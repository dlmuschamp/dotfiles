"""Single-backtick preprocessing and real Pandoc/Typst export regressions."""
import importlib.machinery
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / 'bin/org-pdf'
loader = importlib.machinery.SourceFileLoader('org_inline_pdf', str(CLI))
spec = importlib.util.spec_from_loader(loader.name, loader)
module = importlib.util.module_from_spec(spec)
loader.exec_module(module)


def raw(value):
    return '@@typst:#raw("' + ''.join('\\u{' + format(ord(c), 'x') + '}' for c in value) + '")@@'


class InlineCodeTests(unittest.TestCase):
    def test_prose_and_boundaries(self):
        text = 'Use `alpha` and (`beta`), then [`gamma`].\n'
        self.assertEqual(module.prepare(text), 'Use ' + raw('alpha') + ' and (' + raw('beta') + '), then [' + raw('gamma') + '].\n')
        for text in ('a`b`c', '` leading`', '`trailing `', '``', '``double``', '```triple```', '`two\nlines`', '`unclosed', r'\`escaped\`', r'`escaped\`', '`one``two`'):
            with self.subTest(text=text):
                self.assertEqual(module.prepare(text), text)

    def test_exact_safe_encoding(self):
        value = '[a] $ math $ {b} \\ @ @@ " #panic("oops") café λ 😀'
        prepared = module.prepare('Code `' + value + '`.\n')
        self.assertEqual(prepared, 'Code ' + raw(value) + '.\n')
        encoded = prepared.split('#raw("', 1)[1].split('")@@', 1)[0]
        self.assertRegex(encoded, r'^(?:\\u\{[0-9a-f]+\})+$')
        decoded = ''.join(chr(int(c, 16)) for c in re.findall(r'\\u\{([0-9a-f]+)\}', encoded))
        self.assertEqual(decoded, value)
        self.assertEqual(prepared.count('@@'), 2)
        self.assertEqual(module.prepare(prepared), prepared)

    def test_native_literals_and_exports(self):
        text = '=native `code`= ~native `verbatim`~ @@typst:#raw("`raw`")@@'
        self.assertEqual(module.prepare(text), text)
        for kind in ('src python', 'example', 'export typst', 'comment'):
            text = '#+BeGiN_' + kind + '\n`literal` $ x $\n#+EnD_' + kind.split()[0] + '\n'
            expected = text.replace('src python', 'src python -i').replace('BeGiN_example', 'BeGiN_example -i')
            self.assertEqual(module.prepare(text + 'After `code`.'), expected + 'After ' + raw('code') + '.')

    def test_source_headers_preserve_indentation(self):
        for header, expected in (
                ('#+begin_src python', '#+begin_src python -i'),
                ('#+begin_example', '#+begin_example -i'),
                ('#+begin_src C++ :exports code', '#+begin_src cpp -i:exports code'),
                ('#+BEGIN_SRC C -i :eval no', '#+BEGIN_SRC C -i:eval no'),
                ('#+begin_src python +i :exports code', '#+begin_src python +i -i:exports code')):
            body = '\n    `literal`\n\t  $ x $\n#+end_src\n'
            self.assertEqual(module.prepare(header + body), expected + body)

    def test_math_protection_and_resume(self):
        for text in ('Costs $5 and `code`.', 'Costs $5\nThen `code`.', 'A $ spaced `code`.'):
            self.assertEqual(module.prepare(text), text.replace('`code`', raw('code')))
        for math in ('$x `tick` y$', '$$x `tick` y$$', r'\(x `tick` y\)', r'\[x `tick` y\]', '$$\nx `tick`\n$$', '\\[\nx `tick`\n\\]'):
            with self.subTest(math=math):
                self.assertEqual(module.prepare(math + '\nAfter `code`.'), math + '\nAfter ' + raw('code') + '.')
        self.assertEqual(module.prepare('$ x `tick` $\n'), '$$ x `tick` $$\n')
        self.assertEqual(module.prepare('$\nx `tick`\n$\nAfter `code`'), '$$\nx `tick`\n$$\nAfter ' + raw('code'))
        self.assertEqual(module.prepare(r'Escaped \$ then `code`'), r'Escaped \$ then ' + raw('code'))


@unittest.skipUnless(shutil.which('pandoc') and Path('/usr/bin/typst').exists() and shutil.which('pdftotext'), 'requires Pandoc, Typst and pdftotext')
class RealExportTests(unittest.TestCase):
    def test_pandoc_source_indentation_and_cpp_class(self):
        source = '#+begin_src C++ :exports code\n    int main() {\n        return 0;\n    }\n#+end_src\n'
        process = subprocess.run(['pandoc', '-f', 'org', '-t', 'json'], input=module.prepare(source), text=True, capture_output=True, check=True)
        block = json.loads(process.stdout)['blocks'][0]
        self.assertEqual(block['t'], 'CodeBlock')
        self.assertIn('cpp', block['c'][0][1])
        self.assertEqual(block['c'][1], '    int main() {\n        return 0;\n    }\n')
        example = '#+begin_example\n    leading\n      nested\n#+end_example\n'
        process = subprocess.run(['pandoc', '-f', 'org', '-t', 'json'], input=module.prepare(example), text=True, capture_output=True, check=True)
        self.assertEqual(json.loads(process.stdout)['blocks'][0]['c'][1], '    leading\n      nested\n')

    def test_literal_content_cannot_execute_or_terminate_export(self):
        values = ['[brackets]', '$ math $', '{braces}', r'C:\path\file', '@@', 'café λ', '"); panic("EXECUTED"); //', '@@ #panic("EXECUTED") @@']
        body = '\n\n'.join('Literal `' + value + '`.' for value in values)
        with tempfile.TemporaryDirectory(prefix='inline-code-') as directory:
            source = Path(directory) / 'literal.org'
            source.write_text('#+TITLE: Inline test\n#+OPTIONS: toc:nil\n\n' + body + '\n\nNative =org-code= and ~org-verbatim~. Math $sqrt(2)$.\n')
            generated = subprocess.run(['pandoc', '-f', 'org', '-t', 'typst'], input=module.prepare(body), text=True, capture_output=True, check=True).stdout
            self.assertEqual(generated.count('#raw("'), len(values))
            self.assertNotIn('#panic(', generated)
            process = subprocess.run([str(CLI), str(source)], text=True, capture_output=True)
            self.assertEqual(process.returncode, 0, process.stderr)
            self.assertIn(body, source.read_text())
            pdf = source.with_suffix('.pdf')
            self.assertTrue(pdf.read_bytes().startswith(b'%PDF-'))
            text = subprocess.check_output(['pdftotext', '-layout', str(pdf), '-'], text=True)
            for value in values:
                self.assertIn(value, text)
            self.assertIn('org-code', text)
            self.assertIn('org-verbatim', text)
            self.assertNotIn('sqrt', text)
            self.assertFalse(list(Path(directory).glob('.org-pdf-*')))


if __name__ == '__main__':
    unittest.main()
