"""Mock-runner unit tests only. These do NOT execute or validate real MATLAB."""
import contextlib
import importlib.machinery
import importlib.util
import io
from pathlib import Path
import re
import subprocess
import tempfile
import unittest
from unittest.mock import patch, Mock

CLI = Path(__file__).resolve().parents[1] / 'bin/org-plot-pdf'
loader = importlib.machinery.SourceFileLoader('org_plot_pdf', str(CLI))
spec = importlib.util.spec_from_loader(loader.name, loader)
module = importlib.util.module_from_spec(spec)
loader.exec_module(module)


def block(header='matlab :plot yes :file plots/a.png :eval yes', body='plot(1:3);'):
    return '#+begin_src ' + header + '\n' + body + '\n#+end_src\n'


class PlotTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="org plot's tests ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.doc = self.root / 'document.org'
        self.doc.write_text(block() + block('matlab :plot yes :file b.svg', 'plot(3:5);'))
        self.asset = self.root / 'plots/a.png'
        self.asset.parent.mkdir()
        self.asset.write_bytes(b'prior asset')
        self.pdf = self.doc.with_suffix('.pdf')
        self.pdf.write_bytes(b'prior pdf')

    def parse(self, text):
        return module.parse(text, self.root)

    def assert_preserved(self):
        self.assertEqual(self.asset.read_bytes(), b'prior asset')
        self.assertEqual(self.pdf.read_bytes(), b'prior pdf')
        self.assertFalse(list(self.root.glob('.org-plot-*')))

    def test_only_exact_explicit_top_level_opt_in(self):
        hidden = ''.join('#+begin_' + kind + '\n' + block() + '#+end_' + kind + '\n'
                         for kind in ('example', 'comment', 'export', 'quote'))
        ordinary = block('python', 'raise Exception()') + block('matlab :plot YES')
        ordinary += block('matlab :plot yesplease') + block('matlab :plot no')
        text = '#+PROPERTY: header-args:matlab :plot yes :file inherited.png\n' + hidden + ordinary
        with self.assertRaisesRegex(ValueError, 'no top-level'):
            self.parse(text)
        result = self.parse(text + block())
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0][0], 'plot(1:3);\n')

    def test_unsafe_headers(self):
        for header in ('matlab :plot yes :file "unterminated',
                       'matlab :plot yes :plot no :file a.png',
                       'matlab :file a.png :file b.png :plot yes',
                       'matlab :plot yes', 'matlab :plot yes :file a.png b.png',
                       'python :plot yes :file a.png',
                       'matlab :plot yes :file a.png :eval never',
                       'matlab :plot yes :file a.png :eval no',
                       'matlab :plot yes :file a.png :eval yes :eval no',
                       'matlab stray :plot yes :file a.png'):
            with self.subTest(header=header), self.assertRaises(ValueError):
                self.parse(block(header))

    def test_paths_and_duplicates(self):
        for name in ('/absolute.png', '../escape.png', 'x/../a.png', 'a.pdf', 'a.PNG', r'x\\a.png'):
            with self.subTest(name=name), self.assertRaises(ValueError):
                self.parse(block('matlab :plot yes :file "' + name + '"'))
        with tempfile.TemporaryDirectory() as outside:
            (self.root / 'link').symlink_to(outside, target_is_directory=True)
            with self.assertRaises(ValueError):
                self.parse(block('matlab :plot yes :file link/a.png'))
        with self.assertRaisesRegex(ValueError, 'duplicate output'):
            self.parse(block() + block('matlab :plot yes :file plots/./a.png'))
        self.assertEqual(len(self.parse(block('matlab :plot yes :file "a b.png"'))), 1)

    def test_unclosed_and_mismatched_blocks(self):
        for text in ('#+begin_example\n', '#+begin_src matlab\n',
                     block() + '#+begin_quote\n', '#+end_src\n',
                     '#+begin_example\n#+end_quote\n'):
            with self.subTest(text=text), self.assertRaises(ValueError):
                self.parse(text)

    def fake_matlab(self, command, cwd, timeout):
        self.assertEqual(command[:2], ['/mock/matlab', '-batch'])
        self.assertEqual(cwd, self.root)
        self.assertEqual(timeout, 9)
        script = next(self.root.glob('org_plot_*.m'))
        self.assertEqual(script.parent, cwd)
        self.assertEqual(command[2], 'run(%s)' % module.quote(script))
        self.script = script.read_text()
        self.assertLess(self.script.index('org_plot_0();'), self.script.index('org_plot_1();'))
        self.assertEqual(self.script.count('close all force;'), 2)
        self.assertIn("defaultFigureVisible', 'off'", self.script)
        self.assertIn("plot''s tests", self.script)
        self.assertNotIn('gcf', self.script)
        self.assertEqual(self.script.count("get(groot, 'CurrentFigure')"), 2)
        self.assertEqual(self.script.count('if isempty(org_plot_figure)'), 2)
        self.assertIn("error('org_plot:noFigure'", self.script)
        for path in re.findall(r"exportgraphics\(org_plot_figure, '((?:[^']|'')*)'\)", self.script):
            Path(path.replace("''", "'")).write_bytes(b'new plot')

    def test_success_arguments_workspaces_staging_and_open(self):
        with patch.object(module.shutil, 'which', return_value='/mock/matlab') as which, \
                patch.object(module, 'run_matlab', side_effect=self.fake_matlab) as runner, \
                patch.object(module.subprocess, 'run') as pdf:
            module.export(self.doc, 'chosen-matlab', 9, True)
        which.assert_called_once_with('chosen-matlab')
        runner.assert_called_once()
        pdf.assert_called_once_with([str(CLI.with_name('org-pdf')), str(self.doc), '--open'],
                                    cwd=self.root, check=True)
        self.assertEqual(self.asset.read_bytes(), b'new plot')
        self.assertEqual((self.root / 'b.svg').read_bytes(), b'new plot')
        self.assertIn('function org_plot_0()', self.script)
        self.assertFalse(list(self.root.glob('.org-plot-*')))

    def test_failure_and_stale_outputs_preserve_assets_and_pdf(self):
        def partial(command, cwd, timeout):
            next(self.root.glob('.org-plot-*')).joinpath('plot-0.png').write_bytes(b'partial')
        for effect in (ValueError('MATLAB failed'), None, partial):
            with self.subTest(effect=effect), \
                    patch.object(module.shutil, 'which', return_value='/mock/matlab'), \
                    patch.object(module, 'run_matlab', side_effect=effect), \
                    patch.object(module.subprocess, 'run') as pdf:
                with self.assertRaises(ValueError):
                    module.export(self.doc)
                pdf.assert_not_called()
                self.assert_preserved()

    def test_missing_matlab_and_no_selected_preflight(self):
        with patch.object(module.shutil, 'which', return_value=None), \
                patch.object(module.subprocess, 'Popen') as popen, \
                patch.object(module.subprocess, 'run') as pdf:
            with self.assertRaisesRegex(ValueError, 'executable not found.*--matlab'):
                module.export(self.doc)
            self.doc.write_text(block('matlab'))
            with self.assertRaisesRegex(ValueError, 'no top-level'):
                module.export(self.doc)
            popen.assert_not_called()
            pdf.assert_not_called()
        self.assert_preserved()

    def test_timeout_kills_group_and_waits(self):
        process = Mock(pid=123)
        process.wait.side_effect = [subprocess.TimeoutExpired('matlab', 1), -9]
        with patch.object(module.subprocess, 'Popen', return_value=process) as popen, \
                patch.object(module.os, 'killpg') as kill:
            with self.assertRaisesRegex(ValueError, 'timed out'):
                module.run_matlab(['matlab', '-batch', 'run'], self.root, 1)
        popen.assert_called_once_with(['matlab', '-batch', 'run'], cwd=self.root, start_new_session=True)
        kill.assert_called_once_with(123, module.signal.SIGKILL)
        self.assertEqual(process.wait.call_count, 2)

    def test_nonzero_matlab_status(self):
        process = Mock()
        process.wait.return_value = 7
        with patch.object(module.subprocess, 'Popen', return_value=process):
            with self.assertRaisesRegex(ValueError, 'exit status 7'):
                module.run_matlab(['matlab'], self.root, 120)

    def test_cli_defaults_and_invalid_timeout(self):
        with patch.object(module, 'export') as export:
            self.assertEqual(module.main([str(self.doc), '--open']), 0)
            export.assert_called_once_with(self.doc, 'matlab', 120, True)
        for value in ('0', '-1', 'nan', 'inf'):
            with contextlib.redirect_stderr(io.StringIO()), patch.object(module, 'export') as export:
                self.assertEqual(module.main([str(self.doc), '--timeout', value]), 1)
                export.assert_not_called()


if __name__ == '__main__':
    unittest.main()
