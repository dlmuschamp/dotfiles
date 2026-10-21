# Local MATLAB plots and Org PDFs

Use local MATLAB for computation, Org for your write-up, and Typst for PDF export.
MATLAB Online is not required. This guide describes the configured machine, not
an automatic MATLAB installer or a license bundled with the dotfiles.

## Preserve your own work

Embedding images or configuring tools does not authorize rewriting calculations.
Keep the author's mathematics, prose, variable names, algorithms, and numerical
choices unchanged unless they explicitly request computational edits. Do not add
assertions, expected-answer formulas, or alternate solutions to an assignment as
part of setting up plotting. Surface execution errors separately instead.

A source listing and its linked image are independent files. Export does not
prove that the image came from the displayed code. If code is restored or edited,
regenerate the images with that exact code before treating them as its results.
Do not silently substitute Python-generated plots for MATLAB output.

## Installed CLI and sign-in

On this machine:

- MATLAB: `~/Applications/MATLAB/R2026b/bin/matlab`
- PATH launcher: `~/.local/bin/matlab`
- Launcher options: `-licmode onlinelicensing`, scoped to this launch
- Optional installation override: `MATLAB_ROOT=/path/to/MATLAB/R2026b`

The launcher selects account licensing to avoid the default licensing startup
crash observed here. This still runs MATLAB locally, not MATLAB Online. The
launcher was created locally and is not installed by the dotfiles bootstrap.
On another machine, install and license MATLAB separately and put its launcher
on PATH. Do not assume that copying this repository installs MATLAB.

Check the CLI, then sign in to the MathWorks window if requested:

```sh
command -v matlab
matlab -batch "disp(version); disp(license('test','MATLAB'));"
```

A license result of `1` confirms the check passed. Do not enter passwords or
verification codes into scripts. Initial sign-in can open a window even though
subsequent calculation and plot generation use the CLI.

Run a script you wrote from the directory where its input/output files belong:

```sh
cd /path/to/assignment
matlab -batch "run('my_plots.m')"
```

Your script can save a figure with
`exportgraphics(fig, 'my_plot.png', 'Resolution', 300)`.
You choose the computation, figure handle, and filename.

## Workflow A: existing code and images, no automatic execution

This is the appropriate workflow for preserving existing homework code exactly.
Run your own MATLAB script separately, then link its saved image in the Org file:

```org
#+CAPTION: My plot
[[file:my_plot.png]]
```

Keep image paths relative to the Org file and inside its directory tree.
`:OrgSnippet image` inserts a caption and image link. `:OrgSnippet matlab` inserts
a display-only MATLAB listing with `:eval never`.

- `:OrgPdf` saves the Org buffer, embeds existing images, builds the PDF beside
  the Org file, and opens it.
- `:OrgPdf!` saves and exports without opening a viewer.
- Terminal equivalent: `~/dotfiles/bin/org-pdf assignment.org`

These commands never execute source blocks. They also do not check whether an
existing image matches the source listing. PDF embedding is not an inline
image preview in Neovim.

## Workflow B: explicitly opt into MATLAB execution

Only use this if you choose to make your plotting blocks runnable.
`:OrgSnippet plot` inserts a template with these headers and a matching link:

```org
#+begin_src matlab :plot yes :file figures/my_plot.png :exports code :eval yes
% Your own self-contained plotting code goes here.
% It must create a figure. This placeholder is not a runnable example.
#+end_src

[[file:figures/my_plot.png]]
```

`:OrgPlotPdf` asks for confirmation, executes the opted-in blocks, exports each
block's current figure to its `:file`, builds the PDF, and opens it.
`:OrgPlotPdf!` skips opening the viewer, not confirmation or execution.
Restart Neovim after configuration changes if the command is missing.

```sh
~/dotfiles/bin/org-plot-pdf assignment.org --timeout 300
# An alternate launcher can be supplied explicitly:
~/dotfiles/bin/org-plot-pdf assignment.org --matlab "$HOME/.local/bin/matlab" --timeout 300
```

The CLI is itself explicit execution authorization and has no confirmation
prompt. `--timeout` is in seconds. Blocks run in document order but in separate
function workspaces: variables do not carry between blocks. Do not silently
rewrite an existing document just to satisfy this isolation rule. Use workflow A
if your own script or original blocks intentionally share state.

### Check that generation and linking match

1. Save the `.org` file. Run `:OrgSnippet plot` on an empty line, then use Ctrl-j
   to move through the shared filename, your code, and the caption placeholders.
2. Ensure the header is `:plot yes :file figures/my_plot.png :eval yes` and the
   link is `[[file:figures/my_plot.png]]`, with identical spelling and case.
   The generated figure is placed at the link's location in the PDF.
3. Supply your own complete code that creates the intended current figure.
   Do not rely on a previous block's variables. There is no need to manually
   create the `figures` directory for the runner's automatic export.
4. Run `:OrgPlotPdf`, choose the run option, and wait for the success message.
   Check that `figures/my_plot.png` exists beside the document with a fresh
   modification time, then inspect that figure in the rebuilt PDF.
5. A missing image error means to check the exact relative link or generate the
   file first. `:OrgPdf` alone will not generate a missing image. A no-opted-in-
   blocks error means the document still has display-only headers. Do not
   change them unless you intend to authorize execution.

Only literal `:plot yes` selects a MATLAB block. It requires a relative PNG/SVG
`:file` and must not have `:eval never` or `:eval no`. The runner automatically
exports the current figure, so extra direct exports are unnecessary in new
opted-in blocks. MATLAB code is not sandboxed. Run only code you trust.
An execution failure stops the export. Existing files are not evidence of a
successful new run. A startup crash or sign-in requirement should be diagnosed
without altering the assignment's mathematics.

## Current HW4 status

The assignment's `LOCAL-PLOTS-README.md` records its specific state. Original
computations and prose were restored exactly, with only image links and blank
lines added. Those original blocks retain `:eval never` and are not opted into
`:OrgPlotPdf`. Existing linked PNGs came from earlier assistant-modified code,
not the restored original, so they are not verified outputs of that original.
Use workflow A until the author chooses what code to run. MATLAB remains
installed and account sign-in has succeeded.
