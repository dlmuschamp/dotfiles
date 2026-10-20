"""Real converter integration tests. Run: python3 -m unittest discover -s tests -p test_org_pdf.py"""
import importlib.machinery
import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / "bin" / "org-pdf"
loader = importlib.machinery.SourceFileLoader("org_pdf", str(CLI))
spec = importlib.util.spec_from_loader(loader.name, loader)
module = importlib.util.module_from_spec(spec)
loader.exec_module(module)


class PrepareTests(unittest.TestCase):
    def test_display_and_literal_blocks(self):
        text = '$ sum_(k=1)^n k $\n\n$\n  mat(1, 2; 3, 4)\n$\n'
        self.assertEqual(module.prepare(text), '$$ sum_(k=1)^n k $$\n\n$$\n  mat(1, 2; 3, 4)\n$$\n')
        for kind in ('src typst', 'example', 'export typst', 'comment'):
            block = '#+begin_' + kind + '\n$ x $\n#+end_' + kind.split()[0] + '\n'
            expected = block.replace('#+begin_' + kind, '#+begin_' + kind + ' -i', 1) if kind in ('src typst', 'example') else block
            self.assertEqual(module.prepare(block), expected)

    def test_unclosed_display(self):
        with self.assertRaisesRegex(ValueError, 'unclosed'):
            module.prepare('$\nx^2\n')

    def test_metadata_ignores_blocks_and_subtrees(self):
        header = '#+PDF_TEMPLATE: notes\n#+INSTRUCTOR: Real Teacher\n#+COURSE: Real Course\n'
        for kind in ('src org', 'example', 'export typst', 'comment'):
            header += '#+begin_' + kind + '\n* Not a real heading\n#+PDF_TEMPLATE: invalid\n#+INSTRUCTOR: Fake Teacher\n#+COURSE: Fake Course\n#+end_' + kind.split()[0] + '\n'
        header += '* Actual heading\n#+PDF_TEMPLATE: invalid\n#+COURSE: Subtree Course\n'
        self.assertEqual(module.header_metadata(header), {'pdf-template': 'notes', 'instructor': 'Real Teacher', 'course': 'Real Course'})
        self.assertEqual(module.header_metadata('#+COURSE:\n#+INSTRUCTOR: Teacher\n'), {'course': '', 'instructor': 'Teacher'})


class CliTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='org writing tests ')
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.env = dict(os.environ, XDG_CONFIG_HOME=str(self.directory / 'config home'))
        self.source = self.directory / 'my homework.org'

    def cli(self, *args, success=True, env=None):
        process = subprocess.run([str(CLI), *map(str, args)], env=env or self.env, text=True, capture_output=True)
        if success:
            self.assertEqual(process.returncode, 0, process.stderr)
        else:
            self.assertNotEqual(process.returncode, 0)
            self.assertIn('org-pdf:', process.stderr)
            self.assertNotIn('Traceback', process.stderr)
        return process

    def test_template_listing_and_import_no_overwrite(self):
        self.assertEqual(self.cli('--list-templates').stdout.splitlines(), ['essay', 'notes', 'report'])
        template = self.directory / 'my template.typ'
        template.write_text('#set text(size: 10pt)\n$body$\n')
        self.cli('--import-template', template, '--name', 'custom')
        stored = Path(self.env['XDG_CONFIG_HOME']) / 'org-writing/templates/custom.typ'
        self.assertEqual(stored.read_text(), template.read_text())
        self.assertIn('custom', self.cli('--list-templates').stdout)
        self.cli('--import-template', template, '--name', 'custom', success=False)
        self.cli('--import-template', template, '--name', 'essay', success=False)
        self.cli('--import-template', template, '--name', '../outside', success=False)
        template.write_text('#set text(size: 10pt)\n')
        self.cli('--import-template', template, '--name', 'invalid', success=False)

    def test_readable_input_template_and_dependency_errors(self):
        self.cli(self.source, success=False)
        self.source.write_text('Hello\n')
        self.cli(self.source, '--template', 'absent', success=False)
        self.cli(self.source, '--output', self.directory / 'missing/out.pdf', success=False)
        self.cli(self.source, '--output', self.directory / 'bad.txt', success=False)
        empty_path = dict(self.env, PATH='/usr/bin')
        # The test machine may also have a system pandoc. Use /usr/bin/python3
        # to test dependency detection with an empty PATH independently.
        empty_path['PATH'] = str(self.directory)
        process = subprocess.run(['/usr/bin/python3', str(CLI), str(self.source)], env=empty_path, text=True, capture_output=True)
        self.assertNotEqual(process.returncode, 0)
        self.assertIn('Pandoc is missing', process.stderr)

    @unittest.skipUnless(shutil.which('pandoc') and Path('/usr/bin/typst').exists() and shutil.which('pdftotext'), 'requires pandoc, /usr/bin/typst and pdftotext')
    def test_real_pdf_all_templates_native_math_metadata_and_literal_source(self):
        sentinel = self.directory / 'MUST NOT EXIST'
        self.source.write_text('''#+TITLE: Test title with [brackets] and "quotes"
#+AUTHOR: Test Author
#+DATE: October 19, 2026
#+INSTRUCTOR: Professor Example
#+COURSE: Algebra 101
#+OPTIONS: toc:nil

* A heading
Ordinary prose and native math $sum_(k=1)^n k$.

$ sum_(k=1)^n k = (n(n+1))/2 $

$
mat(1, 2; 3, 4)
$

$$ integral_0^1 x dif x = 1/2 $$

Inline raw @@typst:$sqrt(2)$@@.

#+begin_export typst
$ vec(1, 2) $
#+end_export

| Name | Value |
|------+-------|
| Test |     3 |

- First item
- Second item

-----

#+begin_src sh :exports code :eval yes
printf evil > "''' + str(sentinel) + '''"
#+end_src
''')
        for template in ('essay', 'report', 'notes'):
            output = self.directory / (template + ' output.pdf')
            self.cli(self.source, '--template', template, '--output', output)
            self.assertTrue(output.read_bytes().startswith(b'%PDF-'))
            text = subprocess.check_output(['pdftotext', str(output), '-'], text=True)
            for expected in ('Test Author', 'Professor Example', 'Algebra 101', 'Ordinary prose', 'Test title', 'First item'):
                self.assertIn(expected, text)
            self.assertNotIn('sum_', text)
            self.assertNotIn('integral_', text)
            self.assertFalse(sentinel.exists())
        self.assertFalse(list(self.directory.glob('.org-pdf-*')))

    @unittest.skipUnless(shutil.which('pandoc') and Path('/usr/bin/typst').exists(), 'requires real converters')
    def test_atomic_failure_and_metadata_selector(self):
        self.source.write_text('#+PDF_TEMPLATE: notes\nA valid document.\n\n#+begin_example\n#+PDF_TEMPLATE: invalid\n#+end_example\n\n* Heading\n#+PDF_TEMPLATE: invalid\n')
        self.cli(self.source)
        output = self.source.with_suffix('.pdf')
        original = output.read_bytes()
        self.source.write_text('Bad native math $not_a_defined_typst_function(2)$.\n')
        failure = self.cli(self.source, success=False)
        self.assertIn('typst failed', failure.stderr)
        self.assertEqual(output.read_bytes(), original)
        self.source.write_text('#+PDF_TEMPLATE: nonexistent\nText\n')
        self.cli(self.source, success=False)
        self.cli(self.source, '--template', 'report')
        self.assertFalse(list(self.directory.glob('.org-pdf-*')))

    @unittest.skipUnless(shutil.which('pandoc') and Path('/usr/bin/typst').exists(), 'requires real converters')
    def test_relative_image_from_different_working_directory(self):
        # SVG fixture uses a filename containing spaces.
        (self.directory / 'my figure.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><rect width="10" height="10" fill="red"/></svg>')
        self.source.write_text('A figure:\n\n[[file:my figure.svg]]\n')
        self.cli(self.source, '--template', 'notes')
        self.assertTrue(self.source.with_suffix('.pdf').exists())

    @unittest.skipUnless(shutil.which('pandoc') and Path('/usr/bin/typst').exists(), 'requires real converters')
    def test_custom_template_and_open_argument(self):
        template = self.directory / 'custom.typ'
        template.write_text('#set text(size: 10pt)\n$body$\n')
        self.cli('--import-template', template)
        self.source.write_text('#+PDF_TEMPLATE: custom\nCustom template body $sqrt(2)$.\n')
        tools = self.directory / 'tools'
        tools.mkdir()
        opener = tools / 'xdg-open'
        opener.write_text('#!/bin/sh\nprintf "%s" "$1" > "$OPEN_MARKER"\n')
        opener.chmod(0o755)
        marker = self.directory / 'opened path'
        env = dict(self.env, PATH=str(tools) + os.pathsep + os.environ['PATH'], OPEN_MARKER=str(marker))
        output = self.directory / 'custom exported.pdf'
        self.cli(self.source, '--output', output, '--open', env=env)
        self.assertEqual(marker.read_text(), str(output))
        self.assertTrue(output.read_bytes().startswith(b'%PDF-'))

    @unittest.skipUnless(shutil.which('pandoc') and Path('/usr/bin/typst').exists() and shutil.which('pdftotext'), 'requires real converters and pdftotext')
    def test_discoverable_example(self):
        output = self.directory / 'example essay.pdf'
        self.cli(ROOT / 'typst/org/example.org', '--output', output)
        text = subprocess.check_output(['pdftotext', str(output), '-'], text=True)
        for expected in ('A Small Summation Essay', 'Professor Example', 'Algebra 101', 'Good mathematical writing', 'Conclusion'):
            self.assertIn(expected, text)


if __name__ == '__main__':
    unittest.main()
