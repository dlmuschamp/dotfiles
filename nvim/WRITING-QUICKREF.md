# Neovim write-up quick reference

**Org for structure, Typst for math, PDF for submission.**
Open with `nvim paper.org`. Press `Esc` before using the shortcuts below.
`Space` is the leader key. Restart Neovim once after configuration changes.

## Daily workflow

1. Run `:OrgNew` to choose a template, filename, and title, or open an existing `.org` file.
2. Write with Org headings, Typst equations, and Org source blocks.
3. Use `Shift-Tab` to switch between outline and expanded views.
4. Run `:OrgPdf` to save, build a PDF beside the Org file, and open it.

| Action | Normal-mode keys / command |
| --- | --- |
| Save | `:w` |
| New write-up | `Space o w n` / `:OrgNew` |
| Change saved template | `Space o w t` / `:OrgTemplate` |
| Export and open PDF | `Space o w e` / `:OrgPdf` |
| Clean build: regenerate enabled plots and PDF | `Space o w r` / `:OrgCleanBuild` |
| Export without opening viewer | `:OrgPdf!` |
| Use report style for this export only | `:OrgPdf report` |
| Fold/unfold current heading | `Tab` |
| Cycle whole-file visibility | `Shift-Tab` |
| Next / previous visible heading | `}` / `{` |
| Choose spelling correction | `z=` / `:SpellSuggest` |
| Next / previous spelling error | `]s` / `[s` |
| Add word to personal dictionary | `zg` |

**Spelling does not silently change your text.** Idle suggestions do not move
your cursor. A chosen correction preserves your position, except that Neovim
must clamp a column beyond the new end of a shortened line.

## Math, code, and image insertion shortcuts

Snippets load automatically for all Org files. Restart Neovim after updating
configuration, or run `:lua require('config.org-snippets')` in an existing session.
No manual `:luafile` step is needed.

| Normal-mode command | Inserts |
| --- | --- |
| `:OrgSnippet math` | Centered Typst math |
| `:OrgSnippet inline` | Inline Typst math at the cursor |
| `:OrgSnippet matlab` | MATLAB source listing |
| `:OrgSnippet typst` | Typst source listing (printed code) |
| `:OrgSnippet rawtypst` | Typst export block (rendered markup) |
| `:OrgSnippet code` | Source listing with editable language |
| `:OrgSnippet image` | Caption and image file link |

Type over the selected placeholder. **Ctrl-j** advances to the next placeholder,
and **Ctrl-k** goes back. Start blocks on an empty line. Normal-mode localleader
shortcuts are `m`, `i`, `a`, `t`, `r`, `c`, and `f`, respectively. Inspect your
prefix with `:lua print(vim.g.maplocalleader or '\\')`.

### Embed a diagram or MATLAB plot

Save a PNG or SVG beside the Org file, or in a subdirectory. Run
`:OrgSnippet image`, enter the caption, press Ctrl-j, and enter its relative path:

```org
#+CAPTION: Fourier coefficients
[[file:Fourier_Coeff_Plot.png]]
```

Use `:OrgPdf` to embed the actual image in the PDF. This is PDF embedding, not
an inline graphical preview in Neovim. MATLAB code listings are not executed:
run your plotting script separately so its `exportgraphics` calls create the
PNG files first. Keep assets within the document directory or its subdirectories.

### Generate MATLAB plots with one toggle

**After changing MATLAB code or rounding, use `Space o w r`**, not `Space o w e`.
The rebuild command `:OrgCleanBuild` confirms execution, reruns every `:plot yes`
block from a fresh MATLAB process, regenerates its image, rebuilds the PDF, and
opens it. `:OrgCleanBuild!` skips opening. It is an alias of `:OrgPlotPdf`, which
also always regenerates enabled plots. No images are deleted first, and disabled
blocks are never executed. A MATLAB error stops the build, so fix that error
before treating existing images as updated. Plain `Space o w e` only exports
images already on disk and does not apply new rounding to them.

Use `:OrgSnippet matlab`, write your MATLAB code, and change only `:plot never`
to `:plot yes` when you want a figure. Then run **`:OrgPlotPdf`** and confirm.
`:OrgPlotPdf!` runs and exports without opening a viewer.

```org
#+begin_src matlab :exports code :eval never :plot never
% Your own MATLAB code goes here.
#+end_src
```

No manual filename, `exportgraphics`, or image link is required. After successful
MATLAB generation the runner adds a `:file figures/<document>-plot-1.png` header
and a matching image link below the block. It never changes your MATLAB body.
Existing paths and links are respected. `:OrgSnippet plot` starts already enabled.
Keep `:eval never`: explicit `:plot yes` authorizes this dedicated command, while
ordinary `:OrgPdf` still never executes code.

Enabled blocks run in order and share variables, like one script. Enable earlier
blocks if their variables are needed. Each enabled block must create a figure.
Figures are reset between blocks so old plots cannot silently be reused. Disabled
blocks never execute. Switching back to `:plot never` leaves existing images in
the PDF until you remove their links yourself.

The editor reloads generated links only if you have not edited the buffer during
execution. Save or reconcile any concurrent edits before rerunning. The command
requires confirmation and runs with your user permissions, not in a sandbox.
Local licensed MATLAB must be on PATH. CLI use is explicit authorization without
a prompt: `~/dotfiles/bin/org-plot-pdf file.org --timeout 300`.

Restart Neovim to load updated snippets and commands. For sign-in, manual image
embedding, filename checks, and authorship guidance, see
[local MATLAB and Org plots](../docs/matlab-org-plots.md).

## Start a document

```org
#+TITLE: My write-up
#+AUTHOR: Your Name
#+INSTRUCTOR: Professor Name
#+COURSE: Course Name
#+DATE: October 20, 2026
#+PDF_TEMPLATE: report
#+OPTIONS: toc:nil num:nil

* Introduction
Explain the problem. Use *bold*, /italic/, and inline code `mean(values)`.

** Details
A subsection belongs under its parent heading.

* Conclusion
Summarize the result.
```

Change the example date and metadata for your assignment. `:OrgTemplate` lists
available styles and stores the choice in `#+PDF_TEMPLATE:`. Standard styles:
`report` for structured write-ups, `notes` for compact notes, `essay` for an
MLA-like essay. This machine also has `math`, `technical`, and `mla` presets.
Use the picker to see what is installed. An instructor's requirements take
precedence over any preset.

## Math: type Typst, not LaTeX

| Want | Type |
| --- | --- |
| Inline equation | `$a^2 + b^2 = c^2$` |
| Fraction | `$(a+b)/c$` |
| Square root | `$sqrt(x)$` |
| Subscript / superscript | `$x_i^2$` |
| Greek letters | `$alpha + beta + theta$` |
| Summation | `$sum_(k=1)^n k$` |
| Integral | `$integral_0^1 x dif x$` |
| Mean / overbar | `$overline(x)$` |
| Column vector | `$vec(x, y)$` |
| Matrix: commas separate columns, semicolons separate rows | `$mat(1, 2; 3, 4)$` |

Inline delimiters are tight: `$sqrt(2)$`. For a centered display equation,
use a standalone line with spaces inside the dollars and blank lines around it:

```org
* Derivation
The finite sum has the following closed form.

$ sum_(k=1)^n k = (n(n+1))/2 $

For a longer equation, put the opening and closing dollars on their own lines:

$
mat(1, 2; 3, 4) vec(x, y) = vec(x + 2y, 3x + 4y)
$
```

Do **not** use LaTeX commands such as `\frac`, `\sqrt`, or `\begin{matrix}`
in this exporter. `$$ ... $$` display math also works.

## Code: inline or a block

Inline: `` `array[i]` ``, `=array[i]=`, or `~array[i]~`.
Backtick pairs must stay on one line, without padding inside them, and be
separated from surrounding words by spaces/punctuation. Backtick formatting is
an export convenience. `=...=` and `~...~` are native Org markup.
For language-highlighted inline code, use `src_python{print(42)}`.

For a listing, use an **Org source block**, not triple-backtick Markdown fences:

```org
* Implementation
#+begin_src python :exports code :eval never
def mean(values):
    if not values:
        raise ValueError("need at least one value")
    return sum(values) / len(values)
#+end_src
```

Replace `python` with the language you need:

| Language | Recommended block label |
| --- | --- |
| MATLAB | `matlab` |
| C | `c` or `C` |
| C++ | `cpp` |
| Python | `python` |
| JavaScript / TypeScript | `javascript` / `typescript` |
| Shell / Lua / Rust | `bash` / `lua` / `rust` |
| Typst code shown as a listing | `typst` |

Indentation, blank lines, and line breaks are preserved. Exported tabs use
four-column stops. Code is printed, **never executed by the exporter**.
Keep lines short enough to fit the page. Unknown languages print without colors.

### Edit a source block in its own language buffer

Put the cursor inside the block, then use:

| Action | Keys |
| --- | --- |
| Open source editor | `Space o '` |
| Save edits back, keep source editor open | `Space o w` |
| Save edits back and leave source editor | `Space o '` |
| Cancel source editing | `Space o k` |

In this special source buffer, `Space o w` means **save source**, not the
write-up submenu. Save the parent Org file afterward with `:w`.

For aligned text without highlighting:

```org
#+begin_example
    label       value
        nested  42
#+end_example
```

## Native Typst layout when you need it

Normal prose follows **Org** syntax. Put Typst-only layout/functions in an
explicit export block so they render instead of appearing as ordinary text:

```org
#+begin_export typst
#align(center)[#box(inset: 8pt, stroke: 0.5pt)[A centered result]]
#+end_export
```

Inline raw Typst uses `@@typst:...@@`. A `#+begin_src typst` block is a
**printed listing**, not rendered layout. Only export documents/raw Typst you trust.

## If something looks wrong

- **Math prints as text:** use tight inline dollars, or put display math on its
  own lines with blank lines around it. Check that the expression is Typst syntax.
- **Code loses spacing:** use a source/example block, not an ordinary paragraph.
- **No code colors:** check the language label. In Neovim, restart after setup
  and allow missing Treesitter parsers to install. Prefer `cpp` for C++.
- **Typst formatting prints literally:** use a Typst export block.
- **Export fails:** read the error notification. The previous PDF is kept if
  conversion fails. `:OrgPdf!` avoids launching a viewer while troubleshooting.
- **Images fail:** use `[[file:figure.svg]]` with the asset inside your Org
  document's directory or a subdirectory.

## Examples and deeper help

- Full worked code/math example: `~/dotfiles/typst/org/code-and-math.org`
- Full editor guide: [ORG-WRITING.md](ORG-WRITING.md)
- Export/template details: [../typst/README.md](../typst/README.md)

Open this reference from Neovim:

```vim
:edit ~/dotfiles/nvim/WRITING-QUICKREF.md
```
