"""Measured generic Org image layout regressions, using real PDF raster output."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which('pandoc') and Path('/usr/bin/typst').exists()
                     and shutil.which('pdftoppm'), 'requires Pandoc, Typst and pdftoppm')
class ImageLayoutTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='org image layout ')
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.env = dict(os.environ, XDG_CONFIG_HOME=str(self.directory / 'config'))

    def render(self, width, height, template='essay', prefix='', caption=False):
        (self.directory / 'red figure.svg').write_text(
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}">'
            '<rect width="100%" height="100%" fill="red"/></svg>')
        source = self.directory / 'image.org'
        source.write_text('#+OPTIONS: toc:nil\n\n' + prefix
                          + ('#+CAPTION: Preserved caption\n#+NAME: fig:sample\n' if caption else '')
                          + '[[file:red figure.svg]]\n\nAfter image.\n')
        output = self.directory / 'image.pdf'
        result = subprocess.run([str(ROOT / 'bin/org-pdf'), str(source), '--template', template],
                                env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        data = subprocess.check_output(['pdftoppm', '-r', '72', '-singlefile', str(output)])
        magic, page_width, page_height, maximum, pixels = data.split(None, 4)
        self.assertEqual((magic, maximum), (b'P6', b'255'))
        page_width, page_height = int(page_width), int(page_height)
        red = [i // 3 for i in range(0, len(pixels), 3)
               if pixels[i] > 220 and pixels[i + 1] < 40 and pixels[i + 2] < 40]
        self.assertTrue(red, 'image must appear on the first page, not overflow to a new page')
        xs, ys = [p % page_width for p in red], [p // page_width for p in red]
        bounds = (min(xs), min(ys), max(xs) + 1, max(ys) + 1)
        return output, page_width, page_height, bounds

    def assert_geometry(self, result, ratio, max_width=396, max_height=468):
        _, page_width, page_height, (left, top, right, bottom) = result
        width, height = right - left, bottom - top
        self.assertAlmostEqual((left + right) / 2, page_width / 2, delta=1.5)
        self.assertLessEqual(width, max_width + 1)
        self.assertLessEqual(height, max_height + 1)
        self.assertAlmostEqual(width / height, ratio, delta=0.05)
        self.assertGreaterEqual(top, 0)
        self.assertLess(bottom, page_height)

    def test_large_landscape_and_portrait_all_builtin_templates(self):
        for template in ('essay', 'notes', 'report', 'math', 'mla', 'technical'):
            # Extra templates can be present as unstaged user work in a shared tree.
            if not (ROOT / 'typst/org/templates' / (template + '.typ')).exists():
                continue
            for width, height in ((2400, 600), (600, 2400)):
                with self.subTest(template=template, width=width):
                    result = self.render(width, height, template=template, caption=True)
                    self.assert_geometry(result, width / height)
                    if shutil.which('pdftotext'):
                        text = subprocess.check_output(['pdftotext', str(result[0]), '-'], text=True)
                        self.assertIn('Preserved caption', text)
                        self.assertIn('After image.', text)

    def test_small_image_is_not_enlarged(self):
        result = self.render(80, 40)
        self.assert_geometry(result, 2)
        _, _, _, (left, top, right, bottom) = result
        self.assertLessEqual(right - left, 81)
        self.assertLessEqual(bottom - top, 41)

    def test_custom_short_page_and_explicit_width(self):
        templates = Path(self.env['XDG_CONFIG_HOME']) / 'org-writing/templates'
        templates.mkdir(parents=True)
        (templates / 'short.typ').write_text(
            '#set page(width: 6in, height: 5in, margin: 0.5in)\n$body$\n')
        result = self.render(600, 2400, template='short')
        self.assert_geometry(result, 0.25, max_width=360, max_height=4 * 72 * 0.8)
        result = self.render(2400, 600, prefix='#+ATTR_HTML: :width 192\n')
        self.assert_geometry(result, 4, max_width=144)


if __name__ == '__main__':
    unittest.main()
