;;; test-doom-study.el --- Isolated real-theme regression tests -*- lexical-binding: t; -*-

;; Run from the repository root:
;;   emacs --batch -Q -l docs/test-doom-study.el
;; Requires Doom's installed doom-themes checkout at
;; ~/.config/emacs/.local/straight/repos/themes (standard Doom installation).
;; Only explicitly allowlisted theme definitions are evaluated from config.el.
;; No full user configuration, private workflows, live Emacs or watcher is used.
;; Actual installed Doom themes and repository palette files are exercised.

(require 'cl-lib)
(require 'ert)
(require 'json)
(require 'org)

(defconst study-test-root
  (file-name-directory
   (directory-file-name (file-name-directory (or load-file-name buffer-file-name)))))
(defconst study-test-themes
  (expand-file-name "~/.config/emacs/.local/straight/repos/themes/"))
(unless (file-readable-p (expand-file-name "doom-themes.el" study-test-themes))
  (error "Install Doom's doom-themes checkout at %s before running this test"
         study-test-themes))
(add-to-list 'load-path study-test-themes)
(add-to-list 'custom-theme-load-path (expand-file-name "themes/" study-test-themes))
(require 'doom-themes)

(defvar doom-theme 'doom-one)
(defvar study-test-loads 0)
(defvar study-test-font-forms nil)
(with-temp-buffer
  (insert-file-contents (expand-file-name "doom/config.el" study-test-root))
  (emacs-lisp-mode)
  (check-parens)
  (goto-char (point-min))
  (condition-case nil
      (while t
        (let ((form (read (current-buffer))))
          ;; Capture only the two explicit font declarations, never evaluate
          ;; private workflows or the rest of the user's configuration.
          (when (and (eq (car-safe form) 'setq)
                     (memq (cadr form) '(luciano/ui-font-family doom-font)))
            (push form study-test-font-forms))
          (when (and (memq (car-safe form) '(defun defvar))
                     (memq (cadr form)
                           '(luciano/omarchy-colors luciano/omarchy-colors-file
                             luciano/omarchy-applying-theme luciano/omarchy-study-base
                             luciano/load-omarchy-colors luciano/omarchy-color
                             luciano/omarchy-syntax-color luciano/omarchy-select-base
                             luciano/apply-study-theme-faces
                             luciano/apply-omarchy-theme-faces)))
            (eval form t))))
    (end-of-file nil)))
(custom-declare-theme 'luciano-study 'luciano-study "Study test overrides")

(defun study-test-reset ()
  "Reset test state so each test also runs independently."
  (mapc #'disable-theme (copy-sequence custom-enabled-themes))
  (setq doom-theme 'doom-one
        luciano/omarchy-study-base nil
        luciano/omarchy-colors nil
        study-test-loads 0))

(defun study-test-palette (mode)
  "Return proposal colors for MODE with the study integration marker."
  (let* ((json-object-type 'alist)
         (json-key-type 'string)
         (proposal (json-read-file
                    (expand-file-name "docs/display-palette-proposal.json"
                                      study-test-root)))
         (colors (copy-tree (cdr (assoc mode proposal)))))
    (push (cons "study_background" (cdr (assoc "background" colors))) colors)
    colors))

(defun study-test-spec (theme face attribute)
  "Return ATTRIBUTE in FACE's unconditional spec from THEME."
  (plist-get
   (cadr (assq t (nth 3 (cl-find face (get theme 'theme-settings) :key #'cadr))))
   attribute))

(defun study-test-apply (colors)
  "Apply COLORS without reading or changing the active desktop palette."
  (cl-letf (((symbol-function 'luciano/load-omarchy-colors)
             (lambda () (setq luciano/omarchy-colors colors))))
    (luciano/apply-omarchy-theme-faces)))

(defun study-test-nested-theme-hook (&rest _)
  "Simulate Doom's nested theme hook using the real load-theme API."
  (cl-incf study-test-loads)
  (luciano/apply-omarchy-theme-faces))
(advice-add 'load-theme :after #'study-test-nested-theme-hook)

(ert-deftest study-cycle ()
  "Switch bases only when needed and restore the legacy nonstudy mapping."
  (study-test-reset)
  (study-test-apply (study-test-palette "light"))
  (should (eq doom-theme 'doom-one-light))
  (should (= study-test-loads 1))
  (should (memq 'doom-one-light custom-enabled-themes))
  (dolist (entry '((font-lock-keyword-face . "keywords")
                   (font-lock-function-name-face . "functions")
                   (font-lock-string-face . "strings")
                   (font-lock-constant-face . "numbers")
                   (font-lock-type-face . "types")))
    (should (equal (study-test-spec 'user (car entry) :foreground)
                   (cdr (assoc (cdr entry) (study-test-palette "light"))))))
  (should (equal (study-test-spec 'luciano-study 'org-block :background)
                 (cdr (assoc "current_line" (study-test-palette "light")))))
  (dolist (entry '((font-lock-doc-face . "comments")
                   (error . "errors")
                   (isearch . "search_text")
                   (minibuffer-prompt . "keywords")
                   (company-tooltip . "text")))
    (should (equal (study-test-spec 'luciano-study (car entry) :foreground)
                   (cdr (assoc (cdr entry) (study-test-palette "light"))))))
  (study-test-apply (study-test-palette "light"))
  (should (= study-test-loads 1))
  (study-test-apply (study-test-palette "dark"))
  (should (eq doom-theme 'doom-one))
  (should (= study-test-loads 2))
  (should-not (memq 'doom-one-light custom-enabled-themes))
  (should (equal (study-test-spec 'user 'font-lock-keyword-face :foreground)
                 (cdr (assoc "keywords" (study-test-palette "dark")))))
  (should (eq (car custom-enabled-themes) 'luciano-study))
  (should (equal (face-attribute 'org-block :background nil t)
                 (cdr (assoc "current_line" (study-test-palette "dark")))))
  (should (equal (face-attribute 'font-lock-doc-face :foreground nil t)
                 (cdr (assoc "comments" (study-test-palette "dark")))))
  (should (equal (study-test-spec 'luciano-study 'isearch :foreground)
                 (cdr (assoc "search_text" (study-test-palette "dark")))))
  (study-test-apply (study-test-palette "light"))
  (should (= study-test-loads 3))
  (study-test-apply '(("background" . "#1f1f28") ("bright_blue" . "#123456")))
  (should (= study-test-loads 4))
  (should (eq doom-theme 'doom-one))
  (should-not luciano/omarchy-study-base)
  (should-not (memq 'luciano-study custom-enabled-themes))
  (should (equal (study-test-spec 'user 'font-lock-keyword-face :foreground) "#123456"))
  (study-test-apply '(("background" . "#1f1f28")))
  (should (= study-test-loads 4)))

(ert-deftest study-real-palette-files ()
  "Read real files and check effective face precedence, including reentry."
  (study-test-reset)
  (dolist (mode '("day" "night" "legacy" "day" "night" "day"))
    (if (equal mode "legacy")
        (study-test-apply '(("background" . "#1f1f28")))
      (let ((luciano/omarchy-colors-file
             (expand-file-name (format "omarchy/themes/study-%s/colors.toml" mode)
                               study-test-root)))
        ;; Fail rather than silently accepting the loader's desktop fallbacks.
        (should (file-readable-p luciano/omarchy-colors-file))
        (luciano/apply-omarchy-theme-faces)
        (should (eq doom-theme (if (equal mode "day") 'doom-one-light 'doom-one)))
        (should (eq (car custom-enabled-themes) 'luciano-study))
        (should (equal (face-attribute 'font-lock-keyword-face :foreground nil t)
                       (luciano/omarchy-color "syntax_keywords")))
        (should (equal (face-attribute 'org-block :background nil t)
                       (luciano/omarchy-color "current_line")))
        (should (equal (face-attribute 'font-lock-doc-face :foreground nil t)
                       (luciano/omarchy-color "syntax_comments")))))))

(ert-deftest study-syntax-style-transitions ()
  "Emphasize structure in both palettes and restore nonstudy face styles."
  (study-test-reset)
  ;; A fresh -Q session has no colorscheme. Establish doom-one before taking
  ;; the nonstudy baseline, exactly as a real Doom session would have it.
  (study-test-apply (study-test-palette "dark"))
  (study-test-apply '(("background" . "#1f1f28")))
  (let* ((faces '(font-lock-keyword-face font-lock-function-name-face
                  font-lock-comment-face font-lock-comment-delimiter-face
                  font-lock-doc-face font-lock-builtin-face
                  font-lock-number-face font-lock-function-call-face
                  font-lock-variable-use-face font-lock-warning-face error))
         (baseline
          (mapcar (lambda (face)
                    (list face
                          (face-attribute face :weight nil t)
                          (face-attribute face :slant nil t)))
                  faces)))
    (dolist (mode '("light" "dark" "light" "dark"))
      (study-test-apply (study-test-palette mode))
      (dolist (face '(font-lock-keyword-face font-lock-function-name-face
                      font-lock-function-call-face
                      font-lock-warning-face error))
        (should (eq (face-attribute face :weight nil t) 'bold)))
      (dolist (face '(font-lock-comment-face font-lock-comment-delimiter-face
                      font-lock-doc-face font-lock-builtin-face
                      font-lock-number-face
                      font-lock-variable-use-face))
        (should (eq (face-attribute face :weight nil t) 'normal)))
      (dolist (face '(font-lock-comment-face font-lock-comment-delimiter-face
                      font-lock-doc-face font-lock-builtin-face))
        (should (eq (face-attribute face :slant nil t) 'normal)))
      (dolist (entry '((font-lock-builtin-face . "keywords")
                       (font-lock-number-face . "numbers")
                       (font-lock-function-call-face . "functions")
                       (font-lock-variable-use-face . "text")
                       (font-lock-warning-face . "errors")))
        (should (equal (face-attribute (car entry) :foreground nil t)
                       (cdr (assoc (cdr entry) (study-test-palette mode)))))))
    (study-test-apply '(("background" . "#1f1f28")))
    (should-not (memq 'luciano-study custom-enabled-themes))
    (dolist (entry baseline)
      (should (equal (face-attribute (car entry) :weight nil t) (nth 1 entry)))
      (should (equal (face-attribute (car entry) :slant nil t) (nth 2 entry))))))

(ert-deftest study-font-declarations ()
  "Keep the explicit non-ligature regular 15pt font without loading Doom."
  (should (= (length study-test-font-forms) 2))
  (mapc (lambda (form) (eval form t)) (reverse study-test-font-forms))
  (should (equal luciano/ui-font-family "JetBrainsMonoNL Nerd Font Mono"))
  (should (= luciano/ui-font-height 150))
  (should (equal (format "%s" (font-get doom-font :family)) luciano/ui-font-family))
  (should (= (font-get doom-font :size) 15.0))
  (should (eq (font-get doom-font :weight) 'regular))
  (should (equal (format "%s" (font-get doom-variable-pitch-font :family)) "IBM Plex Sans"))
  (should (= (font-get doom-variable-pitch-font :size) 15.0))
  (should (equal (format "%s" (font-get doom-serif-font :family)) "IBM Plex Serif"))
  (should (= (font-get doom-serif-font :size) 15.0))
  (should (equal (format "%s" (font-get doom-big-font :family)) luciano/ui-font-family))
  (should (= (font-get doom-big-font :size) 16.0)))

(ert-run-tests-batch-and-exit "^study-")
