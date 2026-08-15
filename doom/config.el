;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-one)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")

;;; Org + Typst math
;; Write Typst inside $...$ (not LaTeX). Preview with typst-overlay; export with
;; ox-typst (C-c C-e y). Inline: $a^2$. Display: $ sum_(k=1)^n k $ (spaces).

(after! org
  ;; LaTeX fragment preview fights Typst math — keep it off by default.
  (setq org-startup-with-latex-preview nil)
  ;; Sketches from Xournal++ / screenshots land next to the heading.
  (setq org-attach-use-inheritance t
        org-attach-dir-relative t))

(use-package! ox-typst
  :after org
  :config
  ;; Pass $...$ through as Typst instead of translating from LaTeX.
  (setq org-typst-from-latex-fragment #'org-typst-from-latex-with-naive
        org-typst-from-latex-environment #'org-typst-from-latex-with-naive))

(use-package! typst-ts-mode
  :mode "\\.typ\\'"
  :config
  (setq typst-ts-mode-watch-options "--open")
  ;; Ensure the Typst tree-sitter grammar exists for .typ buffers.
  (unless (treesit-language-available-p 'typst)
    (require 'typst-ts-misc-commands)
    (typst-ts-mc-install-grammar)))

(defun luciano/typst-overlay-analyze-org ()
  "Find Typst `$...$` math in Org, including multi-line display equations."
  (let (math-nodes)
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "\\$\\(?:[^$]\\|\n\\)+?\\$" nil t)
        (let* ((beg (match-beginning 0))
               (end (match-end 0))
               (text (match-string-no-properties 0)))
          (push (make-typst-overlay-math-node
                 :beg beg
                 :end end
                 :text text
                 :text-hash (md5 text))
                math-nodes))))
    (make-typst-overlay-analysis
     :code-nodes nil
     :math-nodes (typst-overlay--sort-math-nodes (nreverse math-nodes))
     :first-error nil)))

(use-package! typst-overlay
  :commands (typst-overlay-mode typst-overlay-refresh)
  :hook ((org-mode . typst-overlay-mode)
         (typst-ts-mode . typst-overlay-mode)
         (after-save . typst-overlay-save-refresh))
  :config
  (setq typst-overlay-scale 1.3)
  (defadvice! luciano/typst-overlay-use-org-analyzer (&rest _)
    "Use multiline-capable Org math detection."
    :after #'typst-overlay--enable
    (when (derived-mode-p 'org-mode)
      (setq-local typst-overlay-analyzer #'luciano/typst-overlay-analyze-org)
      (typst-overlay-refresh))))

;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `with-eval-after-load' block, otherwise Doom's defaults may override your
;; settings. E.g.
;;
;;   (with-eval-after-load 'PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look them up).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.
