# Org writing in Neovim

For a daily cheat sheet, see [WRITING-QUICKREF.md](WRITING-QUICKREF.md).

Open any existing `.org` file with `nvim`. This edits the same plain-text file as
Emacs, without running an Emacs process. Restart existing Neovim instances once
after installing this configuration. Orgmode and its parser are installed on
first use by Lazy/Orgmode. A C compiler and network are needed for that first
parser installation, not for routine note-taking.

## Everyday controls

All keys below are in **normal mode**. `<leader>` is Space.

| Key / command | What it does |
| --- | --- |
| `Tab` | Cycle folding at the current heading |
| `Shift-Tab` | Cycle whole-file visibility |
| `Space o w n` / `:OrgNew` | Choose a template, filename, and title for a new Org document |
| `Space o w t` / `:OrgTemplate` | Choose a different PDF template for the current document |
| `Space o w e` / `:OrgPdf` | Save, export PDF beside the Org file, and open it |
| `Space o w r` / `:OrgCleanBuild` | Confirm, regenerate enabled MATLAB graphics, rebuild PDF, and open it |
| `:OrgPdf!` | Save and export without opening a viewer |
| `:OrgPdf report` | Export once using a particular template |
| `Space o w i` / `:OrgTemplateImport` | Import a local Pandoc Typst template |
| `z=` / `Space o w s` / `:SpellSuggest` | Show and choose spelling corrections for the word under the cursor |
| `]s` / `[s` | Jump to next / previous spelling error |
| `zg` | Add a word to your personal spelling dictionary |
| `Space o a` / `Space o c` | Org agenda / capture |

Spelling is enabled for Org, Markdown, plain text, and Typst. Pause on a misspelled
word in normal mode to see up to three actual suggestions after the line.
Press `z=` for the selectable list. Idle suggestions never move the cursor or
scroll the window. Choosing a correction preserves each window's current cursor
and view (a column beyond the new end of a shortened line is clamped by Neovim).
Nothing is silently auto-corrected. Insert
mode also retains Neovim's built-in `Ctrl-x s` spelling completion.

`Space o w` is the writing submenu in WhichKey. Existing Org tags, TODOs, source
editing, and other default Org bindings are kept. In Org's special source-block
editing buffer, its existing `Space o w` save action takes precedence.

## Code and math without leaving Org

Keep `* Section` / `** Subsection` headings and the same `Tab` / `Shift-Tab`
outline navigation. The document is **Org**, with native Typst inside math
fragments. Ordinary prose still uses Org `*bold*`, `/italic/`, lists, and tables,
not arbitrary Typst markup or LaTeX commands.

- Inline code: `` `array[i]` ``, `=array[i]=`, or `~array[i]~`. Single-backtick
  snippets are a PDF-export convenience. Org-native `=...=` / `~...~` also have
  native Org editor markup. Backtick pairs must be on one line, with no padding
  inside the delimiters, separated from surrounding words by spaces/punctuation.
- Inline math: `$sqrt(x^2 + y^2)$` or `$(a+b)/c$`.
- Display math: put `$ sum_(k=1)^n k = (n(n+1))/2 $` on its own line, with
  blank lines around it. For longer equations, put `$` on opening/closing lines.
- Code listings: use Org source blocks, **not Markdown triple-backtick fences**.
  The language label chooses highlighting in the editor and exported PDF.

```org
* Implementation
Inline code: `mean(values)`. Inline math: $overline(x)$.

#+begin_src python :exports code :eval never
def mean(values):
    if not values:
        raise ValueError("need a value")
    return sum(values) / len(values)
#+end_src

** Derivation

$ overline(x) = (sum_(i=1)^n x_i)/n $
```

Use `matlab`, `C` or `c`, `cpp` (also `C++` on PDF export), `python`,
`javascript`, `typescript`, `bash`, `lua`, or `rust` after `#+begin_src`.
Source code is **never executed** by the exporter. Leading spaces, nested
indentation, and line breaks are preserved. Tabs use four-column stops in
PDF code listings. Use `#+begin_example` / `#+end_example` for literal aligned
text without highlighting. Ordinary paragraph indentation is typesetting, not
literal whitespace, so use one of these blocks when spacing matters.

Syntax parsers for these languages are installed through the existing
Treesitter setup. The first parser build needs a compiler and network access.
Inside a source block, Org's source-edit command `Space o '` opens a dedicated
language buffer. `Space o w` writes it back, and `Space o k` cancels that edit.
The existing Org heading navigation remains unchanged.

For advanced native Typst layout, wrap it in `#+begin_export typst` /
`#+end_export`, or use `@@typst:...@@` inline. A `#+begin_src typst` block
prints Typst code instead of rendering it. Do not mix LaTeX math commands into
Typst math. Unsupported code languages still print as plain monospace code.

Copyable examples for all the languages above, math, and raw layout are in
`~/dotfiles/typst/org/code-and-math.org`. Open it with Neovim and use `:OrgPdf`,
or copy its sections into your own `.org` file. Restart Neovim after changing
configuration to load the new parser setup.

## Local MATLAB plots: generate, link, and export

See [the MATLAB plotting guide](../docs/matlab-org-plots.md) for local CLI setup,
account sign-in, and both supported workflows. MATLAB Online is not needed.

Use `Space o w r` / `:OrgCleanBuild` after editing MATLAB or rounding. It always
reruns all `:plot yes` blocks, then rebuilds the PDF. `:OrgCleanBuild!` skips the
viewer. This is an explicit alias of `:OrgPlotPdf`, not a deletion command.
Disabled blocks remain disabled. `Space o w e` only exports existing images.
Execution errors stop regeneration and must be fixed before plots are current.

- Preserve existing code: run your own `.m` script with
  `matlab -batch "run('my_plots.m')"`, link its PNG using `[[file:my_plot.png]]`,
  then run `:OrgPdf`. Ordinary PDF export never executes code.
- Direct generate-and-embed: insert `:OrgSnippet matlab`, write your own code,
  and change only `:plot never` to `:plot yes`. Run `:OrgPlotPdf` and confirm.
  It automatically adds output paths and matching image links after successful
  generation. `:OrgPlotPdf!` runs and exports without opening a viewer.
- Enabled blocks share variables and run in order. Enable prerequisite plotting
  blocks too. Each enabled block must create a figure, which is saved before
  figures are reset for the next block. Disabled blocks never run.
- `:plot yes` explicitly authorizes this command even with `:eval never`.
  Ordinary `:OrgPdf` still never executes code. Existing explicit paths and
  links are honored. Generated links reload without discarding unsaved edits.
- The MATLAB bodies remain unchanged. Do not add assertions or rewrite math
  just to configure tools. Existing figures are not proof of their source.

## Write prose, export formatted PDFs

Use `:OrgNew` instead of copying boilerplate. It adds editable title, author,
date, instructor, and course fields. It does not save or overwrite an existing
file until you explicitly save/export. You can also add this header to an
existing file:

```org
#+TITLE: My essay
#+AUTHOR: Damian Luciano Muschamp
#+DATE: October 19, 2026
#+PDF_TEMPLATE: essay
#+INSTRUCTOR: Professor Name
#+COURSE: Course Name
#+OPTIONS: toc:nil num:nil

* Introduction
Write ordinary paragraphs, *bold*, /italic/, and lists here.

Inline Typst math: $a^2 + b^2 = c^2$.

$ sum_(k=1)^n k = n (n + 1) / 2 $
```

The export pipeline is **Org → Pandoc → Typst → PDF**, with no Emacs or LaTeX
runtime needed. Use Typst math syntax, not LaTeX commands such as `\\frac`.
Standalone `$ ... $` equations are supported for compatibility with your existing
Org workflow. `$$...$$` display equations also work. See the export guide for
exact supported syntax and limitations.

Built-in choices are `essay` (MLA-like, based on your existing `write_up.typ`),
`report`, and `notes`. Template selection is stored as `#+PDF_TEMPLATE:` in the
Org document, so it survives restarting Neovim. Instructor requirements still
take precedence over the essay preset, which is not a certified MLA/APA template.

## Templates and dependencies

Read `../typst/README.md` for export syntax, template customization/import,
metadata, CLI usage, and caveats. Imported files must be **Pandoc Typst templates**,
not arbitrary Typst Universe packages or standalone `.typ` essays. Copy an
included preset, edit it, and import it to make your own reusable style.

A representative document lives at `../typst/org/example.org`.
The existing `typst` launcher and `typst/templates/write_up.typ` are unchanged.

The repository bootstrap links the new `bin/org-pdf` automatically, and the
Neovim integration can also resolve it directly from the dotfiles checkout.
Required tools are Python 3, Pandoc with Typst output, Typst, and a PDF viewer
for `:OrgPdf` (`:OrgPdf!` needs no viewer). `packages/native.txt` includes
`pandoc-cli`. On this machine Pandoc was installed user-locally from the official
release because passwordless sudo was unavailable. Other machines can install
`pandoc-cli` through the normal provision/package workflow.

## Checks

```sh
python -m unittest discover -s ~/dotfiles/tests -p 'test_org_pdf.py' -v
python -m unittest discover -s ~/dotfiles/tests -p 'test_org_plot_pdf.py' -v
JCODE_SCRATCH_DIR="$HOME/.cache/org-writing-tests" \
  nvim --headless '+luafile ~/dotfiles/tests/test_org_writing.lua'
```

Create the scratch directory first. The editor test uses your real LazyVim
configuration and a dedicated fixture, tests folding, template picker and
spelling selection, then compiles an actual PDF. It does not edit your notes.

Plot-command UI tests use a fake subprocess and do not require MATLAB:

```sh
JCODE_SCRATCH_DIR="$HOME/.cache/org-writing-tests" \
  nvim --headless '+luafile ~/dotfiles/tests/test_org_plot_editor.lua'
```

For the full automatic toggle workflow, use the opt-in acceptance test below.
It needs licensed local MATLAB and `pdfimages` and runs real plotting code in a
separate scratch fixture, never in your homework. It verifies disabled blocks,
shared variables, automatic paths/links, unchanged MATLAB bodies, editor reload,
and two actual images embedded in the exported PDF:

```sh
JCODE_SCRATCH_DIR="$HOME/.cache/org-writing-tests" \
  nvim --headless '+luafile ~/dotfiles/tests/test_org_plot_matlab.lua'
```
