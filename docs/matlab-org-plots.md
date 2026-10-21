# Local MATLAB plots and Org PDFs

Use local MATLAB for computation, Org for your write-up, and Typst for PDF export.
MATLAB Online is not required. This guide describes the configured machine, not
an automatic MATLAB installer or a license bundled with the dotfiles.

## Quick start: change only `:plot never` to `:plot yes`

1. In an Org document, run `:OrgSnippet matlab` and write your own MATLAB code.
   Its header starts with `:plot never`, so it is display-only by default.
2. When you want its figure, change just `:plot never` to `:plot yes`.
3. Run `:OrgPlotPdf` and confirm execution. The command saves the document,
   runs the enabled blocks, generates images, inserts any missing image links,
   builds the PDF, and opens it. `:OrgPlotPdf!` does this without opening a viewer.

Before opting in, the structure is:

```org
#+begin_src matlab :exports code :eval never :plot never
% Your own MATLAB code goes here.
#+end_src
```

Change only the final `never` after `:plot` to `yes`. Leave `:eval never` alone:
`:plot yes` is the explicit execution authorization for the dedicated plotting
command. Ordinary `:OrgPdf` still never executes source blocks.

There is no need to type `:file`, an image link, or `exportgraphics` yourself.
The runner adds a path such as `:file figures/assignment-plot-1.png` to the header
and `[[file:figures/assignment-plot-1.png]]` after the block after successful
MATLAB generation. It creates the directory too. Existing explicit `:file`
paths and image links are respected, not duplicated. `:OrgSnippet plot` is a
shortcut that starts already opted in, with a placeholder for your own code.
Restart Neovim after updating the configuration to load these changes.

## What runs and what stays unchanged

### Clean graphics rebuild versus ordinary PDF export

After changing calculations, display settings, or rounding, press **Space o w r**
or run **`:OrgCleanBuild`** and confirm. It starts fresh MATLAB execution of all
`:plot yes` blocks and regenerates their graphics, then rebuilds and opens the
PDF. `:OrgCleanBuild!` does the same without opening a viewer. The command is an
explicit alias of `:OrgPlotPdf`, which already regenerates on every run.

**Space o w e / `:OrgPdf` only exports existing images.** It cannot apply a
changed `round(..., 2)` expression to PNGs already on disk. If MATLAB fails,
fix the reported code error before considering old images updated. Clean build
does not delete existing files first or execute disabled blocks. It does not
insert, remove, or alter rounding in your MATLAB code.

- Only top-level MATLAB blocks with literal `:plot yes` run. Disabled, absent,
  inherited, or commented opt-ins do not run.
- Enabled blocks run in document order with shared MATLAB variables, like one
  script. If a later block needs coefficients from an earlier block, enable
  that earlier block too. Disabled blocks do not initialize variables.
- Each enabled block must create a figure. The runner saves the current figure
  at the end of that block. It closes figures before the next block, but keeps
  the MATLAB variables. A block that only computes and creates no figure will
  fail rather than silently export a previous plot.
- The runner does not rewrite MATLAB bodies, calculations, or prose. It only
  adds missing output-path headers and image links after successful generation.
  It refuses to publish if the saved document changed while MATLAB was running.
- Neovim reloads generated links into an untouched buffer. If you edited the
  buffer during execution, those edits are kept. Reconcile the generated links
  on disk before saving over them.
- Setting `:plot never` again disables future execution. It does not remove
  images or links already generated. Ordinary export will still show them.
- Execution is not sandboxed. Only run code you trust. The confirmation includes
  authorization to add image paths and links, not to change computations.

## Verify the image link

After a successful run, the header's `:file figures/assignment-plot-1.png` and
its `[[file:figures/assignment-plot-1.png]]` link should match exactly, including
case. Paths are relative to the Org file, not Neovim's working directory, and
must stay within that document's directory tree. Move the link to choose where
its figure appears in the PDF. Add `#+CAPTION:` directly before it if desired.
To choose your own output filename, supply a relative PNG/SVG `:file` header.
Automatic names use the document stem and top-level MATLAB block ordinal. Once
a path is written into the header, it remains stable when blocks move.

Inspect both the fresh PNG and the rebuilt PDF. Existing files are not proof
of a successful new run. Errors stop export, and unsuccessful MATLAB generation
does not add links. `:OrgPdf` alone cannot generate missing images.

## Existing scripts and manual embedding still work

Keep existing code exactly as written if that is what you want. Run your own
script separately, then link its saved image and use ordinary `:OrgPdf`:

```sh
cd /path/to/assignment
matlab -batch "run('my_plots.m')"
~/dotfiles/bin/org-pdf assignment.org
```

```org
[[file:my_plot.png]]
```

`:OrgSnippet image` inserts a caption and image link. The direct MATLAB script
must save its images itself, unlike the automatic Org plot runner.

## Installed CLI and sign-in

On this machine MATLAB is at `~/Applications/MATLAB/R2026b/bin/matlab`.
`~/.local/bin/matlab` launches it with `-licmode onlinelicensing` to avoid the
default licensing startup crash observed here. This is local MATLAB, not MATLAB
Online. The launcher was created locally, not by the dotfiles bootstrap.
Other machines need their own installation, license, and MATLAB on PATH.
`MATLAB_ROOT=/path/to/MATLAB/R2026b` overrides the launcher's installation path.

```sh
command -v matlab
matlab -batch "disp(version); disp(license('test','MATLAB'));"
~/dotfiles/bin/org-plot-pdf assignment.org --timeout 300
# Optional alternate launcher:
~/dotfiles/bin/org-plot-pdf assignment.org --matlab "$HOME/.local/bin/matlab" --timeout 300
```

Complete the MathWorks sign-in window if requested. Do not put passwords or
verification codes in scripts. A license result of `1` confirms the check.
The CLI has no execution confirmation prompt, so invoking it is authorization.
`--timeout` is in seconds. A missing command in Neovim normally means to restart
Neovim after configuration changes.

## Authorship and current HW4 status

Tool setup and embedding do not authorize rewriting mathematics, variable names,
algorithms, or numerical choices. Do not add assertions, expected-answer formulas,
or substitute solutions to an assignment as part of configuring tools. Report
execution errors separately. Do not substitute Python plots for MATLAB output.

The HW4 `LOCAL-PLOTS-README.md` records its specific state. Original calculations
and prose were restored, with only image links and blank lines added. This
feature does not opt that document into execution or change its computations.
Its existing PNGs came from earlier assistant-modified code, not the restored
original, so they are not verified outputs of that original. Regenerate using
the exact code you choose before treating images as its results.
