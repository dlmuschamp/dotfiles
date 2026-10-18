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
(with-temp-buffer
  (insert-file-contents (expand-file-name "doom/config.el" study-test-root))
  (emacs-lisp-mode)
  (check-parens)
  (goto-char (point-min))
  (condition-case nil
      (while t
        (let ((form (read (current-buffer))))
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
  (dolist (entry '((font-lock-keyword-face . "#6C2E91")
                   (font-lock-function-name-face . "#124B80")
                   (font-lock-string-face . "#20532E")
                   (font-lock-constant-face . "#6E3B08")
                   (font-lock-type-face . "#005055")))
    (should (equal (study-test-spec 'user (car entry) :foreground) (cdr entry))))
  (should (equal (study-test-spec 'luciano-study 'org-block :background) "#EDEBE5"))
  (dolist (entry '((font-lock-doc-face . "#454B54")
                   (error . "#902030")
                   (isearch . "#24272E")
                   (minibuffer-prompt . "#6C2E91")
                   (company-tooltip . "#24272E")))
    (should (equal (study-test-spec 'luciano-study (car entry) :foreground)
                   (cdr entry))))
  (study-test-apply (study-test-palette "light"))
  (should (= study-test-loads 1))
  (study-test-apply (study-test-palette "dark"))
  (should (eq doom-theme 'doom-one))
  (should (= study-test-loads 2))
  (should-not (memq 'doom-one-light custom-enabled-themes))
  (should (equal (study-test-spec 'user 'font-lock-keyword-face :foreground) "#D1B2FA"))
  (should (eq (car custom-enabled-themes) 'luciano-study))
  (should (equal (face-attribute 'org-block :background nil t) "#292F38"))
  (should (equal (face-attribute 'font-lock-doc-face :foreground nil t) "#B4BCC6"))
  (should (equal (study-test-spec 'luciano-study 'isearch :foreground) "#1F2329"))
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

(ert-run-tests-batch-and-exit "^study-")
