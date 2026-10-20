# Org writing in Neovim

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
| `:OrgPdf!` | Save and export without opening a viewer |
| `:OrgPdf report` | Export once using a particular template |
| `Space o w i` / `:OrgTemplateImport` | Import a local Pandoc Typst template |
| `z=` / `Space o w s` / `:SpellSuggest` | Show and choose spelling corrections for the word under the cursor |
| `]s` / `[s` | Jump to next / previous spelling error |
| `zg` | Add a word to your personal spelling dictionary |
| `Space o a` / `Space o c` | Org agenda / capture |

Spelling is enabled for Org, Markdown, plain text, and Typst. Pause on a misspelled
word in normal mode to see up to three actual suggestions after the line.
Press `z=` for the selectable list. Nothing is silently auto-corrected. Insert
mode also retains Neovim's built-in `Ctrl-x s` spelling completion.

`Space o w` is the writing submenu in WhichKey. Existing Org tags, TODOs, source
editing, and other default Org bindings are kept. In Org's special source-block
editing buffer, its existing `Space o w` save action takes precedence.

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
JCODE_SCRATCH_DIR="$HOME/.cache/org-writing-tests" \
  nvim --headless '+luafile ~/dotfiles/tests/test_org_writing.lua'
```

Create the scratch directory first. The editor test uses your real LazyVim
configuration and a dedicated fixture, tests folding, template picker and
spelling selection, then compiles an actual PDF. It does not edit your notes.
