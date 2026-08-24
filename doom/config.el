;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

(setq doom-theme 'doom-one)
(setq display-line-numbers-type 'relative)
(setq org-directory "~/org/")

;; Open EWW in the currently selected window instead of Doom's popup.
(set-popup-rule! "^\\*eww\\*" :ignore t)
(add-to-list 'display-buffer-alist
             '("^\\*eww\\*"
               (display-buffer-same-window)
               (inhibit-same-window . nil)))

;; One passphrase prompt per Emacs session for encrypted oauth tokens.
;; GPG 2.1+ ignores Emacs passphrase callbacks unless pinentry is loopback —
;; without this, every oauth2-auto plstore decrypt uses system pinentry and
;; `plstore-passphrase-alist' stays empty (4 calendars = 4 prompts).
(setq epa-file-cache-passphrase-for-symmetric-encryption t
      plstore-cache-passphrase-for-symmetric-encryption t
      epg-pinentry-mode 'loopback
      epa-pinentry-mode 'loopback)

;;; Keep buffers matching disk (nvim / other tools / gcal / builds).
;; Doom's default `doom-auto-revert-mode' only reloads when you switch
;; buffer/window/frame — so a file edited in nvim can look stale until you
;; leave and come back. Use real global auto-revert instead.
(remove-hook 'doom-first-file-hook #'doom-auto-revert-mode)
(after! autorevert
  (global-auto-revert-mode +1)
  (setq global-auto-revert-non-file-buffers t
        auto-revert-verbose nil
        auto-revert-use-notify t
        auto-revert-avoid-polling nil
        auto-revert-interval 1
        ;; Never prompt to reload an unmodified buffer from disk.
        revert-without-query '(".*")))
(setq dired-auto-revert-buffer t)

(after! projectile
  ;; Don't serve a stale project file index after nvim creates/renames files.
  (setq projectile-enable-caching nil)
  (add-hook 'projectile-after-switch-project-hook
            (lambda (&rest _)
              (when (fboundp 'projectile-invalidate-cache)
                (projectile-invalidate-cache nil)))))

(after! calendar
  (define-key calendar-mode-map (kbd "RET") #'org-agenda-goto-calendar))

;;; ==========================================
;;; INDENT + 80-COLUMN DISCIPLINE
;;; ==========================================
;; Most codebases use 2 or 4 spaces. 8 is intentional here: deep nesting burns
;; the column budget fast (Linux kernel C style is also tab-width 8).
(setq-default tab-width 8
              standard-indent 8
              indent-tabs-mode nil          ; spaces, not tab characters
              fill-column 80)               ; classic wrap / comment width

;; Language offsets that ignore standard-indent unless set explicitly.
(setq c-basic-offset 8
      c-ts-mode-indent-offset 8
      python-indent-offset 8
      js-indent-level 8
      typescript-indent-level 8
      css-indent-offset 8
      web-mode-markup-indent-offset 8
      web-mode-code-indent-offset 8
      web-mode-css-indent-offset 8
      rust-indent-offset 8
      go-ts-mode-indent-offset 8
      sh-basic-offset 8
      lua-indent-level 8
      yaml-indent-offset 2) ; YAML is unreadable at 8; keep 2

;; Visible ruler at column 80. Soft-wrapping code mid-statement is painful, so
;; we draw the line instead of auto-wrapping programming buffers. Org/text
;; still auto-fill (hard wrap) at 80.
(add-hook 'prog-mode-hook #'display-fill-column-indicator-mode)
(add-hook 'text-mode-hook #'display-fill-column-indicator-mode)
(add-hook 'text-mode-hook #'auto-fill-mode)
(add-hook 'org-mode-hook #'auto-fill-mode)

;;; ==========================================
;;; ORG MODE — command center
;;; ==========================================
(after! org
  (setq org-directory "~/org/")

  ;; %^T prompts for date+time. Type 2:30pm — Org stores 24h (org-gcal-safe).
  ;; Empty :org-gcal: drawer is required: org-gcal-sync only pushes headlines
  ;; that already have that drawer. Capture file picks the Google calendar:
  ;;   t → Personal, a → Arbor Live, s → School. Canvas is pull-only.
  (setq org-capture-templates
        '(("t" "Personal task" entry
           (file+headline "~/org/personal.org" "Tasks")
           "* TODO %?\nSCHEDULED: %^T\n:org-gcal:\n:END:\n%i")
          ("a" "Arbor inquiry / booking" entry
           (file+headline "~/org/arbor.org" "Inquiries")
           "* TODO %?\nSCHEDULED: %^T\n:org-gcal:\n:END:\n%i")
          ("s" "School task" entry
           (file+headline "~/org/school.org" "School Tasks")
           "* TODO %?\nSCHEDULED: %^T\n:org-gcal:\n:END:\n%i")))

  (setq org-agenda-files '("~/org/personal.org"
                           "~/org/arbor.org"
                           "~/org/school.org"
                           "~/org/canvas.org")
        ;; One headline can have SCHEDULED + a timestamp in :org-gcal: —
        ;; without this, agenda lists the same event twice at different times.
        org-agenda-skip-additional-timestamps-same-entry t)

  (require 'org-id)
  (setq org-id-link-to-org-use-id 'create-if-interactive)

  ;; WAITING_REPLY / NEEDS_REPLY: parked (separate agenda pane, not time chart).
  ;; No @ on keywords → no note popup when parking.
  ;; Flow: TODO → IN_PROGRESS → WAITING_REPLY / NEEDS_REPLY → DONE / CANCELLED.
  (setq org-todo-keywords
        '((sequence "TODO(t)" "IN_PROGRESS(i)" "WAITING_REPLY(w)" "NEEDS_REPLY(r)" "|"
                    "DONE(d!)" "CANCELLED(c)")))
  (setq org-todo-keyword-faces
        '(("IN_PROGRESS" . +org-todo-active)
          ("WAITING_REPLY" . +org-todo-onhold)
          ("NEEDS_REPLY" . +org-todo-onhold)
          ("CANCELLED" . +org-todo-cancel)))
  (setq org-use-fast-todo-selection 'expert
        org-enforce-todo-dependencies t
        org-log-into-drawer t
        org-log-done 'time)

  ;;; --- Clocking (hands-off) -------------------------------------------
  ;; How it works — you almost never open a clock menu:
  ;;   1. Set state to IN_PROGRESS → clocks in automatically
  ;;   2. Set WAITING_REPLY / NEEDS_REPLY / TODO / DONE / CANCELLED → clocks out
  ;;   3. Idle 15 min → Org asks if you were away (safe default)
  ;;   4. Timed calendar events that already ended get a matching CLOCK line
  ;;      after each gcal fetch (all category files) — no laptop needed
  ;; Manual overrides (rarely): SPC n o i / o  (clock in / out)
  (setq org-clock-in-switch-to-state "IN_PROGRESS"
        org-clock-persist 'history
        org-clock-out-when-done t
        org-clock-idle-time 15
        org-clock-into-drawer t
        org-clock-out-remove-zero-time-clocks t
        org-clock-report-include-clocking-task t
        ;; Don't pop the "Clock Resolution" menu on clock-in.
        org-clock-auto-clock-resolution nil)
  (org-clock-persistence-insinuate)

  (defun luciano/org-clock-on-state-change ()
    "Clock in on IN_PROGRESS; clock out when parking or finishing."
    (cond
     ((equal org-state "IN_PROGRESS")
      (unless (org-clocking-p)
        (let ((org-clock-auto-clock-resolution nil))
          (org-clock-in))))
     ((member org-state '("TODO" "WAITING_REPLY" "NEEDS_REPLY" "DONE" "CANCELLED"))
      (when (org-clocking-p)
        (org-clock-out nil t)))))
  (add-hook 'org-after-todo-state-change-hook #'luciano/org-clock-on-state-change)

  (defun luciano/org--entry-timed-range ()
    "Return (START . END) Emacs times for the first timed range on this entry, or nil."
    (let* ((end (save-excursion (org-end-of-subtree t t)))
           (stamp
            (save-excursion
              (or
               ;; Prefer SCHEDULED / DEADLINE / active stamp in body
               (re-search-forward org-tr-regexp end t)
               (re-search-forward org-ts-regexp-both end t)))))
      (when stamp
        (let* ((ts (match-string-no-properties 0))
               (parsed (org-parse-time-string (substring ts 1 -1) t)))
          (when (and (nth 2 parsed) (nth 1 parsed)) ; has hour+minute
            (let* ((start (org-time-string-to-time ts))
                   ;; Range form <DATE HH:MM-HH:MM> → end from second time
                   (end-time
                    (if (string-match
                         "<\\([^>]+\\) \\([0-9]+\\):\\([0-9]+\\)-\\([0-9]+\\):\\([0-9]+\\)>"
                         ts)
                        (encode-time
                         0
                         (string-to-number (match-string 5 ts))
                         (string-to-number (match-string 4 ts))
                         (nth 3 parsed) (nth 4 parsed) (nth 5 parsed)
                         (nth 8 (decode-time start)))
                      ;; Single timestamp: treat as zero-length (skip)
                      nil)))
              (when (and end-time (time-less-p start end-time))
                (cons start end-time))))))))

  (defun luciano/org--entry-has-clock-covering-p (start end)
    "Non-nil if this entry already has a CLOCK covering START..END."
    (let ((found nil)
          (end-pos (save-excursion (org-end-of-subtree t t))))
      (save-excursion
        (while (and (not found)
                    (re-search-forward
                     (concat "CLOCK: " org-tr-regexp-both) end-pos t))
          (let* ((line (match-string-no-properties 0))
                 (cstart (org-time-string-to-time
                          (match-string-no-properties 1)))
                 (cend (and (match-string-no-properties 2)
                            (org-time-string-to-time
                             (match-string-no-properties 2)))))
            (when (and cend
                       (<= (abs (float-time (time-subtract cstart start))) 60)
                       (<= (abs (float-time (time-subtract cend end))) 60))
              (setq found t)))))
      found))

  (defun luciano/org-auto-clock-from-timestamps (&optional file)
    "Turn past timed calendar events into CLOCK lines (Arbor shifts, meetings).
Idempotent: skips entries that already have a matching CLOCK.
Runs after gcal fetch so shifts away from the laptop still count."
    (interactive)
    (let* ((file (expand-file-name (or file (buffer-file-name))))
           (now (current-time))
           (count 0))
      (when (and file (file-readable-p file))
        (with-current-buffer (find-file-noselect file)
          (org-with-wide-buffer
           (org-map-entries
            (lambda ()
              (when-let* ((range (luciano/org--entry-timed-range))
                          (start (car range))
                          (end (cdr range))
                          ((time-less-p end now)) ; only finished events
                          ((not (luciano/org--entry-has-clock-covering-p
                                 start end))))
                (org-clock-find-position nil)
                (insert
                 "CLOCK: ["
                 (format-time-string (org-time-stamp-format t t) start)
                 "]--["
                 (format-time-string (org-time-stamp-format t t) end)
                 "] => "
                 (org-duration-from-minutes
                  (/ (float-time (time-subtract end start)) 60.0))
                 "\n")
                (setq count (1+ count))))
            nil 'file))
          (when (and (> count 0) (buffer-modified-p))
            (save-buffer)))
        (when (called-interactively-p 'interactive)
          (message "Auto-clocked %d finished timed event(s) in %s"
                   count (file-name-nondirectory file))))
      count))

  ;;; --- Open tasks first; DONE/CANCELLED last or folded ---------------
  (defun luciano/org-category-file-p (&optional file)
    "Non-nil if FILE is one of the planner category org files."
    (let ((file (file-truename (or file (buffer-file-name) ""))))
      (member file
              (mapcar (lambda (f) (file-truename (expand-file-name f org-directory)))
                      '("personal.org" "arbor.org" "school.org" "canvas.org")))))

  (defun luciano/org-sort-open-first ()
    "Sort entries: open TODOs first, DONE/CANCELLED last (all outline levels)."
    (interactive)
    (save-excursion
      (goto-char (point-min))
      ;; Point before first headline → sort whole file's top-level entries.
      ;; RECURSIVE sorts nested parents (e.g. under * Inquiries) the same way.
      ;; Sort siblings by TODO keyword order (done keywords after | sort last).
      (org-sort-entries nil ?o))
    (when (called-interactively-p 'interactive)
      (message "Sorted: open tasks first, DONE/CANCELLED last")))

  (defun luciano/org-fold-done-entries ()
    "Fold every DONE/CANCELLED subtree so open work stays visible."
    (interactive)
    (org-map-entries
     (lambda ()
       (when (org-entry-is-done-p)
         (outline-hide-subtree)))
     nil 'file))

  (defun luciano/org-tidy-category-buffer ()
    "Open tasks on top; fold finished ones. Safe to run on category files."
    (when (and (derived-mode-p 'org-mode)
               (luciano/org-category-file-p)
               (not (buffer-modified-p)))
      ;; Sort in-buffer but don't dirty: order re-applies next visit.
      (luciano/org-sort-open-first)
      (set-buffer-modified-p nil)
      (luciano/org-fold-done-entries)))

  (add-hook 'org-mode-hook
            (lambda ()
              (when (luciano/org-category-file-p)
                ;; After first display — sort + fold without fighting capture
                (run-with-idle-timer 0.2 nil
                                     (lambda (buf)
                                       (when (buffer-live-p buf)
                                         (with-current-buffer buf
                                           (luciano/org-tidy-category-buffer))))
                                     (current-buffer)))))

  (setq org-agenda-skip-scheduled-if-done t
        org-agenda-skip-deadline-if-done t
        org-agenda-skip-timestamp-if-done t
        org-agenda-todo-ignore-done t
        org-agenda-todo-list-sublevels t
        org-agenda-start-with-log-mode nil
        org-agenda-window-setup 'current-window
        org-agenda-restore-windows-after-quit t
        org-agenda-timegrid-use-ampm t
        org-read-date-prefer-future t
        org-time-stamp-rounding-minutes '(0 5)
        ;; Do NOT enable org-display-custom-times — 12h display in the file
        ;; breaks org-gcal. Type 12h in the minibuffer; agenda grid shows AM/PM.
        org-startup-with-latex-preview nil
        org-attach-use-inheritance t
        org-attach-dir-relative t)

  ;; Only unfinished keywords in category "all tasks" sections.
  (defconst luciano/org-open-todo-match
    "TODO|IN_PROGRESS|WAITING_REPLY|NEEDS_REPLY")

  (defconst luciano/org-time-todo-states
    '("TODO" "IN_PROGRESS" "DONE")
    "TODO states that count as real time blocks (planned chart).")

  (defconst luciano/org-parked-todo-match
    "WAITING_REPLY|NEEDS_REPLY"
    "Parked items — waiting on someone else, not on your clock.")

  ;;; --- Weekly ASCII time chart ----------------------------------------
  (defface luciano/time-chart-arbor
    '((t :foreground "#98be65" :weight bold))
    "Arbor hours in the weekly time chart.")
  (defface luciano/time-chart-personal
    '((t :foreground "#51afef" :weight bold))
    "Personal hours in the weekly time chart.")
  (defface luciano/time-chart-school
    '((t :foreground "#c678dd" :weight bold))
    "School hours in the weekly time chart.")
  (defface luciano/time-chart-other
    '((t :foreground "#da8548" :weight bold))
    "Other hours in the weekly time chart.")

  (defun luciano/org--category-face (cat)
    (pcase (downcase (or cat ""))
      ("arbor" 'luciano/time-chart-arbor)
      ("personal" 'luciano/time-chart-personal)
      ("school" 'luciano/time-chart-school)
      ("canvas" 'luciano/time-chart-school)
      (_ 'luciano/time-chart-other)))

  (defun luciano/org--file-category (file)
    (or (with-current-buffer (find-file-noselect file)
          (save-excursion
            (goto-char (point-min))
            (when (re-search-forward "^#\\+CATEGORY:\\s-*\\(.+\\)$" nil t)
              (string-trim (match-string-no-properties 1)))))
        (capitalize (file-name-base file))))

  (defun luciano/org--time-add (time seconds)
    "Add SECONDS to TIME."
    (time-add time (seconds-to-time seconds)))

  (defun luciano/org--week-bounds (&optional time)
    "Return (START . END) for the week containing TIME (Mon 00:00 → next Mon)."
    (let* ((time (or time (current-time)))
           (decoded (decode-time time))
           (dow (org-day-of-week
                 (nth 3 decoded) (nth 4 decoded) (nth 5 decoded)))
           ;; Org: 0=Sun … 6=Sat → days since Monday
           (since-mon (mod (- dow 1) 7))
           (midnight (encode-time 0 0 0
                                  (nth 3 decoded) (nth 4 decoded) (nth 5 decoded)))
           (start (luciano/org--time-add midnight (* -1 since-mon 24 60 60)))
           (end (luciano/org--time-add start (* 7 24 60 60))))
      (cons start end)))

  (defun luciano/org--collect-clocks (start end &optional files)
    "Collect clock segments in [START,END) as plists (:cat :title :day :mins)."
    (let (rows)
      (dolist (file (or files (org-agenda-files t)))
        (let ((cat (luciano/org--file-category file)))
          (with-current-buffer (find-file-noselect file)
            (org-with-wide-buffer
             (goto-char (point-min))
             (while (re-search-forward
                     (concat "^[ \\t]*CLOCK: " org-tr-regexp-both) nil t)
               (let* ((cs (org-time-string-to-time (match-string-no-properties 1)))
                      (ce (and (match-string-no-properties 2)
                               (org-time-string-to-time
                                (match-string-no-properties 2)))))
                 (when (and ce
                            (time-less-p cs end)
                            (time-less-p start ce))
                   (let* ((clipped-s (if (time-less-p cs start) start cs))
                          (clipped-e (if (time-less-p end ce) end ce))
                          (mins (max 0 (/ (float-time
                                           (time-subtract clipped-e clipped-s))
                                          60)))
                          (day (format-time-string "%a %m/%d" clipped-s))
                          (title (save-excursion
                                   (org-back-to-heading t)
                                   (org-get-heading t t t t))))
                     (when (> mins 0)
                       (push (list :cat cat :title title :day day :mins mins
                                   :sort (float-time clipped-s))
                             rows))))))))))
      (nreverse rows)))

  (defun luciano/org--collect-allotted (start end &optional files)
    "Collect timed SCHEDULED (or drawer) ranges in [START,END) as allotted minutes.
Uses calendar block length — no CLOCK required.
Skips WAITING_REPLY, NEEDS_REPLY, and CANCELLED. Only TODO / IN_PROGRESS / DONE
(and headlines with no TODO keyword) count as time blocks."
    (let (rows)
      (dolist (file (or files (org-agenda-files t)))
        (let ((cat (luciano/org--file-category file)))
          (with-current-buffer (find-file-noselect file)
            (org-with-wide-buffer
             (org-map-entries
              (lambda ()
                (let ((todo (org-get-todo-state)))
                  (when (or (null todo)
                            (member todo luciano/org-time-todo-states))
                    (let* ((elem (org-element-at-point))
                           (sched (org-element-property :scheduled elem))
                           (tobj (or sched
                                     (save-excursion
                                       (let ((limit (save-excursion
                                                      (org-end-of-subtree t t))))
                                         (when (re-search-forward org-ts-regexp limit t)
                                           (goto-char (match-beginning 0))
                                           (org-element-timestamp-parser))))))
                           (plist (and tobj (eq (car tobj) 'timestamp) (cadr tobj))))
                      (when (and plist
                                 (plist-get plist :hour-start)
                                 (plist-get plist :hour-end))
                        (let* ((cs (encode-time
                                    0
                                    (or (plist-get plist :minute-start) 0)
                                    (plist-get plist :hour-start)
                                    (plist-get plist :day-start)
                                    (plist-get plist :month-start)
                                    (plist-get plist :year-start)))
                               (ce (encode-time
                                    0
                                    (or (plist-get plist :minute-end) 0)
                                    (plist-get plist :hour-end)
                                    (or (plist-get plist :day-end)
                                        (plist-get plist :day-start))
                                    (or (plist-get plist :month-end)
                                        (plist-get plist :month-start))
                                    (or (plist-get plist :year-end)
                                        (plist-get plist :year-start)))))
                          (when (and (time-less-p cs end)
                                     (time-less-p start ce))
                            (let* ((clipped-s (if (time-less-p cs start) start cs))
                                   (clipped-e (if (time-less-p end ce) end ce))
                                   (mins (max 0 (/ (float-time
                                                    (time-subtract clipped-e clipped-s))
                                                   60.0)))
                                   (day (format-time-string "%a %m/%d" clipped-s))
                                   (title (org-get-heading t t t t)))
                              (when (> mins 0)
                                (push (list :cat cat :title title :day day
                                            :mins mins
                                            :sort (float-time clipped-s))
                                      rows))))))))))
              nil 'file)))))
      (nreverse rows)))

  (defun luciano/org--round-mins (mins &optional step)
    "Round MINS to nearest STEP minutes (default 15). Well-intentioned timesheet rounding."
    (let* ((step (float (or step 15)))
           (n (max 0 (float mins))))
      (* step (floor (+ (/ n step) 0.5)))))

  (defun luciano/org--format-arbor-timesheet (&optional week-shift)
    "Copy-ready Arbor timesheet from CLOCK only, rounded to 15 minutes.
Never uses allotted calendar length — safe to paste into a real timecard."
    (let* ((week-shift (or week-shift 0))
           (shifted (luciano/org--time-add (current-time)
                                           (* week-shift 7 24 60 60)))
           (bounds (luciano/org--week-bounds shifted))
           (start (car bounds))
           (end (cdr bounds))
           (arbor (list (expand-file-name "arbor.org" org-directory)))
           (rows (luciano/org--collect-clocks start end arbor))
           (by-title (make-hash-table :test 'equal))
           (items '())
           (raw-grand 0.0)
           (bill-grand 0.0)
           (out ""))
      (dolist (r rows)
        (let ((title (or (plist-get r :title) "?"))
              (mins (plist-get r :mins)))
          (puthash title (+ mins (gethash title by-title 0)) by-title)))
      (maphash (lambda (k v) (push (cons k v) items)) by-title)
      (setq items (cl-sort items #'> :key #'cdr))
      (setq out
            (concat
             (propertize
              (format "Arbor timesheet (CLOCK → 15m)  %s → %s\n"
                      (format-time-string "%a %b %d" start)
                      (format-time-string "%a %b %d"
                                          (luciano/org--time-add end -1)))
              'face 'bold)
             (propertize
              "Billable = clocked time rounded to nearest 15m. Not calendar blocks.\n"
              'face 'shadow)
             (propertize "c in chart buffer copies this table.\n\n" 'face 'shadow)
             "| Task | Clocked | Billable |\n"
             "|------+---------+----------|\n"))
      (if (null items)
          (setq out (concat out "| (no Arbor clocks this week) |  |  |\n"))
        (dolist (it items)
          (let* ((raw (float (cdr it)))
                 (bill (luciano/org--round-mins raw 15)))
            (setq raw-grand (+ raw-grand raw)
                  bill-grand (+ bill-grand bill))
            (setq out
                  (concat out
                          (format "| %s | %5.2fh | %5.2fh |\n"
                                  (truncate-string-to-width (car it) 40 nil nil "…")
                                  (/ raw 60.0)
                                  (/ bill 60.0))))))
        (setq out
              (concat out
                      (format "| TOTAL | %5.2fh | %5.2fh |\n"
                              (/ raw-grand 60.0)
                              (/ bill-grand 60.0)))))
      out))

  (defun luciano/org--format-weekly-dashboard (&optional week-shift use-allotted)
    "Return a string: ASCII stacked bars by day + org-style category totals table.
USE-ALLOTTED non-nil (default) uses calendar block lengths; nil uses CLOCK."
    (let* ((week-shift (or week-shift 0))
           (use-allotted (if (eq use-allotted 'clock) nil t))
           (shifted (luciano/org--time-add (current-time)
                                           (* week-shift 7 24 60 60)))
           (bounds (luciano/org--week-bounds shifted))
           (start (car bounds))
           (end (cdr bounds))
           (rows (if use-allotted
                     (luciano/org--collect-allotted start end)
                   (luciano/org--collect-clocks start end)))
           (days '())
           (cats '("Arbor" "Personal" "School" "Canvas"))
           (day-cat (make-hash-table :test 'equal))
           (cat-total (make-hash-table :test 'equal))
           (day-total (make-hash-table :test 'equal))
           (out ""))
      (dotimes (i 7)
        (push (format-time-string
               "%a %m/%d"
               (luciano/org--time-add start (* i 24 60 60)))
              days))
      (setq days (nreverse days))
      (dolist (r rows)
        (let* ((cat (plist-get r :cat))
               (day (plist-get r :day))
               (mins (plist-get r :mins))
               (canon (cond
                       ((string-match-p "arbor" (downcase cat)) "Arbor")
                       ((string-match-p "personal" (downcase cat)) "Personal")
                       ((string-match-p "school" (downcase cat)) "School")
                       ((string-match-p "canvas" (downcase cat)) "Canvas")
                       (t "Other"))))
          (unless (member canon cats) (setq cats (append cats (list canon))))
          (puthash (cons day canon)
                   (+ mins (gethash (cons day canon) day-cat 0))
                   day-cat)
          (puthash canon (+ mins (gethash canon cat-total 0)) cat-total)
          (puthash day (+ mins (gethash day day-total 0)) day-total)))
      (setq out
            (concat
             (propertize
              (format "Planned time %s  (%s → %s)\n"
                      (if use-allotted "· allotted blocks (not timesheet)" "· CLOCK")
                      (format-time-string "%a %b %d" start)
                      (format-time-string "%a %b %d"
                                          (luciano/org--time-add end -1)))
              'face 'bold)
             (when use-allotted
               (propertize
                "Only TODO / IN_PROGRESS / DONE (and untagged events). Parked items are a separate pane.\n"
                'face 'shadow))
             (format "Legend: %s  %s  %s  %s\n"
                     (propertize "Arbor" 'face 'luciano/time-chart-arbor)
                     (propertize "Personal" 'face 'luciano/time-chart-personal)
                     (propertize "School" 'face 'luciano/time-chart-school)
                     (propertize "Canvas/Other" 'face 'luciano/time-chart-other))))
      (let* ((max-day (max 1 (or (cl-loop for d in days
                                          maximize (gethash d day-total 0))
                                 1)))
             (bar-w 36)
             (grand (max 1 (cl-loop for c in cats sum (gethash c cat-total 0)))))
        (setq out (concat out (format "\n%-12s %6s  %s\n" "Day" "Hours" "By category")
                          (make-string 64 ?─) "\n"))
        (dolist (d days)
          (let ((tot (gethash d day-total 0)))
            (setq out (concat out (format "%-12s %5.1fh  " d (/ tot 60.0))))
            (if (zerop tot)
                (setq out (concat out
                                  (propertize (make-string bar-w ?·) 'face 'shadow)
                                  "\n"))
              (dolist (cat cats)
                (let ((m (gethash (cons d cat) day-cat 0)))
                  (when (> m 0)
                    (setq out
                          (concat out
                                  (luciano/org--bar
                                   m max-day
                                   (max 1 (round (* bar-w (/ m (float max-day)))))
                                   (luciano/org--category-face cat)))))))
              (setq out (concat out "\n")))))
        ;; Org-style totals table
        (setq out (concat out "\n| Category | Hours | Share | Bar |\n"
                          "|----------+------+-------+-----|\n"))
        (dolist (cat cats)
          (let* ((m (gethash cat cat-total 0))
                 (hrs (/ m 60.0))
                 (pct (floor (* 100.0 (/ m (float grand)))))
                 (bar (luciano/org--bar m grand 16
                                        (luciano/org--category-face cat) t)))
            (when (or (> m 0) (member cat '("Arbor" "Personal" "School")))
              (setq out (concat out
                                (format "| %-8s | %5.1f | %3d%% | %s |\n"
                                        cat hrs pct bar))))))
        (setq out (concat out
                          (format "| %-8s | %5.1f | 100%% | |\n"
                                  "Total" (/ grand 60.0)))))
      out))

  (defun luciano/org--weekly-dashboard-buffer (&optional week-shift)
    "Build/refresh the side-panel dashboard buffer; return it."
    (let* ((week-shift (or week-shift 0))
           (buf (get-buffer-create "*Org Command Chart*"))
           (plan (luciano/org--format-weekly-dashboard week-shift t))
           (sheet (luciano/org--format-arbor-timesheet week-shift)))
      (with-current-buffer buf
        (let ((inhibit-read-only t))
          (erase-buffer)
          (special-mode)
          (setq-local luciano/org-command-chart-week week-shift)
          (setq-local luciano/org-command-chart-timesheet sheet)
          (setq-local revert-buffer-function
                      (lambda (&rest _)
                        (luciano/org--weekly-dashboard-buffer
                         luciano/org-command-chart-week)
                        (when (get-buffer-window buf)
                          (set-window-buffer (get-buffer-window buf) buf))))
          (insert plan)
          (insert "\n"
                  (propertize "════════ Arbor timesheet (copy this) ════════\n"
                              'face 'bold)
                  sheet
                  "\n")
          (goto-char (point-min))
          (local-set-key (kbd "g") #'revert-buffer)
          (local-set-key (kbd "c") #'luciano/org-copy-arbor-timesheet)
          (local-set-key (kbd "<")
                         (lambda ()
                           (interactive)
                           (luciano/org--weekly-dashboard-buffer
                            (1- luciano/org-command-chart-week))))
          (local-set-key (kbd ",")
                         (lambda ()
                           (interactive)
                           (luciano/org--weekly-dashboard-buffer
                            (1- luciano/org-command-chart-week))))
          (local-set-key (kbd ">")
                         (lambda ()
                           (interactive)
                           (luciano/org--weekly-dashboard-buffer
                            (1+ luciano/org-command-chart-week))))
          (local-set-key (kbd ".")
                         (lambda ()
                           (interactive)
                           (luciano/org--weekly-dashboard-buffer
                            (1+ luciano/org-command-chart-week))))
          (local-set-key (kbd "q") #'quit-window)))
      buf))

  (defun luciano/org-copy-arbor-timesheet ()
    "Copy the Arbor billable timesheet table to the kill-ring."
    (interactive)
    (let ((text (or (and (boundp 'luciano/org-command-chart-timesheet)
                         luciano/org-command-chart-timesheet)
                    (luciano/org--format-arbor-timesheet 0))))
      ;; Strip face properties for a clean paste into forms/email.
      (setq text (substring-no-properties text))
      (kill-new text)
      (message "Arbor timesheet copied (%d chars)" (length text))))

  (defun luciano/org-agenda-command-center (&optional _match)
    "Command center: 10-day agenda (left) + planned chart / timesheet (right)."
    (let ((org-agenda-window-setup 'only-window))
      (org-agenda nil "d!"))
    (when-let ((agenda-win (get-buffer-window org-agenda-buffer-name)))
      (select-window agenda-win)
      (delete-other-windows)
      (split-window-right)
      (other-window 1)
      (switch-to-buffer (luciano/org--weekly-dashboard-buffer 0))
      (other-window 1)))

  (defun luciano/org-agenda-insert-weekly-dashboard (&optional _match)
    "Legacy stacked insert (unused by command center; kept for T-style reuse)."
    (let ((inhibit-read-only t))
      (goto-char (point-max))
      (unless (bolp) (insert "\n"))
      (insert "\n"
              (propertize "════════ Time this week ════════\n" 'face 'bold)
              (luciano/org--format-weekly-dashboard 0 t)
              "\n")))

  (defun luciano/org--bar (mins max-mins width face &optional pad)
    "Propertized ASCII bar for MINS relative to MAX-MINS."
    (let* ((max-mins (max (float max-mins) 1.0))
           (filled (round (* width (/ mins max-mins))))
           (filled (min width (max (if (> mins 0) 1 0) filled)))
           (bar (concat (make-string filled ?█)
                        (if pad (make-string (- width filled) ?·) ""))))
      (propertize bar 'face face)))

  (defun luciano/org-weekly-time-chart (&optional week-shift expand)
    "ASCII weekly time chart by day and category.
With prefix ARG (or EXPAND non-nil), show longest tasks breakdown.
WEEK-SHIFT: 0=this week, -1=last week, etc."
    (interactive (list 0 current-prefix-arg))
    (require 'org-clock)
    (let* ((week-shift (or week-shift 0))
           (expand (or expand current-prefix-arg))
           (shifted (luciano/org--time-add (current-time)
                                           (* week-shift 7 24 60 60)))
           (bounds (luciano/org--week-bounds shifted))
           (start (car bounds))
           (end (cdr bounds))
           (rows (luciano/org--collect-clocks start end))
           (days '())
           (cats '())
           (day-cat (make-hash-table :test 'equal))
           (cat-total (make-hash-table :test 'equal))
           (day-total (make-hash-table :test 'equal))
           (buf (get-buffer-create "*Org Time Chart*")))
      (dotimes (i 7)
        (push (format-time-string
               "%a %m/%d"
               (luciano/org--time-add start (* i 24 60 60)))
              days))
      (setq days (nreverse days))
      (dolist (r rows)
        (let ((cat (plist-get r :cat))
              (day (plist-get r :day))
              (mins (plist-get r :mins)))
          (unless (member cat cats) (push cat cats))
          (puthash (cons day cat)
                   (+ mins (gethash (cons day cat) day-cat 0))
                   day-cat)
          (puthash cat (+ mins (gethash cat cat-total 0)) cat-total)
          (puthash day (+ mins (gethash day day-total 0)) day-total)))
      (setq cats (nreverse cats))
      (with-current-buffer buf
        (let ((inhibit-read-only t))
          (erase-buffer)
          (special-mode)
          (setq-local revert-buffer-function
                      (lambda (&rest _)
                        (luciano/org-weekly-time-chart week-shift expand)))
          (insert (propertize
                   (format "Weekly time  %s → %s%s\n"
                           (format-time-string "%a %b %d" start)
                           (format-time-string "%a %b %d"
                                               (luciano/org--time-add end -1))
                           (if expand "  (expanded)" ""))
                   'face 'bold))
          (insert "Keys: g refresh · e expand/collapse · </>/,/. week · q quit\n")
          (insert (format "Legend: %s  %s  %s  %s\n\n"
                          (propertize "Arbor" 'face 'luciano/time-chart-arbor)
                          (propertize "Personal" 'face 'luciano/time-chart-personal)
                          (propertize "School" 'face 'luciano/time-chart-school)
                          (propertize "Other" 'face 'luciano/time-chart-other)))
          (let* ((max-day (or (cl-loop for d in days
                                       maximize (gethash d day-total 0))
                              1))
                 (bar-w 28))
            (insert (format "%-12s %6s  %s\n" "Day" "Hours" "By category"))
            (insert (make-string 72 ?─) "\n")
            (dolist (d days)
              (let* ((tot (gethash d day-total 0))
                     (hrs (/ tot 60.0)))
                (insert (format "%-12s %5.1fh  " d hrs))
                (if (zerop tot)
                    (insert (propertize (make-string bar-w ?·) 'face 'shadow) "\n")
                  (progn
                    ;; Stacked colored segments proportional to the day's mix.
                    (dolist (cat cats)
                      (let ((m (gethash (cons d cat) day-cat 0)))
                        (when (> m 0)
                          (insert (luciano/org--bar m max-day
                                                      (max 1 (round (* bar-w (/ m (float max-day)))))
                                                      (luciano/org--category-face cat))))))
                    (insert "\n")
                    (dolist (cat cats)
                      (let ((m (gethash (cons d cat) day-cat 0)))
                        (when (> m 0)
                          (insert (format "             %s %4.1fh  %s\n"
                                          (propertize (format "%-10s" cat)
                                                      'face (luciano/org--category-face cat))
                                          (/ m 60.0)
                                          (luciano/org--bar m max-day 12
                                                            (luciano/org--category-face cat)
                                                            t))))))))))
            (insert "\n" (propertize "Week totals\n" 'face 'bold))
            (let ((grand 0.0))
              (dolist (cat cats)
                (let ((m (gethash cat cat-total 0)))
                  (setq grand (+ grand m))
                  (insert (format "  %s %5.1fh  %s\n"
                                  (propertize (format "%-10s" cat)
                                              'face (luciano/org--category-face cat))
                                  (/ m 60.0)
                                  (luciano/org--bar m (max grand 1) 24
                                                    (luciano/org--category-face cat)
                                                    t)))))
              (insert (format "  %-10s %5.1fh\n" "TOTAL" (/ grand 60.0))))
            (when expand
              (insert "\n" (propertize "Longest tasks this week\n" 'face 'bold))
              (let* ((by-title (make-hash-table :test 'equal))
                     (items '()))
                (dolist (r rows)
                  (let* ((key (cons (plist-get r :cat) (plist-get r :title)))
                         (m (plist-get r :mins)))
                    (puthash key (+ m (gethash key by-title 0)) by-title)))
                (maphash (lambda (k v) (push (cons k v) items)) by-title)
                (setq items (cl-sort items #'> :key #'cdr))
                (cl-loop for ((cat . title) . mins) in items
                         for i from 1 to 15
                         do (insert
                             (format "  %2d. %s %5.1fh  %s\n"
                                     i
                                     (propertize (format "%-10s" cat)
                                                 'face (luciano/org--category-face cat))
                                     (/ mins 60.0)
                                     (truncate-string-to-width
                                      (or title "?") 48 nil nil "…"))))))
            (insert "\nTip: set state to IN_PROGRESS to auto-clock at the laptop;\n")
            (insert "finished timed calendar blocks auto-clock after sync.\n")
            (insert "Arbor timecard: SPC o W  (hours per task this week).\n"))
          (goto-char (point-min))
          (setq-local luciano/org-time-chart-week week-shift)
          (setq-local luciano/org-time-chart-expand expand)
          (local-set-key (kbd "g") #'revert-buffer)
          (local-set-key (kbd "e")
                         (lambda ()
                           (interactive)
                           (luciano/org-weekly-time-chart
                            luciano/org-time-chart-week
                            (not luciano/org-time-chart-expand))))
          (local-set-key (kbd "<")
                         (lambda ()
                           (interactive)
                           (luciano/org-weekly-time-chart
                            (1- luciano/org-time-chart-week)
                            luciano/org-time-chart-expand)))
          (local-set-key (kbd ",")
                         (lambda ()
                           (interactive)
                           (luciano/org-weekly-time-chart
                            (1- luciano/org-time-chart-week)
                            luciano/org-time-chart-expand)))
          (local-set-key (kbd ">")
                         (lambda ()
                           (interactive)
                           (luciano/org-weekly-time-chart
                            (1+ luciano/org-time-chart-week)
                            luciano/org-time-chart-expand)))
          (local-set-key (kbd ".")
                         (lambda ()
                           (interactive)
                           (luciano/org-weekly-time-chart
                            (1+ luciano/org-time-chart-week)
                            luciano/org-time-chart-expand)))
          (local-set-key (kbd "q") #'quit-window)))
      (pop-to-buffer buf)))

  (defun luciano/org-agenda-weekly-time-chart (&optional _match)
    "Agenda dispatcher entry point for the weekly time chart."
    (luciano/org-weekly-time-chart 0 nil))

  (defun luciano/org-arbor-timecard (&optional week-shift)
    "Hours clocked per Arbor task this week (timecard helper).
WEEK-SHIFT: 0=this week, -1=last week. Keys: g refresh, </> week, q quit."
    (interactive (list 0))
    (require 'org-clock)
    (let* ((week-shift (or week-shift 0))
           (shifted (luciano/org--time-add (current-time)
                                           (* week-shift 7 24 60 60)))
           (bounds (luciano/org--week-bounds shifted))
           (start (car bounds))
           (end (cdr bounds))
           (arbor (list (expand-file-name "arbor.org" org-directory)))
           (rows (luciano/org--collect-clocks start end arbor))
           (by-title (make-hash-table :test 'equal))
           (buf (get-buffer-create "*Arbor Timecard*")))
      (dolist (r rows)
        (let ((title (or (plist-get r :title) "?"))
              (mins (plist-get r :mins)))
          (puthash title (+ mins (gethash title by-title 0)) by-title)))
      (with-current-buffer buf
        (let ((inhibit-read-only t)
              (items '())
              (grand 0.0))
          (erase-buffer)
          (special-mode)
          (setq-local revert-buffer-function
                      (lambda (&rest _)
                        (luciano/org-arbor-timecard week-shift)))
          (setq-local luciano/org-arbor-timecard-week week-shift)
          (insert (propertize
                   (format "Arbor timecard  %s → %s\n"
                           (format-time-string "%a %b %d" start)
                           (format-time-string "%a %b %d"
                                               (luciano/org--time-add end -1)))
                   'face 'bold))
          (insert "CLOCK only · billable rounded to 15m · c copies table\n")
          (insert "Keys: g refresh · </>/,/. week · c copy · q quit\n\n")
          (insert (format "%-40s %8s %9s\n" "Task" "Clocked" "Billable"))
          (insert (make-string 60 ?─) "\n")
          (maphash (lambda (k v) (push (cons k v) items)) by-title)
          (setq items (cl-sort items #'> :key #'cdr))
          (let ((bill-grand 0.0))
            (if (null items)
                (insert (propertize "(no Arbor clocks this week)\n" 'face 'shadow))
              (dolist (it items)
                (let* ((mins (float (cdr it)))
                       (bill (luciano/org--round-mins mins 15)))
                  (setq grand (+ grand mins)
                        bill-grand (+ bill-grand bill))
                  (insert (format "%-40s %7.2fh %8.2fh\n"
                                  (truncate-string-to-width (car it) 40 nil nil "…")
                                  (/ mins 60.0)
                                  (/ bill 60.0)))))
              (insert (make-string 60 ?─) "\n")
              (insert (format "%-40s %7.2fh %8.2fh\n"
                              "TOTAL" (/ grand 60.0) (/ bill-grand 60.0)))
              (setq-local luciano/org-command-chart-timesheet
                          (luciano/org--format-arbor-timesheet week-shift))))
          (insert "\nAlso: SPC o A → A (agenda clockreport) · command center right pane\n")
          (goto-char (point-min))
          (local-set-key (kbd "g") #'revert-buffer)
          (local-set-key (kbd "c") #'luciano/org-copy-arbor-timesheet)
          (local-set-key (kbd "<")
                         (lambda ()
                           (interactive)
                           (luciano/org-arbor-timecard
                            (1- luciano/org-arbor-timecard-week))))
          (local-set-key (kbd ",")
                         (lambda ()
                           (interactive)
                           (luciano/org-arbor-timecard
                            (1- luciano/org-arbor-timecard-week))))
          (local-set-key (kbd ">")
                         (lambda ()
                           (interactive)
                           (luciano/org-arbor-timecard
                            (1+ luciano/org-arbor-timecard-week))))
          (local-set-key (kbd ".")
                         (lambda ()
                           (interactive)
                           (luciano/org-arbor-timecard
                            (1+ luciano/org-arbor-timecard-week))))
          (local-set-key (kbd "q") #'quit-window)))
      (pop-to-buffer buf)))

  (defun luciano/org-agenda-arbor-timecard (&optional _match)
    "Agenda dispatcher entry for Arbor weekly hours."
    (luciano/org-arbor-timecard 0))

  ;; SPC o A then:
  ;;   a week/day (built-in)   d command center (split)   r Arbor
  ;;   p Personal   s School   c Canvas   t open TODOs
  ;;   A Arbor timesheet   W Arbor hours   T weekly CLOCK chart
  (setq org-agenda-custom-commands
        `(("d" "Command center (10 days + time)" luciano/org-agenda-command-center)
          ;; Internal left-pane series used by command center (not listed in dispatcher
          ;; if we hide it — still selectable as d!). Keep visible description short.
          ("d!" nil
           ((agenda ""
                    ((org-agenda-span 10)
                     (org-agenda-start-on-weekday nil)
                     (org-agenda-start-day "-1d")
                     (org-agenda-overriding-header "Command center · 10 days")
                     ;; Parked items live in the pane below — keep the calendar clean.
                     (org-agenda-skip-function
                      '(org-agenda-skip-entry-if 'todo
                                                 '("WAITING_REPLY" "NEEDS_REPLY")))))
            (todo "IN_PROGRESS"
                  ((org-agenda-overriding-header "In progress")))
            (todo ,luciano/org-parked-todo-match
                  ((org-agenda-overriding-header "Waiting / needs reply (not on the clock)"))))
           ((org-agenda-window-setup 'current-window)))
          ("D" "Today only"
           ((agenda ""
                    ((org-agenda-span 'day)
                     (org-agenda-overriding-header "Today")
                     (org-agenda-skip-function
                      '(org-agenda-skip-entry-if 'todo
                                                 '("WAITING_REPLY" "NEEDS_REPLY")))))
            (todo "IN_PROGRESS"
                  ((org-agenda-overriding-header "In progress")))
            (todo ,luciano/org-parked-todo-match
                  ((org-agenda-overriding-header "Waiting / needs reply")))
            (todo "TODO"
                  ((org-agenda-overriding-header "Backlog (TODO)")))))
          ("r" "Arbor"
           ((agenda ""
                    ((org-agenda-files '("~/org/arbor.org"))
                     (org-agenda-span 7)
                     (org-agenda-overriding-header "Arbor week")))
            (todo ,luciano/org-open-todo-match
                  ((org-agenda-files '("~/org/arbor.org"))
                   (org-agenda-overriding-header "Arbor open tasks")))))
          ("p" "Personal"
           ((agenda ""
                    ((org-agenda-files '("~/org/personal.org"))
                     (org-agenda-span 7)
                     (org-agenda-overriding-header "Personal week")))
            (todo ,luciano/org-open-todo-match
                  ((org-agenda-files '("~/org/personal.org"))
                   (org-agenda-overriding-header "Personal open tasks")))))
          ("s" "School"
           ((agenda ""
                    ((org-agenda-files '("~/org/school.org" "~/org/canvas.org"))
                     (org-agenda-span 7)
                     (org-agenda-overriding-header "School + Canvas week")))
            (todo ,luciano/org-open-todo-match
                  ((org-agenda-files '("~/org/school.org" "~/org/canvas.org"))
                   (org-agenda-overriding-header "School + Canvas open")))))
          ("c" "Canvas (imported, pull-only)"
           ((agenda ""
                    ((org-agenda-files '("~/org/canvas.org"))
                     (org-agenda-span 14)
                     (org-agenda-overriding-header "Canvas import")))
            (todo ,luciano/org-open-todo-match
                  ((org-agenda-files '("~/org/canvas.org"))
                   (org-agenda-overriding-header "Canvas open")))
            (todo "DONE|CANCELLED"
                  ((org-agenda-files '("~/org/canvas.org"))
                   (org-agenda-overriding-header "Canvas finished")))))
          ("t" "All open TODOs" todo ,luciano/org-open-todo-match
           ((org-agenda-overriding-header "Everything open")))
          ("A" "Arbor week + clock report (timesheet)"
           ((agenda ""
                    ((org-agenda-files '("~/org/arbor.org"))
                     (org-agenda-span 'week)
                     (org-agenda-start-with-clockreport-mode t)
                     (org-agenda-clockreport-parameter-plist
                      '(:link t :maxlevel 3 :fileskip0 t :compact t
                              :narrow 60 :formula %))
                     (org-agenda-overriding-header "Arbor week + time clocked")))))
          ("W" "Arbor hours per task (timecard)" luciano/org-agenda-arbor-timecard)
          ("T" "Weekly time chart (CLOCK)" luciano/org-agenda-weekly-time-chart)))

  (map! :map org-mode-map
        :localleader
        :desc "Sort open tasks first" "S" #'luciano/org-sort-open-first
        :desc "Fold DONE/CANCELLED" "F" #'luciano/org-fold-done-entries)
  (map! :leader
        :desc "Weekly time chart" "o C" #'luciano/org-weekly-time-chart
        :desc "Arbor timecard" "o W" #'luciano/org-arbor-timecard))
;;; ==========================================
;;; GOOGLE CALENDAR (ORG-GCAL)
;;; ==========================================
(let ((secrets (expand-file-name "private/org-gcal-secrets.el" doom-user-dir)))
  (if (file-exists-p secrets)
      (load secrets nil 'nomessage)
    (warn "Missing %s — copy private/org-gcal-secrets.el.example and fill it in"
          secrets)))

;; Calendar IDs / OAuth live in private/org-gcal-secrets.el (gitignored).
(dolist (sym '(luciano/org-gcal-personal-id
               luciano/org-gcal-school-id
               luciano/org-gcal-arbor-id
               luciano/org-gcal-canvas-id))
  (unless (boundp sym)
    (user-error "org-gcal: %s unset — create doom/private/org-gcal-secrets.el" sym)))

(defvar luciano/org-gcal--syncing nil)
(defvar luciano/org-gcal--just-captured nil
  "Non-nil briefly after capture post so after-save does not double-create.")
(defvar luciano/org-gcal--suppress-schedule-post nil
  "Non-nil while org-gcal itself rewrites SCHEDULED (avoid push loops).")
(defvar luciano/oauth2-plstore-busy nil
  "Non-nil while oauth2-auto is reading/writing its plstore.")

(defun luciano/org-gcal-tokens-unlocked-p ()
  "Non-nil if the oauth2 plstore passphrase is already cached in this session."
  (require 'oauth2-auto nil t)
  (when (boundp 'oauth2-auto-plstore)
    (let ((entry (assoc (file-truename oauth2-auto-plstore)
                        plstore-passphrase-alist)))
      (and entry (cdr entry) t))))

(defun luciano/oauth2-auto--plstore-read (username provider)
  "Like `oauth2-auto--plstore-read', but actually use the in-memory cache.
Upstream hard-codes `(or nil ;(gethash …))' which forces a decrypt per
calendar on every sync."
  (let ((id (oauth2-auto--compute-id username provider)))
    (or (gethash id oauth2-auto--plstore-cache)
        (let ((plstore (plstore-open oauth2-auto-plstore)))
          (unwind-protect
              (puthash id
                       (cdr (plstore-get plstore id))
                       oauth2-auto--plstore-cache)
            (plstore-close plstore))))))

(defun luciano/oauth2-auto--with-plstore-lock (orig-fun &rest args)
  "Serialize plstore open/save so parallel calendar syncs don't race."
  (while luciano/oauth2-plstore-busy
    (accept-process-output nil 0.05))
  (setq luciano/oauth2-plstore-busy t)
  (unwind-protect
      (apply orig-fun args)
    (setq luciano/oauth2-plstore-busy nil)))

(defun luciano/org-gcal-ensure-token-unlocked (&optional force)
  "Decrypt oauth2 plstore once so the passphrase is cached for this session.
Uses Emacs minibuffer (loopback pinentry), not system pinentry.
Non-interactive calls never prompt — return nil if locked unless FORCE."
  (interactive (list t))
  (require 'oauth2-auto)
  (require 'plstore)
  (cond
   ((luciano/org-gcal-tokens-unlocked-p) t)
   ((and (not force) (not (called-interactively-p 'any))) nil)
   (t
    (let ((plstore (plstore-open oauth2-auto-plstore)))
      (unwind-protect
          (when-let ((name (car-safe (car (plstore--get-alist plstore)))))
            (plstore-get plstore name))
        (plstore-close plstore)))
    (luciano/org-gcal-tokens-unlocked-p))))

(defun luciano/org-gcal-readonly-calendar-p (calendar-id)
  "Non-nil if CALENDAR-ID is the Canvas import calendar."
  (equal calendar-id luciano/org-gcal-canvas-id))

(defun luciano/org-gcal-readonly-file-p (&optional file)
  "Non-nil if FILE is the Canvas pull-only org file."
  (let ((file (file-truename (or file (buffer-file-name) ""))))
    (equal file
           (file-truename (expand-file-name "canvas.org" org-directory)))))

(defun luciano/org-gcal-writable-file-p (&optional file)
  "Non-nil if FILE maps to a writable Google calendar (not Canvas import)."
  (let ((file (file-truename (or file (buffer-file-name) ""))))
    (and (member file
                 (mapcar (lambda (f) (file-truename (expand-file-name f org-directory)))
                         '("personal.org" "arbor.org" "school.org")))
         t)))

(defun luciano/org-gcal-calendar-id-for-file (&optional file)
  "Return the Google calendar-id mapped to FILE in `org-gcal-fetch-file-alist'.
Prefer a writable (non-Canvas) mapping when a file somehow appears twice."
  (let* ((file (file-truename (or file (buffer-file-name) "")))
         (matches (cl-remove-if-not
                   (lambda (x)
                     (equal file
                            (file-truename (expand-file-name (cdr x)))))
                   org-gcal-fetch-file-alist))
         (writable (cl-find-if-not
                    (lambda (x) (luciano/org-gcal-readonly-calendar-p (car x)))
                    matches)))
    (car-safe (or writable (car matches)))))

(defun luciano/org-gcal-ensure-postable ()
  "Prepare headline at point for a non-interactive push to Google Calendar.
Sets calendar-id from the file mapping and an empty :org-gcal: drawer so
later `org-gcal-sync' can find the entry. Never stamps Canvas (pull-only)."
  (require 'org-gcal)
  (when (luciano/org-gcal-readonly-file-p)
    (user-error "org-gcal: canvas.org is pull-only — mark TODOs locally only"))
  (let ((id (luciano/org-gcal-calendar-id-for-file)))
    (unless id
      (user-error "org-gcal: no calendar mapped for %s" (buffer-file-name)))
    ;; New events always take the file's calendar. Existing entry-ids keep
    ;; their calendar-id so we don't silently move Google events.
    (if (org-entry-get (point) org-gcal-entry-id-property)
        (unless (org-entry-get (point) org-gcal-calendar-id-property)
          (org-entry-put (point) org-gcal-calendar-id-property id))
      (org-entry-put (point) org-gcal-calendar-id-property id)))
  (save-excursion
    (org-back-to-heading t)
    (let ((end (save-excursion (outline-next-heading) (point))))
      (unless (re-search-forward
               (format "^[ \t]*:%s:[ \t]*$" org-gcal-drawer-name) end t)
        (org-end-of-meta-data t)
        (unless (bolp) (insert "\n"))
        (insert (format ":%s:\n:END:\n" org-gcal-drawer-name)))))
  t)

(defun luciano/org-gcal--post-quietly ()
  "Call `org-gcal-post-at-point' without blocking on calendar-id/duration prompts.
Does not stub unrelated minibuffer reads (oauth / pinentry)."
  (require 'org-gcal)
  (luciano/org-gcal-ensure-postable)
  (let* ((org-gcal-managed-post-at-point-update-existing 'always-push)
         (cal (or (org-entry-get (point) org-gcal-calendar-id-property)
                  (luciano/org-gcal-calendar-id-for-file)))
         (orig-cr (symbol-function 'completing-read))
         (orig-rfm (symbol-function 'read-from-minibuffer)))
    (when (luciano/org-gcal-readonly-calendar-p cal)
      (user-error "org-gcal: refusing to post to Canvas import calendar"))
    (unless cal
      (user-error "org-gcal: no calendar-id for %s" (buffer-file-name)))
    (cl-letf (((symbol-function 'completing-read)
               (lambda (prompt &rest args)
                 (if (and prompt (string-match-p "Calendar ID" prompt))
                     (format "%s (%s)" (buffer-file-name) cal)
                   (apply orig-cr prompt args))))
              ((symbol-function 'read-from-minibuffer)
               (lambda (prompt &optional default &rest args)
                 (if (and prompt (string-match-p "Duration" prompt))
                     (or default
                         (org-duration-from-minutes
                          (max org-gcal-event-default-duration 30)))
                   (apply orig-rfm prompt default args)))))
      (org-gcal-post-at-point nil nil 'always-push))))

(defun luciano/org-agenda-redo-if-live ()
  "Refresh an open agenda buffer so it matches Org/GCal without reopening."
  (when (and (boundp 'org-agenda-buffer-name)
             (get-buffer org-agenda-buffer-name))
    (ignore-errors
      (with-current-buffer org-agenda-buffer-name
        (org-agenda-redo t)))))

(defun luciano/org-gcal--finish-async (&optional interactive message)
  "Clear sync guard, auto-clock, and redo agenda after deferred GCal work."
  (setq luciano/org-gcal--syncing nil)
  (luciano/org-auto-clock-calendars)
  (luciano/org-agenda-redo-if-live)
  (when (and interactive message)
    (message "%s" message)))

(defun luciano/org-gcal-sync (&optional interactive)
  "Bidirectional sync for Personal/Arbor/School; Canvas is fetched pull-only."
  (interactive (list t))
  (require 'org-gcal)
  (when (or interactive (not luciano/org-gcal--syncing))
    (setq luciano/org-gcal--syncing t)
    (condition-case err
        (progn
          (unless (luciano/org-gcal-ensure-token-unlocked interactive)
            (setq luciano/org-gcal--syncing nil)
            (when interactive
              (user-error "org-gcal: unlock tokens first (SPC G u)"))
            (error "org-gcal: tokens locked"))
          (org-gcal-sync)
          ;; org-gcal-sync is deferred — keep the guard up until requests settle.
          (run-with-idle-timer
           6 nil #'luciano/org-gcal--finish-async interactive
           (and interactive "org-gcal: sync finished")))
      (error
       (setq luciano/org-gcal--syncing nil)
       (when interactive
         (user-error "org-gcal sync failed: %s" (error-message-string err)))))))

(defun luciano/org-gcal-fetch (&optional interactive)
  "Pull Google → Org only (phone/GCal edits show up in agenda)."
  (interactive (list t))
  (require 'org-gcal)
  (unless (luciano/org-gcal-ensure-token-unlocked interactive)
    (when interactive
      (user-error "org-gcal: unlock tokens first (SPC G u)"))
    (error "org-gcal: tokens locked"))
  (setq luciano/org-gcal--syncing t)
  (org-gcal-fetch)
  (run-with-idle-timer
   6 nil #'luciano/org-gcal--finish-async interactive
   (and interactive "org-gcal: fetch finished")))

(defun luciano/org-update-arbor-clocktable ()
  "Refresh the weekly clocktable dblock in arbor.org."
  (let ((file (expand-file-name "arbor.org" org-directory))
        (luciano/org-gcal--syncing t))
    (when (file-readable-p file)
      (with-current-buffer (find-file-noselect file)
        (org-with-wide-buffer
         (goto-char (point-min))
         (when (re-search-forward "^#\\+begin: clocktable" nil t)
           (org-dblock-update)))
        (when (buffer-modified-p)
          (save-buffer))))))

(defun luciano/org-auto-clock-calendars ()
  "Auto-clock finished timed events across all category calendars."
  (dolist (f '("arbor.org" "personal.org" "school.org" "canvas.org"))
    (ignore-errors
      (luciano/org-auto-clock-from-timestamps
       (expand-file-name f org-directory))))
  (ignore-errors (luciano/org-update-arbor-clocktable)))

(defun luciano/org-gcal-canvas-todo-on-fetch (calendar-id _event update-mode)
  "Stamp Canvas import headlines with TODO so you can track progress locally.
Does not push back to Google (Canvas calendar is read-only)."
  (when (and (luciano/org-gcal-readonly-calendar-p calendar-id)
             (memq update-mode '(newly-fetched update-existing))
             (not (org-get-todo-state)))
    (org-todo "TODO")))

(defun luciano/org-gcal-post-at-point ()
  "Push headline at point to Google (required once for brand-new events)."
  (interactive)
  (luciano/org-gcal--post-quietly))

(defun luciano/org-gcal-post-new-in-buffer ()
  "Post open, timed headlines in the current file that have no Google entry-id.
`org-gcal-sync' skips these: it only walks headlines that already have a
:org-gcal: drawer."
  (require 'org-gcal)
  (when (luciano/org-gcal-writable-file-p)
    (org-map-entries
     (lambda ()
       (let ((todo (org-get-todo-state)))
         (when (and todo
                    (not (member todo org-done-keywords))
                    (not (org-entry-get (point) org-gcal-entry-id-property))
                    (or (org-get-scheduled-time (point))
                        (org-get-deadline-time (point))))
           (condition-case err
               (luciano/org-gcal--post-quietly)
             (error (message "org-gcal post new: %s"
                             (error-message-string err)))))))
     nil 'file)))

(defun luciano/org-gcal-post-after-capture ()
  "After capture into personal/arbor/school, post the new event to Google.
Does not touch GPG plstores (that was hanging capture) and does not prompt."
  (unless org-note-abort
    (save-excursion
      (save-window-excursion
        (condition-case err
            (progn
              (org-capture-goto-last-stored)
              (when (and (buffer-file-name)
                         (luciano/org-gcal-writable-file-p))
                ;; Mark so after-save does not immediately post a second copy.
                (setq luciano/org-gcal--just-captured t)
                (run-with-idle-timer
                 5 nil (lambda () (setq luciano/org-gcal--just-captured nil)))
                (luciano/org-gcal--post-quietly)))
          (error (message "org-gcal post after capture: %s"
                          (error-message-string err))))))))

(defun luciano/org-gcal-post-after-schedule (&rest _)
  "Push SCHEDULED time changes to Google (native reschedule → PATCH).
Does not wait on `luciano/org-gcal--syncing' — that flag was blocking reschedules."
  (unless (or luciano/org-gcal--suppress-schedule-post
              (not (buffer-file-name))
              (not (luciano/org-gcal-writable-file-p)))
    (let ((buf (current-buffer))
          (marker (point-marker)))
      (run-with-idle-timer
       0.5 nil
       (lambda ()
         (when (buffer-live-p buf)
           (with-current-buffer buf
             (save-excursion
               (goto-char marker)
               (org-back-to-heading t)
               (when (and (luciano/org-gcal-writable-file-p)
                          (or (org-get-scheduled-time (point))
                              (org-entry-get (point) "entry-id")))
                 (condition-case err
                     (progn
                       (unless (luciano/org-gcal-tokens-unlocked-p)
                         (message "org-gcal: unlock tokens (SPC G u) to push reschedule"))
                       (when (luciano/org-gcal-tokens-unlocked-p)
                         (luciano/org-gcal--post-quietly)
                         (message "org-gcal: pushed reschedule for %s"
                                  (org-get-heading t t t t))))
                   (error (message "org-gcal post after schedule: %s"
                                   (error-message-string err)))))))))))))

(defun luciano/org-gcal-post-after-agenda-schedule (&rest _)
  "After `org-agenda-schedule', push the underlying Org headline to Google."
  (let ((marker (org-get-at-bol 'org-hd-marker)))
    (when (and marker (marker-buffer marker))
      (run-with-idle-timer
       0.5 nil
       (lambda ()
         (when (and (markerp marker) (marker-buffer marker))
           (with-current-buffer (marker-buffer marker)
             (save-excursion
               (goto-char marker)
               (org-back-to-heading t)
               (when (and (not luciano/org-gcal--suppress-schedule-post)
                          (luciano/org-gcal-writable-file-p))
                 (condition-case err
                     (if (luciano/org-gcal-tokens-unlocked-p)
                         (progn
                           (luciano/org-gcal--post-quietly)
                           (message "org-gcal: pushed agenda reschedule for %s"
                                    (org-get-heading t t t t)))
                       (message "org-gcal: unlock tokens (SPC G u) to push reschedule"))
                   (error (message "org-gcal agenda reschedule: %s"
                                   (error-message-string err)))))))))))))

(defun luciano/org-gcal-push-existing-in-buffer ()
  "Quietly PATCH every headline in this buffer that already has a Google entry-id.
Covers manual SCHEDULED edits that did not go through `org-schedule'."
  (require 'org-gcal)
  (when (and (luciano/org-gcal-writable-file-p)
             (luciano/org-gcal-tokens-unlocked-p))
    (org-map-entries
     (lambda ()
       (when (org-entry-get (point) org-gcal-entry-id-property)
         (condition-case err
             (luciano/org-gcal--post-quietly)
           (error (message "org-gcal push existing: %s"
                           (error-message-string err))))))
     nil 'file)))

(defun luciano/org-gcal-sync-after-save ()
  "Debounced push of new + existing events after saving a writable org file."
  (when (and (eq major-mode 'org-mode)
             (luciano/org-gcal-writable-file-p)
             (not luciano/org-gcal--just-captured))
    (let ((buf (current-buffer)))
      (run-with-idle-timer
       1.5 nil
       (lambda ()
         (when (and (buffer-live-p buf)
                    (not luciano/org-gcal--just-captured))
           (with-current-buffer buf
             (luciano/org-gcal-post-new-in-buffer)
             (luciano/org-gcal-push-existing-in-buffer))))))))

(defun luciano/org-gcal-fetch-before-agenda (&rest _)
  "Pull from Google before agenda so phone edits are visible.
Skips entirely when tokens are locked — opening agenda must never hang on pinentry."
  (when (and (not luciano/org-gcal--syncing)
             (luciano/org-gcal-tokens-unlocked-p))
    (run-with-idle-timer 0.1 nil #'luciano/org-gcal-fetch)))

(defun luciano/org-gcal--update-entry-guard (orig &rest args)
  "Run `org-gcal--update-entry' without triggering our schedule→post advice."
  (let ((luciano/org-gcal--suppress-schedule-post t)
        (luciano/org-gcal--syncing t))
    (apply orig args)))

;; Load now so capture/save hooks exist even if you never run SPC G s.
(require 'oauth2-auto)
(require 'org-gcal)

;; Upstream oauth2-auto disables its plstore memory cache and opens the
;; encrypted file once per calendar. Patch that, and serialize disk access.
(advice-add 'oauth2-auto--plstore-read :override #'luciano/oauth2-auto--plstore-read)
(advice-add 'oauth2-auto--plstore-read :around #'luciano/oauth2-auto--with-plstore-lock)
(advice-add 'oauth2-auto--plstore-write :around #'luciano/oauth2-auto--with-plstore-lock)

(after! org-gcal
  (org-gcal-reload-client-id-secret)
  ;; personal / arbor / school: read/write to matching Google calendars.
  ;; canvas: Canvas ICS import — pull only; TODO states stay local in Org.
  (setq org-gcal-fetch-file-alist
        `((,luciano/org-gcal-personal-id . "~/org/personal.org")
          (,luciano/org-gcal-arbor-id . "~/org/arbor.org")
          (,luciano/org-gcal-school-id . "~/org/school.org")
          (,luciano/org-gcal-canvas-id . "~/org/canvas.org"))
        org-gcal-recurring-events-mode 'top-level
        org-gcal-up-days 60
        org-gcal-down-days 60
        org-gcal-notify-p nil
        ;; Never ask "Push event to Google Calendar?" on post.
        org-gcal-managed-post-at-point-update-existing 'always-push)

  ;; Stock org-gcal adds its own capture poster at load time. That + ours
  ;; created TWO Google events per capture (then fetch reimported the twin).
  (advice-add #'org-gcal--capture-post :override #'ignore)
  (remove-hook 'org-capture-after-finalize-hook #'org-gcal--capture-post)
  (remove-hook 'org-capture-after-finalize-hook 'org-gcal--capture-post)
  (add-hook 'org-capture-after-finalize-hook #'luciano/org-gcal-post-after-capture)
  (add-hook 'after-save-hook #'luciano/org-gcal-sync-after-save)
  (add-hook 'org-gcal-after-update-entry-functions
            #'luciano/org-gcal-canvas-todo-on-fetch)
  (advice-add 'org-agenda :before #'luciano/org-gcal-fetch-before-agenda)
  (advice-add 'org-schedule :after #'luciano/org-gcal-post-after-schedule)
  (advice-add 'org-agenda-schedule :after #'luciano/org-gcal-post-after-agenda-schedule)
  ;; When org-gcal itself rewrites SCHEDULED during fetch, don't push back.
  (advice-add 'org-gcal--update-entry :around #'luciano/org-gcal--update-entry-guard)

  ;; One delayed startup sync, then every 30 minutes (guard against doom reload).
  (unless (bound-and-true-p luciano/org-gcal--timers-started)
    (setq luciano/org-gcal--timers-started t)
    (run-with-idle-timer 5 nil #'luciano/org-gcal-sync)
    (run-with-timer (* 30 60) (* 30 60) #'luciano/org-gcal-sync))

  (map! :leader
        (:prefix ("G" . "gcal")
         :desc "Sync" "s" #'luciano/org-gcal-sync
         :desc "Fetch (pull)" "f" #'luciano/org-gcal-fetch
         :desc "Post at point" "p" #'luciano/org-gcal-post-at-point
         :desc "Unlock tokens" "u" #'luciano/org-gcal-ensure-token-unlocked)))

;;; ==========================================
;;; ORG + TYPST MATH (restored)
;;; ==========================================
;; Write Typst inside $...$ (not LaTeX). Preview with typst-overlay; export with
;; ox-typst (C-c C-e y). Inline: $a^2$. Display: $ sum_(k=1)^n k $ (spaces).

(use-package! ox-typst
  :after org
  :config
  (setq org-typst-from-latex-fragment #'org-typst-from-latex-with-naive
        org-typst-from-latex-environment #'org-typst-from-latex-with-naive))

(use-package! typst-ts-mode
  :mode "\\.typ\\'"
  :config
  (setq typst-ts-watch-options '("--open"))
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

(defun luciano/typst-overlay-maybe-enable ()
  "Enable `typst-overlay-mode' in real Org buffers only."
  (when (eq major-mode 'org-mode)
    (with-demoted-errors "typst-overlay: %S"
      (typst-overlay-mode +1))))

(use-package! typst-overlay
  :commands (typst-overlay-mode typst-overlay-refresh)
  :hook ((org-mode . luciano/typst-overlay-maybe-enable)
         (typst-ts-mode . typst-overlay-mode)
         (after-save . typst-overlay-save-refresh))
  :config
  (setq typst-overlay-scale 1.3)
  (defadvice! luciano/typst-overlay-use-org-analyzer (&rest _)
    "Use multiline-capable Org math detection."
    :after #'typst-overlay--enable
    (when (derived-mode-p 'org-mode)
      (setq-local typst-overlay--analyzer #'luciano/typst-overlay-analyze-org)
      (typst-overlay-refresh))))

;; Projectile: use VCS for file indexing.
(setq projectile-indexing-method 'alien)

(set-eglot-client! '(c-mode c-ts-mode c++-mode c++-ts-mode)
                   '("/home/luciano/.local/bin/esp-clangd"
                     "-j=4"
                     "--background-index"
                     "--clang-tidy"
                     "--completion-style=detailed"
                     "--header-insertion=iwyu"
                     "--header-insertion-decorators"))
