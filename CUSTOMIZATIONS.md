# My dotfiles customizations: desktop, Org notes, and PDFs

This is the practical handbook for the customizations added in this session.
Read the quick start first. The later sections explain what lives where, how to
change document styles, and what the setup does **not** automate.

## Contents

1. [Five-minute quick start](#five-minute-quick-start)
2. [What changed](#what-changed)
3. [Writing Org documents in Neovim](#writing-org-documents-in-neovim)
4. [Picking the right preset](#picking-the-right-preset)
5. [Generating and opening PDFs](#generating-and-opening-pdfs)
6. [Importing and customizing templates](#importing-and-customizing-templates)
7. [Math, code, figures, and citations](#math-code-figures-and-citations)
8. [Spelling and correction suggestions](#spelling-and-correction-suggestions)
9. [Desktop bar and light/dark mode](#desktop-bar-and-lightdark-mode)
10. [Files, installation, and troubleshooting](#files-installation-and-troubleshooting)

## Five-minute quick start

1. Restart Neovim if it was already open before the setup changed.
2. Run `nvim` from the directory where you want to keep the assignment.
3. In normal mode, type `:OrgNew` and press Enter.
4. Choose `mla` for a humanities essay, `math` for problem sets, or `technical`
   for a general technical write-up. Enter a filename and title.
5. Edit the author, instructor, course, and date at the top. Replace the example
   prose and calculations in the starter with your actual work.
6. Write and save with `:w`. Press Escape to return from insert mode to normal
   mode before using the controls below.
7. Run `:OrgPdf` to save, build a PDF, and open it in your configured PDF viewer.

Your source remains an ordinary `.org` file. The generated `.pdf` is a separate
file beside it. You can reopen the same source in Neovim or Emacs later.

**The PDF is not live-previewed automatically.** Run `:OrgPdf` again after edits.
For an export without opening a viewer, use `:OrgPdf!`.

### Controls to remember

All key sequences below are normal-mode sequences, not keys held together.
`Space o w n` means press Space, then `o`, then `w`, then `n`.

| Action | Command | Keys |
| --- | --- | --- |
| New Org document with preset and starter | `:OrgNew` | `Space o w n` |
| Pick another PDF preset for this document | `:OrgTemplate` | `Space o w t` |
| Set a known preset directly | `:OrgTemplate mla` | Command only |
| Save, generate PDF, and open it | `:OrgPdf` | `Space o w e` |
| Regenerate enabled MATLAB graphics and rebuild PDF | `:OrgCleanBuild` | `Space o w r` |
| Generate PDF without opening | `:OrgPdf!` | Command only |
| Temporarily export using another preset | `:OrgPdf technical` | Command only |
| Import a local PDF layout template | `:OrgTemplateImport` | `Space o w i` |
| Choose a spelling correction | `:SpellSuggest` | `z=` or `Space o w s` |
| Cycle the heading under the cursor | No command needed | `Tab` |
| Cycle whole-file visibility | No command needed | `Shift-Tab` |
| Next / previous spelling error | No command needed | `]s` / `[s` |
| Accept a word into your dictionary | No command needed | `zg` |
| Org agenda / capture | Org's own interface | `Space o a` / `Space o c` |

`Space o w` is the custom **writing** group in WhichKey. If you are in Org's
special source-block editing buffer, Org's existing `Space o w` save action
remains available and can wait for the mapping timeout because of that prefix.

## What changed

### Desktop changes

- The Omarchy bar is horizontal at the **top** rather than down the left edge.
- The clock is pinned to the exact horizontal center. The bar still spans the
  screen; this is not a small floating panel.
- Wallpaper-dependent transparency was disabled. Bar colors now come from the
  active theme, which gives stable foreground/background colors for that mode.
- **Super + Alt + Space → Toggle → Light / Dark Mode** switches the existing
  `study-day` and `study-night` themes without replacing your wallpaper.

### Writing changes

- Added `nvim-orgmode/orgmode` to the existing LazyVim configuration. This is the
  component responsible for Org parsing, outline folding, and Org commands.
- Added local Neovim commands for choosing presets, starting documents,
  importing styles, exporting PDFs, and selecting spelling corrections.
- Added the `org-pdf` command. It converts Org with Pandoc, preserves native
  Typst mathematics, and compiles the result with the actual Typst binary.
- Added reusable PDF presets and sample Org starters.
- Enabled English spelling for Org, Markdown, text, and Typst files, with
  suggestions displayed when you pause on a misspelled word.
- Removed a duplicate Lazy initialization that produced a startup warning.
  The previous optional Typst LSP configuration was moved into Lazy's normal
  plugin configuration instead of being initialized separately.

The old interactive `typst` launcher, its `write_up.typ`, and the Emacs export
configuration are still there. They are **separate workflows**, not prerequisites
for the new Neovim export command. Existing monitor-scaling edits were not part
of these changes.

## Writing Org documents in Neovim

### A small source example

```org
#+TITLE: My Essay
#+AUTHOR: Damian Luciano Muschamp
#+SURNAME: Muschamp
#+INSTRUCTOR: Professor Name
#+COURSE: Course Name
#+DATE: 19 October 2026
#+PDF_TEMPLATE: mla
#+OPTIONS: toc:nil num:nil

Write the opening paragraph here. A blank line starts another paragraph.
Use *bold*, /italic/, and =literal code= when needed.

A second paragraph goes here. You do not need to insert spaces to indent it:
the PDF preset handles indentation and page layout.
```

The date above is just an example. `:OrgNew` fills in the date on the day you
create a document. You can change it before submission, and export uses the
stored date rather than silently updating it every time.

Keep the export metadata **before the first heading**. The custom metadata
reader deliberately ignores settings copied into source/example blocks or
subtrees. This prevents a pasted example from changing your export settings.

### Outline and folding

```org
* Topic
Body paragraph.

** Subtopic
More detail.

* Another topic
- First item
- Second item

1. First step
2. Second step
```

Headings use stars, not Markdown's `#`. Press `Tab` on a heading to cycle its
local fold, or `Shift-Tab` to cycle whole-file visibility. These are normal-mode
mappings. In insert mode, Tab may still be used by completion or indentation.
Folding affects the editor display, not which ordinary document text is exported.

For an MLA essay, headings are optional. You can write ordinary paragraphs after
the metadata instead of forcing every paragraph into a heading. For math and
technical writing, headings are usually useful for problems or sections.

### A layout preset is not the same thing as an Org starter

- A **PDF layout preset** is a `.typ` Pandoc template. It controls fonts,
  margins, heading styles, page numbering, and title layout.
- An **Org starter** is an editable `.org` example. It gives you the initial
  metadata and useful section structure.

`:OrgNew` uses both when a bundled starter exists. The `mla`, `math`, and
`technical` presets each have one. Imported presets without a bundled starter
use a generic Org introduction instead.

`:OrgTemplate` changes only the layout choice in the existing document. It does
**not** replace your paragraphs with another starter. Likewise, `:OrgPdf math`
uses that layout for one export without changing the saved preset choice.

## Picking the right preset

| Preset | Use it for | Main characteristics |
| --- | --- | --- |
| `mla` | Humanities essays and MLA-style coursework | US Letter, 1-inch margins, 12pt serif, double-spaced body, half-inch first-line indents, surname/page header, plain centered title |
| `math` | Homework, derivations, proofs, and problem sets | Numbered sections and display equations, readable math spacing, course information |
| `technical` | CS/engineering reports and general technical write-ups | Numbered sections, readable code, tables, equations, title information, page numbers |
| `essay` | Your previous personal essay style | Original MLA-like adaptation of `write_up.typ`, kept for compatibility; not the new double-spaced MLA preset |
| `report` | Simple general report | Numbered headings, 11pt serif, title/author/date |
| `notes` | Compact study notes | Smaller text and margins, unnumbered headings |

Choose **`mla` rather than `essay`** when you want the new MLA layout. An
instructor's assignment sheet takes precedence over any preset. A layout preset
does not verify that your citations, argument, or bibliography follow MLA.

### Bundled starters

The three new starters are in:

```text
~/dotfiles/typst/org/starters/mla.org
~/dotfiles/typst/org/starters/math.org
~/dotfiles/typst/org/starters/technical.org
```

Use `:OrgNew` to get the right starter automatically, or copy one explicitly:

```sh
# -n prevents overwriting an existing assignment.
cp -n ~/dotfiles/typst/org/starters/math.org ./problem-set.org
nvim ./problem-set.org
```

These are working samples, not completed assignments. Replace their sample
content and metadata before submitting anything.

## Generating and opening PDFs

### From Neovim

```vim
:OrgTemplate mla
:OrgPdf
```

`OrgTemplate` updates `#+PDF_TEMPLATE:` in the buffer. `OrgPdf` saves the buffer,
then uses the stored preset. The resulting PDF has the same base filename as
the `.org` file. `OrgPdf!` skips opening the viewer, but still saves and exports.

### From a terminal

```sh
org-pdf './My essay.org'
org-pdf './My essay.org' --open
org-pdf './My essay.org' --template mla --open
org-pdf './My essay.org' --template technical --output './submission.pdf'
org-pdf --list-templates
```

Quote paths containing spaces. The directory given to `--output` must already
exist. The template precedence is:

1. Explicit `--template` on the command line, including `:OrgPdf NAME`.
2. `#+PDF_TEMPLATE:` in the Org header.
3. `essay` if no preset was specified at all.

The exporter writes a temporary PDF and replaces the destination **only after
successful compilation**. If math or template code fails, your last successful
PDF remains intact. The `.org` source is not modified by the CLI. Neovim's
`OrgPdf` deliberately saves your editor buffer first.

### What actually runs

```text
Your .org source
    ↓ Pandoc's Org reader
Document structure, paragraphs, lists, metadata, and math
    ↓ custom native-math Lua filter
Typst document using your selected PDF template
    ↓ /usr/bin/typst compile
Formatted .pdf
```

No Emacs session or LaTeX installation is needed for this path. The filter does
not evaluate Org source-code blocks. It preserves Typst math instead of asking
Pandoc to interpret that math as LaTeX. This does not make the converter a full
replacement for every Emacs Org export feature.

## Importing and customizing templates

### The most reliable way: adapt one of the bundled layouts

Start with a layout that is already known to work with this exporter:

```sh
cp -n ~/dotfiles/typst/org/templates/technical.typ ~/my-technical.typ
nvim ~/my-technical.typ
```

Change the font size, margins, colors, heading rules, or title layout. Keep the
`$body$` placeholder intact. To register your edited copy:

```sh
org-pdf --import-template ~/my-technical.typ --name my-technical
org-pdf --list-templates
```

Then choose it with `:OrgTemplate`, or add this to the document header:

```org
#+PDF_TEMPLATE: my-technical
```

From Neovim, `:OrgTemplateImport` opens a file-path prompt. Select a `.typ` file
with a simple filename such as `my-technical.typ`. Its stem becomes the preset
name. If the filename contains spaces or you want a different name, use the
terminal command's `--name` option instead.

### Where imported presets go

Imports are copied into:

```text
~/.config/org-writing/templates/NAME.typ
```

If `XDG_CONFIG_HOME` is set, its directory replaces `~/.config`. You can edit the
imported copy directly after importing it. A second import will not overwrite
an existing preset. Builtin names such as `mla` or `notes` cannot be shadowed by
a user import. Pick a new name for a variant, such as `mla-seminar`.

**Imported presets are local files, not automatically tracked by this repo.**
To keep a finished personal preset in dotfiles and make it available on another
machine, copy it into the tracked preset directory with a unique name, then
review and commit that file:

```sh
cp -n ~/.config/org-writing/templates/my-technical.typ \
  ~/dotfiles/typst/org/templates/my-technical.typ
```

The exporter discovers `.typ` files in that directory automatically. Keep
preset names to letters, digits, hyphens, and underscores, beginning with a
letter or digit. Export and visually inspect a sample after editing a preset.

### Minimal custom template

A minimal **Pandoc Typst template** looks like this:

```typst
#set page(paper: "us-letter", margin: 1in, numbering: "1")
#set text(font: "New Computer Modern", size: 11pt)
#set par(spacing: 0.7em)
$if(title)$
#align(center)[#text(size: 18pt)[$title$]]
$endif$
$body$
```

This file is not compiled directly with `typst compile`: Pandoc must first
substitute its `$title$` and `$body$` fields. A literal dollar sign in a Pandoc
template must be escaped as `$$`; this is different from the math syntax in
your `.org` source. Copying an existing preset avoids most of that boilerplate.

### Why a downloaded Typst template might not import

There are three different things people call a template:

1. A **Pandoc Typst template** with fields such as `$body$`: directly supported.
2. A complete standalone `.typ` document: not directly supported as a PDF preset.
3. A Typst Universe package expecting an `#import` and `#show` call: requires a
   compatible wrapper/adaptation, not just copying the package name.

The importer rejects a file without `$body$` instead of pretending it will work.
Import only styles you trust. Custom raw Typst or imports can read allowed local
assets, and Universe packages can require a network download on first use.
The included presets need no third-party Universe packages.

Self-contained presets are easiest. Relative files referenced by generated
Typst resolve under the **Org document's directory**, which is the Typst project
root, not automatically beside the imported template. Put needed figures and
assets there, or deliberately adapt your layout to that project structure.

## Math, code, figures, and citations

### Native Typst math

Use Typst syntax consistently in files exported with this workflow:

```org
An inline expression: $sqrt(2)$.
Another inline expression: $sum_(k=1)^n k$.

$ sum_(k=1)^n k = n (n + 1) / 2 $

$
mat(1, 2; 3, 4)
$
```

Keep display equations on their own lines with blank lines around them.
The exporter normalizes the standalone spaced-dollar form for Pandoc and then
passes its content through as Typst math. Org `$$ ... $$` display fragments also
work. Avoid mixing this with LaTeX commands such as `\frac{a}{b}`. Write
`$a / b$` or `$frac(a, b)$` instead.

A raw block is an escape hatch when you specifically need Typst layout code:

```org
#+begin_export typst
#align(center)[$ vec(1, 2, 3) $]
#+end_export
```

That syntax is useful for advanced features, but normal paragraphs and math do
not require you to write a full `.typ` document.

### Code and tables

```org
#+begin_src python
print("This is displayed as code, not run by the PDF exporter.")
#+end_src

| Trial | Result |
|-------+--------|
|     1 |    2.5 |
|     2 |    2.7 |
```

Source blocks are formatted as code in the PDF. They are not executed to produce
results. Org tables are converted as document tables, not treated as raw Typst.

### Figures

After changing MATLAB code or rounding, use `Space o w r` / `:OrgCleanBuild`
and confirm. It regenerates all `:plot yes` graphics before building the PDF.
`:OrgCleanBuild!` skips the viewer. It does not delete files first or run disabled
blocks. Ordinary `Space o w e` / `:OrgPdf` only exports images already on disk.
MATLAB errors stop the rebuild. The tool never removes your rounding or edits
your calculations to make an error disappear.

For complete CLI setup, MathWorks sign-in, and plot execution rules, see
[Local MATLAB plots and Org PDFs](docs/matlab-org-plots.md). MATLAB runs locally,
without MATLAB Online. `matlab -batch "run('my_plots.m')"` runs your own script.

To generate and embed directly in Neovim, use `:OrgSnippet matlab`, write your own
code, and change only `:plot never` to `:plot yes`. Leave `:eval never` alone.
Run `:OrgPlotPdf` and confirm execution and automatic image path/link insertion.
Enabled blocks share variables and run in order. Each must create a figure.
The command exports it, adds missing paths and links without changing MATLAB
bodies, builds the PDF, and opens it. No manual `:file` or image link is needed.
`:OrgPlotPdf!` skips opening, not execution. `:OrgPdf` only embeds existing images.

Preserve the author's calculations exactly unless computational edits were
explicitly requested. Tooling setup is not permission to add assertions,
expected-answer formulas, or substitute solutions. After code is restored,
previous images must not be represented as verified outputs of that code.

```org
[[file:figures/plot.svg]]
```

Keep `figures/plot.svg` under the directory containing the Org file. Export can
be invoked from another working directory and still resolve those paths.
Paths outside the document's Typst project root are not automatically allowed.
Emacs attachment IDs are not resolved, so prefer concrete `file:` links.

### MLA citations and Works Cited

Write accurate in-text citations yourself. Neither the `mla` layout nor the
spelling checker verifies sources or converts arbitrary references into correct
MLA entries. The starter demonstrates a Works Cited section using the layout's
helper, which supplies a new page, centered label, and hanging indents.

The helper is a small raw Typst block, so entries inside it use Typst formatting
rather than Org formatting. Follow the working example in `starters/mla.org`.
If you need an automated bibliography from a `.bib` file, that is an additional
workflow, not something this preset silently provides.

## Spelling and correction suggestions

Spelling is on for Org, Markdown, plain text, and Typst, using `en_us`.

1. Put the cursor on a misspelled word in normal mode.
2. Pause briefly. Suggested replacements appear after the line.
3. Press `z=` to open a selectable correction list.
4. Choose a word. Only that word is replaced.

`Ctrl-x s` in insert mode still uses Neovim's built-in spelling completion.
Use `]s` and `[s` to move between errors. Use `zg` for a valid name or technical
term, rather than repeatedly changing it to an incorrect dictionary word.
Nothing is silently auto-corrected. Suggestions are spelling suggestions, not
a grammar checker or a fact checker.

If the document changes while the correction picker is open, the replacement
is rejected rather than risking editing a different word or line. Invoke the
picker again on the current text.

## Desktop bar and light/dark mode

Open **Super + Alt + Space**, choose **Toggle**, then **Light / Dark Mode**.
It switches between `study-day` and `study-night`, reusing your existing palettes.
The wallpaper is left alone. This is a manual toggle, not an automatic sunset
schedule.

The bar is configured with:

```json
"position": "top",
"transparent": false,
"centerAnchor": "omarchy.clock"
```

The clock is centered even when the left and right widget groups have different
widths. Turning off transparency stops wallpaper-dependent foreground selection.
The colors still intentionally change when you change between light and dark.
The bar is not locked against Omarchy's own drag or transparency gestures; if
one of those changes its position again, restore the settings above in
`omarchy/shell.json` and run:

```sh
omarchy-shell shell reloadConfig
omarchy-menu refresh
```

The Toggle branch is also available from the main menu's Trigger branch. The
extra Toggle link in Apps preserves Super + Alt + Space's existing app list.

## Files, installation, and troubleshooting

### File map

Paths here are relative to `~/dotfiles`.

| File or directory | Purpose |
| --- | --- |
| `CUSTOMIZATIONS.md` | This handbook |
| `nvim/ORG-WRITING.md` | Shorter editor-specific reference |
| `nvim/lua/plugins/org-writing.lua` | Org plugin, lazy-loading, optional Typst LSP |
| `nvim/lua/config/org-writing.lua` | Document starters/pickers, PDF commands, spelling suggestions |
| `nvim/lazy-lock.json` | Pinned plugin revisions, including Orgmode |
| `bin/org-pdf` | Org-to-PDF CLI, template discovery/import, metadata handling |
| `typst/org/native-math.lua` | Pandoc filter preserving native Typst math |
| `typst/org/templates/` | Builtin and tracked custom PDF layouts |
| `typst/org/starters/` | Org examples for MLA, math, and technical work |
| `typst/README.md` | Lower-level exporter details and limitations |
| `typst/templates/write_up.typ` | Previous standalone Typst template, unchanged |
| `bin/typst` | Previous interactive Typst picker/watch workflow, unchanged |
| `omarchy/shell.json` | Top bar, transparency, clock anchor, widget layout |
| `omarchy/extensions/omarchy-menu.jsonc` | Menu entries for Toggle and light/dark mode |
| `bin/dotfiles-toggle-color-mode` | Manual Study Day/Night switch, keeping wallpaper |
| `packages/native.txt` | Package list, now including `pandoc-cli` |
| `tests/test_org_pdf.py` | Real PDF/export/template regression tests |
| `tests/test_org_writing.lua` | Real Neovim fold/spelling/template/export checks |

Your existing `~/.config/nvim` and `~/.config/omarchy` point into this repo.
Changes to the tracked configuration therefore affect the live setup. The
bootstrap links commands under `bin/` into `~/.local/bin`; `org-pdf` and the theme
toggle are already linked on this machine. Neovim can also resolve the exporter
directly from this checkout.

### Dependencies and moving to another machine

The PDF path needs Python 3, Pandoc with Typst output, and Typst. `--open` needs
`xdg-open` and a configured PDF viewer. Your existing Sioyek setup is not removed.
The MLA preset uses Liberation Serif, supplied by the existing `ttf-liberation`
package entry. The other layouts use the installed New Computer Modern family
and DejaVu Sans Mono. Check fonts with `/usr/bin/typst fonts` if the appearance
changes after migration.

Pandoc was installed here as `~/.local/bin/pandoc` from its official release,
because passwordless sudo was unavailable. It is not a binary committed into
dotfiles. On a new Arch system, use the repository's normal package/provisioning
workflow; `pandoc-cli` is in the package list. Orgmode's parser needs a compiler
and network access for first-time installation, not for ordinary subsequent use.
The optional Tinymist LSP is not required for Org editing or PDF export.

### Common problems

| Symptom | What to do |
| --- | --- |
| `OrgNew` or `OrgPdf` does not exist | Restart Neovim and confirm `~/.config/nvim` points at this repo |
| Shift-Tab inserts text or does nothing | Press Escape first, confirm the buffer is an `.org` file, then try again |
| New preset missing from the picker | Run `org-pdf --list-templates`; check its filename/name and import location |
| Existing Org file exports in old style | Use `:OrgTemplate mla`, `math`, or `technical`, then export again |
| Template import says it already exists | Edit the imported copy or import under a different name; imports do not overwrite |
| Import says `$body$` is missing | You have a standalone Typst document/package, not a Pandoc template |
| Typst reports an unknown math variable | Check Typst math syntax; this path does not translate LaTeX commands |
| PDF saved but viewer did not open | Use `:OrgPdf!` and open the saved PDF manually; check `xdg-open` |
| Figure cannot be read | Use a concrete `file:` link and keep assets under the Org file's directory |
| Preset edits look wrong | Export a short sample and inspect the PDF; a syntactically valid template may still have bad layout |
| A correct name is underlined | Use `zg` to add it to your personal dictionary |

### Validation

The setup is checked by exporting actual PDFs, extracting their text, checking
layout properties for the MLA preset, and exercising the installed Neovim
configuration's folds, template picker, correction picker, and PDF command.

To rerun the tests without touching your own notes:

```sh
mkdir -p "$HOME/.cache/org-writing-tests"
TMPDIR="$HOME/.cache/org-writing-tests" \
  python -m unittest discover -s ~/dotfiles/tests -p test_org_pdf.py -v
JCODE_SCRATCH_DIR="$HOME/.cache/org-writing-tests" \
  nvim --headless '+luafile ~/dotfiles/tests/test_org_writing.lua'
```

### Formatting references

The MLA preset's basic page requirements were checked against Purdue OWL's
MLA General Format and Works Cited guidance. Spacing implementation follows
Typst's paragraph/text documentation. Instructor-specific requirements and
bibliographic accuracy still need your review.

```text
https://owl.purdue.edu/owl/research_and_citation/mla_style/mla_formatting_and_style_guide/mla_general_format.html
https://owl.purdue.edu/owl/research_and_citation/mla_style/mla_formatting_and_style_guide/mla_works_cited_page_basic_format.html
https://typst.app/docs/reference/model/par/
https://typst.app/docs/reference/text/text/
```
