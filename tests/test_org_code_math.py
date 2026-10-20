"""Real code/math regressions: python3 -m unittest discover -s tests -p test_org_code_math.py -v.

PDF checks exercise the public CLI. SVG/query checks additionally inspect native
Typst highlighting with the same preprocessor, filters and tab policy, not mocks.
"""
import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'typst/org'
CLI = ROOT / 'bin/org-pdf'
TYPST = '/usr/bin/typst'
loader = importlib.machinery.SourceFileLoader('org_pdf_code_math', str(CLI))
spec = importlib.util.spec_from_loader(loader.name, loader)
exporter = importlib.util.module_from_spec(spec)
loader.exec_module(exporter)

LANGUAGES = {
    'matlab': ('matlab', 'function y = square(x)\n    y = x.^2; % comment\nend'),
    'C': ('c', 'int main(void) { return 42; }'),
    'cpp': ('cpp', 'int main() { const auto value = "hello"; return 42; }'),
    'C++': ('cpp', 'int main() { const auto value = "hello"; return 42; }'),
    'python': ('python', 'def square(x):\n    return "hello" # comment'),
    'javascript': ('javascript', 'const value = "hello"; // comment'),
    'typescript': ('typescript', 'const value: string = "hello"; // comment'),
    'bash': ('bash', 'echo "$HOME" # comment'),
    'lua': ('lua', 'local value = "hello" -- comment'),
    'rust': ('rust', 'fn main() { let value = "hello"; }'),
}


@unittest.skipUnless(shutil.which('pandoc') and os.access(TYPST, os.X_OK)
                     and shutil.which('pdftotext'),
                     'requires real Pandoc, /usr/bin/typst and pdftotext')
class CodeMathCliTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='org code math tests ')
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)
        self.env = dict(os.environ, XDG_CONFIG_HOME=str(self.directory / 'config'))

    def run_tool(self, *args, **kwargs):
        result = subprocess.run(list(map(str, args)), text=True, capture_output=True,
                                env=self.env, timeout=60, **kwargs)
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        return result.stdout

    def export(self, text, name='document', template='report'):
        source = self.directory / (name + '.org')
        source.write_text(text)
        output = source.with_suffix('.pdf')
        self.run_tool(CLI, source, '--template', template, '--output', output)
        self.assertTrue(output.read_bytes().startswith(b'%PDF-'))
        self.assertFalse(list(self.directory.glob('.org-pdf-*')))
        return output

    def pdf_text(self, output):
        return self.run_tool('pdftotext', output, '-')

    def native_document(self, org, name):
        generated = self.run_tool(
            'pandoc', '--from=org', '--to=typst', '--preserve-tabs', '--tab-stop=4',
            '--lua-filter', ASSETS / 'native-math.lua',
            '--lua-filter', ASSETS / 'code.lua', input=exporter.prepare(org))
        path = self.directory / (name + '.typ')
        path.write_text(generated)
        return path

    def test_language_matrix_real_cli_pdf_and_native_svg_colors(self):
        # Only code appears in each SVG, so colored fills cannot come from a
        # heading, math, template decoration, or a different language's block.
        for language, (normalized, code) in LANGUAGES.items():
            with self.subTest(language=language):
                org = f'#+begin_src {language} :exports code :eval never\n{code}\n#+end_src\n'
                pdf = self.export(org, language)
                self.assertIn(code.splitlines()[0].split()[0], self.pdf_text(pdf))
                typ = self.native_document(org, language)
                raw = json.loads(self.run_tool(TYPST, 'query', typ, 'raw'))
                self.assertEqual(len(raw), 1)
                self.assertEqual(raw[0]['lang'], normalized)
                self.assertEqual(raw[0]['text'], code + '\n')
                svg = typ.with_suffix('.svg')
                self.run_tool(TYPST, 'compile', typ, svg)
                tree = ET.fromstring(svg.read_text())
                colors = {node.get('fill', '').lower() for node in tree.iter()}
                chromatic = {color for color in colors if color.startswith('#')
                             and len(color) == 7
                             and not (color[1:3] == color[3:5] == color[5:7])}
                self.assertTrue(chromatic, f'{language} silently rendered without syntax colors: {colors}')

    def test_common_indent_nested_indent_and_tabs_pdf_geometry(self):
        org = '''#+OPTIONS: toc:nil num:nil
#+begin_src python :exports code :eval never
    SpaceBase
        SpaceNested
            SpaceDeep
#+end_src

#+begin_src python -i :exports code :eval never
TabZero
\tTabFour
\t\tTabEight
    SpaceFour
  \tMixedFour
#+end_src

#+begin_example
    ExampleBase
        ExampleNested
#+end_example

- Nested listing

  #+begin_src python :exports code :eval never
      ListBase
          ListNested
  #+end_src
'''
        pdf = self.export(org, 'indentation')
        tree = ET.fromstring(self.run_tool('pdftotext', '-bbox', pdf, '-'))
        words = {node.text: node for node in tree.iter() if node.tag.endswith('word')}

        def x(word):
            self.assertIn(word, words)
            return float(words[word].get('xMin'))

        # DejaVu Sans Mono at 9pt: four spaces are 21.67383pt. Absolute
        # common margins are checked against the zero-indented block too.
        step = 21.67383
        with self.subTest(whitespace='tab width'):
            self.assertAlmostEqual(x('TabFour') - x('TabZero'), step, delta=0.12)
        for left, right in [('SpaceBase', 'SpaceNested'), ('SpaceNested', 'SpaceDeep'),
                            ('TabFour', 'TabEight'), ('ExampleBase', 'ExampleNested'),
                            ('ListBase', 'ListNested')]:
            with self.subTest(indentation=(left, right)):
                self.assertAlmostEqual(x(right) - x(left), step, delta=0.12)
        for word in ('SpaceBase', 'SpaceFour', 'MixedFour', 'ExampleBase'):
            with self.subTest(common_margin=word):
                self.assertAlmostEqual(x(word) - x('TabZero'), step, delta=0.12)

    def test_math_inline_code_and_raw_injection_are_data_in_same_pdf(self):
        # These would fail compilation if interpreted as executable Typst.
        payload = '\"); #panic("SOURCE_EXECUTED"); // \\\\ @@typst:#panic("SNIPPET_EXECUTED")@@'
        inline = '\");#panic("INLINE_EXECUTED")//@@typst:bad@@'
        sentinel = self.directory / 'MUST_NOT_EXIST'
        org = f'''#+OPTIONS: toc:nil num:nil
Inline math $sqrt(2)$ and $alpha + beta$ with `inline_code(x)`.
Inline hostile `{inline}`.
Org literals ~native_code(x)~ and =verbatim_code(x)=.

$ sum_(k=1)^n k = (n(n+1))/2 $

$
mat(1, 2; 3, 4)
$

#+begin_src typst :exports code :eval yes
{payload}
$ not_a_defined_function(2) $
``` #panic("FENCE_EXECUTED") ```
#+end_src

#+begin_example
#panic("EXAMPLE_EXECUTED")
#+end_example

#+begin_src bash :exports code :eval yes
printf executed > "{sentinel}"
#+end_src
'''
        pdf = self.export(org, 'math and safety')
        text = self.pdf_text(pdf)
        for literal in ('inline_code(x)', 'native_code(x)', 'verbatim_code(x)',
                        'SOURCE_EXECUTED', 'SNIPPET_EXECUTED', 'INLINE_EXECUTED',
                        'FENCE_EXECUTED', 'EXAMPLE_EXECUTED', 'not_a_defined_function'):
            self.assertIn(literal, text)
        self.assertNotIn('sum_', text)
        self.assertNotIn('sqrt(2)', text)
        self.assertNotIn('alpha + beta', text)
        self.assertNotIn('mat(1,', text)
        self.assertFalse(sentinel.exists(), 'source block was executed')
        typ = self.native_document(org, 'safety')
        raw = json.loads(self.run_tool(TYPST, 'query', typ, 'raw'))
        self.assertIn(inline, [node['text'] for node in raw])
        self.assertTrue(any(node['text'].startswith(payload + '\n') for node in raw))
        equations = json.loads(self.run_tool(TYPST, 'query', typ, 'math.equation'))
        self.assertEqual(len(equations), 4)
        self.assertEqual(sum(bool(node['block']) for node in equations), 2)

    def test_code_and_math_sample_exports(self):
        sample = ASSETS / 'code-and-math.org'
        self.assertTrue(sample.is_file(), 'discoverable code/math sample is missing')
        output = self.directory / 'sample.pdf'
        self.run_tool(CLI, sample, '--output', output)
        self.assertTrue(output.read_bytes().startswith(b'%PDF-'))
        text = self.pdf_text(output)
        for expected in ('Code and Mathematics', 'MATLAB', 'JavaScript', 'TypeScript',
                         'Rust', 'inline_code(x)', 'aligned', 'nested',
                         'A native Typst layout block'):
            self.assertIn(expected, text)
        self.assertNotIn('sum_', text)
        self.assertNotIn('sqrt(x', text)


if __name__ == '__main__':
    unittest.main()
