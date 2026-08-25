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

;; Soft-wrapping code mid-statement is painful, so we don't auto-wrap
;; programming buffers. Org/text still auto-fill (hard wrap) at fill-column.
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
          ;; Capture groups before org-time-string-to-time (it clobbers match-data).
          (let* ((ts1 (match-string-no-properties 1))
                 (ts2 (match-string-no-properties 2))
                 (cstart (and ts1 (org-time-string-to-time ts1)))
                 (cend (and ts2 (org-time-string-to-time ts2))))
            (when (and cstart cend
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
                ;; org-time-stamp-format already includes […]; do not wrap again.
                (insert
                 "CLOCK: "
                 (format-time-string (org-time-stamp-format t t) start)
                 "--"
                 (format-time-string (org-time-stamp-format t t) end)
                 " => "
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
        ;; (create-step . shift-step). Shift step = 15 so agenda M-up/down
        ;; slides events in quarter-hour increments.
        org-time-stamp-rounding-minutes '(0 15)
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
               ;; Capture groups first — org-time-string-to-time clobbers match-data
               ;; (otherwise match-string 2 reads buffer positions 0..4 and errors).
               (let* ((ts1 (match-string-no-properties 1))
                      (ts2 (match-string-no-properties 2))
                      (cs (and ts1 (org-time-string-to-time ts1)))
                      (ce (and ts2 (org-time-string-to-time ts2))))
                 (when (and cs ce
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
          (local-set-key (kbd "q") #'luciano/kill-buffer-ask-save)))
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

  (defvar luciano/org-command-center-active nil
    "Non-nil while the command-center agenda+chart layout should stay open.")

  (defun luciano/org-refresh-command-chart ()
    "Rebuild *Org Command Chart* if it exists (keep week shift)."
    (when-let ((buf (get-buffer "*Org Command Chart*")))
      (with-current-buffer buf
        (luciano/org--weekly-dashboard-buffer
         (or (and (boundp 'luciano/org-command-chart-week)
                  luciano/org-command-chart-week)
             0)))))

  (defun luciano/org--ensure-command-chart-window ()
    "Show the bar chart in a right split next to the agenda, if missing."
    (when-let ((agenda-win (or (get-buffer-window org-agenda-buffer-name)
                               (and (eq major-mode 'org-agenda-mode)
                                    (selected-window)))))
      (let* ((chart (luciano/org--weekly-dashboard-buffer
                     (or (and (get-buffer "*Org Command Chart*")
                              (with-current-buffer "*Org Command Chart*"
                                (and (boundp 'luciano/org-command-chart-week)
                                     luciano/org-command-chart-week)))
                         0)))
             (chart-win (get-buffer-window chart)))
        (unless chart-win
          (with-selected-window agenda-win
            (when (one-window-p t)
              (split-window-right))
            (let ((right (window-in-direction 'right)))
              (if right
                  (set-window-buffer right chart)
                (split-window-right)
                (other-window 1)
                (switch-to-buffer chart)
                (other-window -1)))))
        chart)))

  (defun luciano/org-show-command-chart (&optional week-shift)
    "Pop the command-center bar chart (planned time + Arbor timesheet).
Call this anytime — SPC o C — if the right pane went missing."
    (interactive (list 0))
    (let ((buf (luciano/org--weekly-dashboard-buffer (or week-shift 0))))
      (if-let ((win (get-buffer-window buf)))
          (select-window win)
        (display-buffer
         buf
         '((display-buffer-reuse-window display-buffer-in-side-window)
           (side . right)
           (window-width . 0.42)
           (reusable-frames . visible))))
      buf))

  (defun luciano/org-agenda-command-center (&optional _match)
    "Command center: 10-day agenda (left) + planned chart / timesheet (right)."
    (setq luciano/org-command-center-active t)
    (let ((org-agenda-window-setup 'only-window)
          (luciano/inhibit-kill-on-delete-window t))
      (org-agenda nil "d!"))
    (when-let ((agenda-win (get-buffer-window org-agenda-buffer-name)))
      (select-window agenda-win)
      (let ((luciano/inhibit-kill-on-delete-window t))
        (delete-other-windows))
      (split-window-right)
      (other-window 1)
      (switch-to-buffer (luciano/org--weekly-dashboard-buffer 0))
      (other-window 1))
    ;; If agenda landed elsewhere, still force the chart pane.
    (luciano/org--ensure-command-chart-window))

  (defun luciano/org-agenda-insert-weekly-dashboard (&optional _match)
    "Legacy stacked insert (unused by command center; kept for T-style reuse)."
    (let ((inhibit-read-only t))
      (goto-char (point-max))
      (unless (bolp) (insert "\n"))
      (insert "\n"
              (propertize "════════ Time this week ════════\n" 'face 'bold)
              (luciano/org--format-weekly-dashboard 0 t)
              "\n")))

  ;; Keep the bar chart visible + fresh while the command center is up.
  (defun luciano/org-agenda-maybe-restore-chart ()
    (when luciano/org-command-center-active
      (luciano/org--ensure-command-chart-window)
      (luciano/org-refresh-command-chart)))
  (add-hook 'org-agenda-finalize-hook #'luciano/org-agenda-maybe-restore-chart)

  ;;; --- Schedule sidecar (see what's booked while capturing) ------------
  (defun luciano/org--hhmm (hour minute)
    "12h clock string for HOUR/MINUTE."
    (let* ((h (mod (or hour 0) 24))
           (m (or minute 0))
           (h12 (let ((x (mod h 12))) (if (zerop x) 12 x))))
      (format "%d:%02d%s" h12 m (if (< h 12) "am" "pm"))))

  (defun luciano/org--collect-schedule-overview (start end &optional files)
    "Timed SCHEDULED blocks in [START,END) for a capture/schedule sidecar.
Includes point-in-time stamps (no end) as start-only rows."
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
                           (plist (and sched (eq (car-safe sched) 'timestamp)
                                       (cadr sched))))
                      (when (and plist (plist-get plist :hour-start))
                        (let* ((hs (plist-get plist :hour-start))
                               (ms (or (plist-get plist :minute-start) 0))
                               (he (plist-get plist :hour-end))
                               (me (or (plist-get plist :minute-end) 0))
                               (cs (encode-time
                                    0 ms hs
                                    (plist-get plist :day-start)
                                    (plist-get plist :month-start)
                                    (plist-get plist :year-start)))
                               (ce (if he
                                       (encode-time
                                        0 me he
                                        (or (plist-get plist :day-end)
                                            (plist-get plist :day-start))
                                        (or (plist-get plist :month-end)
                                            (plist-get plist :month-start))
                                        (or (plist-get plist :year-end)
                                            (plist-get plist :year-start)))
                                     (luciano/org--time-add cs (* 30 60)))))
                          (when (and (time-less-p cs end)
                                     (time-less-p start ce))
                            (push (list :cat cat
                                        :title (org-get-heading t t t t)
                                        :day (format-time-string "%a %m/%d" cs)
                                        :when (if he
                                                  (format "%s–%s"
                                                          (luciano/org--hhmm hs ms)
                                                          (luciano/org--hhmm he me))
                                                (luciano/org--hhmm hs ms))
                                        :sort (float-time cs))
                                  rows))))))))
              nil 'file)))))
      (cl-sort (nreverse rows) #'< :key (lambda (r) (plist-get r :sort)))))

  (defun luciano/org--format-schedule-sidecar (&optional days)
    "Plain-text overview of booked times for the next DAYS (default 5)."
    (let* ((days (or days 5))
           (start (luciano/org--time-add
                   (apply #'encode-time
                          (append '(0 0 0)
                                  (nthcdr 3 (decode-time (current-time)))))
                   0))
           (end (luciano/org--time-add start (* days 24 60 60)))
           (rows (luciano/org--collect-schedule-overview start end))
           (out (concat
                 (propertize
                  (format "Already booked · next %d day%s\n"
                          days (if (= days 1) "" "s"))
                  'face 'bold)
                 (propertize
                  "Use this while picking a time for a new note.\n\n"
                  'face 'shadow)))
           (cur-day nil))
      (if (null rows)
          (setq out (concat out (propertize "(nothing timed yet)\n" 'face 'shadow)))
        (dolist (r rows)
          (let ((day (plist-get r :day)))
            (unless (equal day cur-day)
              (setq cur-day day)
              (setq out (concat out
                                (propertize (format "%s\n" day) 'face 'bold))))
            (setq out
                  (concat out
                          (format "  %-11s %s\n"
                                  (propertize (plist-get r :when) 'face 'success)
                                  (truncate-string-to-width
                                   (format "%s  [%s]"
                                           (plist-get r :title)
                                           (plist-get r :cat))
                                   40 nil nil "…")))))))
      out))

  (defun luciano/org-show-schedule-sidecar (&rest _)
    "Side window: what's already scheduled (for capture / time prompts)."
    (interactive)
    (let ((buf (get-buffer-create "*Schedule now*")))
      (with-current-buffer buf
        (let ((inhibit-read-only t))
          (erase-buffer)
          (special-mode)
          (setq-local revert-buffer-function
                      (lambda (&rest _) (luciano/org-show-schedule-sidecar)))
          (insert (luciano/org--format-schedule-sidecar 5))
          (goto-char (point-min))
          (local-set-key (kbd "g") #'revert-buffer)
          (local-set-key (kbd "q") #'quit-window)))
      (display-buffer
       buf
       '((display-buffer-reuse-window display-buffer-in-side-window)
         (side . right)
         (slot . 1)
         (window-width . 42)
         (dedicated . t)
         (reusable-frames . visible)))
      buf))

  (defun luciano/org-hide-schedule-sidecar (&rest _)
    "Drop the schedule sidecar when capture finishes."
    (when-let ((buf (get-buffer "*Schedule now*")))
      (when-let ((win (get-buffer-window buf)))
        (quit-window t win))))

  (add-hook 'org-capture-mode-hook #'luciano/org-show-schedule-sidecar)
  (add-hook 'org-capture-after-finalize-hook #'luciano/org-hide-schedule-sidecar)
  ;; Refresh while answering %^T / schedule prompts (only during capture).
  (defun luciano/org-maybe-refresh-schedule-sidecar (&rest _)
    (when (bound-and-true-p org-capture-mode)
      (luciano/org-show-schedule-sidecar)))
  (advice-add 'org-read-date :before #'luciano/org-maybe-refresh-schedule-sidecar)

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
          (local-set-key (kbd "q") #'luciano/kill-buffer-ask-save)))
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
          (local-set-key (kbd "q") #'luciano/kill-buffer-ask-save)))
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

  (defun luciano/org--slide-heading-minutes (hdmarker minutes)
    "Shift SCHEDULED (else DEADLINE / first stamp) at HDMARKER by MINUTES.
Preserves HH:MM-HH:MM duration. Return non-nil on success."
    (when (and (markerp hdmarker) (marker-buffer hdmarker))
      (with-current-buffer (marker-buffer hdmarker)
        (org-with-wide-buffer
         (goto-char hdmarker)
         (org-back-to-heading t)
         (let ((bound (save-excursion (outline-next-heading) (point)))
               (changed nil))
           (cl-labels
               ((shift-at-match ()
                  ;; Point at `<' of an active timestamp → change minutes.
                  (when (org-at-timestamp-p 'lax)
                    (org-timestamp-change minutes 'minute)
                    (setq changed t))))
             (save-excursion
               (cond
                ((re-search-forward org-scheduled-time-regexp bound t)
                 (goto-char (1- (match-beginning 1)))
                 (shift-at-match))
                ((re-search-forward org-deadline-time-regexp bound t)
                 (goto-char (1- (match-beginning 1)))
                 (shift-at-match))
                ((re-search-forward org-ts-regexp bound t)
                 (goto-char (match-beginning 0))
                 (shift-at-match)))))
           changed)))))

  (defun luciano/org-agenda-slide-targets ()
    "Headlines to slide: bulk-marked, else region lines, else point."
    (cond
     (org-agenda-bulk-marked-entries
      (cl-remove-if-not (lambda (m) (and (markerp m) (marker-buffer m)))
                        (reverse org-agenda-bulk-marked-entries)))
     ((use-region-p)
      (let (ms)
        (save-excursion
          (goto-char (region-beginning))
          (while (< (point) (region-end))
            (when-let ((m (org-get-at-bol 'org-hd-marker)))
              (push m ms))
            (forward-line 1)))
        (nreverse (delete-dups ms))))
     (t
      (list (or (org-get-at-bol 'org-hd-marker)
                (org-agenda-error))))))

  (defun luciano/org-agenda-slide-minutes (n)
    "Reschedule agenda entry(ies) by N×15 minutes (negative = earlier).
With bulk marks (`m`) or an active region, shift all of them; otherwise
the line at point. Saves Org files and pushes writable calendars to GCal."
    (interactive "p")
    (org-agenda-check-type t 'agenda)
    (let* ((step (* n (or (cadr org-time-stamp-rounding-minutes) 15)))
           (targets (luciano/org-agenda-slide-targets))
           (buffers nil)
           (count 0)
           (heading-ids nil))
      (unless targets
        (user-error "Nothing to reschedule at point (mark with m, or select a region)"))
      (dolist (hd targets)
        (when (luciano/org--slide-heading-minutes hd step)
          (setq count (1+ count))
          (cl-pushnew (marker-buffer hd) buffers)
          (push (copy-marker hd) heading-ids)))
      (dolist (buf buffers)
        (with-current-buffer buf
          (when (buffer-modified-p)
            ;; Suppress bulk after-save; we push each heading below.
            (let ((luciano/org-gcal--just-captured t))
              (save-buffer)))))
      ;; Same deferred push path as native agenda reschedule (proven to work).
      (dolist (hd (nreverse heading-ids))
        (when (fboundp 'luciano/org-gcal-push-heading-at-marker)
          (luciano/org-gcal-push-heading-at-marker hd 'verbose)))
      (when org-agenda-bulk-marked-entries
        (org-agenda-bulk-unmark-all))
      (org-agenda-redo t)
      (when (fboundp 'luciano/org-refresh-command-chart)
        (luciano/org-refresh-command-chart))
      (message "Rescheduled %d event%s by %+d min (GCal push queued)"
               count (if (= count 1) "" "s") step)))

  (defun luciano/org-agenda-slide-later (&optional arg)
    "Slide event(s) ARG×15 minutes later. Bulk marks / region supported."
    (interactive "p")
    (luciano/org-agenda-slide-minutes (or arg 1)))

  (defun luciano/org-agenda-slide-earlier (&optional arg)
    "Slide event(s) ARG×15 minutes earlier. Bulk marks / region supported."
    (interactive "p")
    (luciano/org-agenda-slide-minutes (- (or arg 1))))

  (map! :map org-mode-map
        :localleader
        :desc "Sort open tasks first" "S" #'luciano/org-sort-open-first
        :desc "Fold DONE/CANCELLED" "F" #'luciano/org-fold-done-entries)
  (map! :leader
        :desc "Command bar chart" "o C" #'luciano/org-show-command-chart
        :desc "CLOCK time chart" "o T" #'luciano/org-weekly-time-chart
        :desc "What's booked" "o B" #'luciano/org-show-schedule-sidecar
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

(defun luciano/org-gcal-push-heading-at-marker (marker &optional verbose)
  "Deferred GCal push for the Org headline at MARKER.
VERBOSE non-nil prints skip/success/error messages (used by agenda slide)."
  (when (and (markerp marker) (marker-buffer marker))
    (let ((buf (marker-buffer marker))
          (pos (marker-position marker)))
      (run-with-idle-timer
       0.4 nil
       (lambda ()
         (when (buffer-live-p buf)
           (with-current-buffer buf
             (save-excursion
               (goto-char pos)
               (org-back-to-heading t)
               (let ((title (org-get-heading t t t t)))
                 (cond
                  ((not (luciano/org-gcal-writable-file-p))
                   (when verbose
                     (message "org-gcal: skip %s (canvas/readonly or unmapped file)"
                              title)))
                  ((not (luciano/org-gcal-tokens-unlocked-p))
                   (message "org-gcal: unlock tokens (SPC G u) to push “%s”" title))
                  (t
                   (condition-case err
                       (progn
                         (luciano/org-gcal--post-quietly)
                         ;; ensure-postable may have dirtied the buffer
                         (when (buffer-modified-p)
                           (let ((luciano/org-gcal--just-captured t))
                             (save-buffer)))
                         (when verbose
                           (message "org-gcal: pushed “%s”" title)))
                     (error
                      (message "org-gcal push “%s”: %s"
                               title (error-message-string err)))))))))))))))

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

;; Enable code execution for C, Python, and Bash
(org-babel-do-load-languages
 'org-babel-load-languages
 '((C . t)
   (python . t)
   (shell . t)))

;;; ==========================================
;;; QUIT = ask save, then kill; never land on *scratch*
;;; ==========================================
;; IMPORTANT: do NOT advise delete-window to kill file buffers.
;; Stock Evil :wq / :q → evil-window-delete → on a sole window, delete-window
;; errors → evil-quit falls through to save-buffers-kill-emacs. Killing the
;; buffer *before* that made :wq look like a crash (Emacs exited).

(defvar luciano/inhibit-kill-on-delete-window nil
  "Legacy flag; kept so older callers binding it still work.")

;; Prefer Doom dashboard over *scratch* when nothing else is open.
(setq doom-fallback-buffer-name "*doom*")

(defun luciano/dashboard-name ()
  (if (boundp '+dashboard-name) +dashboard-name "*doom*"))

(defun luciano/goto-dashboard ()
  "Show the Doom dashboard in this window/workspace; never leave *scratch* visible."
  (setq doom-fallback-buffer-name (luciano/dashboard-name))
  (delete-other-windows)
  (let ((buffer-list-update-hook nil))
    (if (fboundp '+dashboard/open)
        (+dashboard/open (selected-frame))
      (progn
        (switch-to-buffer (doom-fallback-buffer))
        (when (fboundp '+dashboard-reload)
          (+dashboard-reload t)))))
  (when (and (bound-and-true-p persp-mode)
             (fboundp 'persp-add-buffer))
    (persp-add-buffer (current-buffer) (get-current-persp) nil nil))
  (when-let ((scratch (get-buffer "*scratch*")))
    (unless (eq scratch (current-buffer))
      (dolist (win (get-buffer-window-list scratch nil t))
        (set-window-buffer win (current-buffer)))
      (ignore-errors (kill-buffer scratch))))
  (current-buffer))

(defun luciano/next-real-buffer (&optional dying)
  "Return another real buffer, or nil (caller should open the dashboard)."
  (cl-find-if (lambda (b)
                (and (not (eq b dying))
                     (not (string= (buffer-name b) "*scratch*"))
                     (not (string= (buffer-name b) (luciano/dashboard-name)))
                     (doom-real-buffer-p b)))
              (buffer-list)))

(defun luciano/last-real-buffer-p (&optional dying)
  "Non-nil if DYING is the only remaining real buffer."
  (null (luciano/next-real-buffer dying)))

(defun luciano/ensure-not-scratch ()
  "If this window shows *scratch* (or nothing real), open the dashboard."
  (when (or (string= (buffer-name) "*scratch*")
            (and (luciano/last-real-buffer-p)
                 (not (string= (buffer-name) (luciano/dashboard-name)))
                 (not (and (fboundp '+dashboard-buffer-p)
                           (+dashboard-buffer-p (current-buffer))))))
    (luciano/goto-dashboard)))

(defun luciano/kill-buffer-ask-save (&optional buffer)
  "Offer to save BUFFER if modified, then kill it (never bury).
If it was the last real buffer, land on the Doom dashboard — never *scratch*."
  (interactive)
  (let ((buf (or buffer (current-buffer))))
    (when (and (boundp 'luciano/org-command-center-active)
               luciano/org-command-center-active
               (or (and (buffer-live-p buf)
                        (string-prefix-p "*Org Agenda" (buffer-name buf)))
                   (eq buf (get-buffer "*Org Command Chart*"))))
      (setq luciano/org-command-center-active nil))
    (with-current-buffer buf
      (when (and (buffer-modified-p)
                 (or (buffer-file-name)
                     (and (boundp 'buffer-offer-save) buffer-offer-save)))
        (if (y-or-n-p (format "Save %s before killing? " (buffer-name buf)))
            (save-buffer)
          (set-buffer-modified-p nil))))
    (let* ((win (get-buffer-window buf))
           (last-p (luciano/last-real-buffer-p buf)))
      (cond
       ;; Last real buffer → dashboard, then kill.
       (last-p
        (luciano/goto-dashboard)
        (when (and (buffer-live-p buf)
                   (not (eq buf (current-buffer))))
          (let (kill-buffer-query-functions kill-buffer-hook)
            (ignore-errors (kill-buffer buf))))
        (luciano/goto-dashboard)
        (run-at-time 0 nil #'luciano/goto-dashboard))
       ;; Extra window: kill buffer + close window.
       ((and win (not (one-window-p t)))
        (with-selected-window win
          (kill-buffer buf)
          (when (window-live-p win)
            (delete-window win))))
       ;; Sole window, more real buffers left: switch to another real one.
       (t
        (when (and win (eq (window-buffer win) buf))
          (with-selected-window win
            (if-let ((other (luciano/next-real-buffer buf)))
                (switch-to-buffer other)
              (luciano/goto-dashboard))))
        (when (buffer-live-p buf)
          (let (kill-buffer-query-functions)
            (ignore-errors (kill-buffer buf))))
        (luciano/ensure-not-scratch))))))

;; :q / :wq must kill the buffer — never fall through to kill-emacs.
(defun luciano/evil-quit (&optional force)
  "Kill this buffer (ask to save). Never exit Emacs from :q.
Use SPC q q (or :qa) to leave Emacs."
  (interactive "<!>")
  (if force
      (progn
        (set-buffer-modified-p nil)
        (let (kill-buffer-query-functions)
          (kill-buffer (current-buffer)))
        (luciano/ensure-not-scratch))
    (luciano/kill-buffer-ask-save)))

(defun luciano/evil-save-and-close (file &optional bang)
  "Save, then kill buffer — never exit Emacs (fixes :wq 'crash')."
  (interactive "<f><!>")
  (evil-write nil nil nil file bang)
  (luciano/kill-buffer-ask-save))

(advice-add 'evil-quit :override #'luciano/evil-quit)
(advice-add 'evil-save-and-close :override #'luciano/evil-save-and-close)

(after! org-agenda
  ;; Agenda is not sticky: q should destroy it, not leave it buried.
  (setq org-agenda-sticky nil)
  (defun luciano/org-agenda-quit ()
    "Quit agenda; drop the command-center chart pane too."
    (interactive)
    (setq luciano/org-command-center-active nil)
    (when-let ((chart (get-buffer "*Org Command Chart*")))
      (when (get-buffer-window chart)
        (ignore-errors (kill-buffer chart))))
    (luciano/kill-buffer-ask-save))
  (define-key org-agenda-mode-map (kbd "q") #'luciano/org-agenda-quit)
  ;; Reschedule by 15m — must bind evil motion state or Alt+↑/↓ still drags lines.
  (map! :map org-agenda-mode-map
        :m "M-<down>" #'luciano/org-agenda-slide-later
        :m "M-<up>"   #'luciano/org-agenda-slide-earlier
        "M-<down>"    #'luciano/org-agenda-slide-later
        "M-<up>"      #'luciano/org-agenda-slide-earlier)
  (after! evil-org-agenda
    (evil-define-key* 'motion evil-org-agenda-mode-map
      (kbd "M-<down>") #'luciano/org-agenda-slide-later
      (kbd "M-<up>")   #'luciano/org-agenda-slide-earlier)))

;; After any kill-current-buffer, scrub *scratch* if it stole the window.
(defadvice! luciano/after-kill-current-buffer-a (&rest _)
  "Never leave the frame on *scratch* after killing a buffer."
  :after #'kill-current-buffer
  (luciano/ensure-not-scratch)
  (run-at-time 0 nil #'luciano/ensure-not-scratch))

(defun luciano/kill-all-buffers-ask-save ()
  "Offer to save, kill every buffer, then land on the Doom dashboard."
  (interactive)
  (save-some-buffers)
  (let* ((dash-name (luciano/dashboard-name))
         (dash (get-buffer-create dash-name)))
    (setq doom-fallback-buffer-name dash-name)
    (delete-other-windows)
    (switch-to-buffer dash)
    (when (fboundp '+dashboard-reload)
      (+dashboard-reload t))
    (dolist (buf (buffer-list))
      (let ((name (buffer-name buf)))
        (unless (or (eq buf dash)
                    (string= name dash-name)
                    (string-prefix-p " " name))
          (when (buffer-live-p buf)
            (with-current-buffer buf
              (when (and (buffer-modified-p) (not (buffer-file-name)))
                (set-buffer-modified-p nil)))
            (let (kill-buffer-query-functions
                  kill-buffer-hook)
              (ignore-errors (kill-buffer buf)))))))
    (luciano/goto-dashboard)
    (run-at-time 0 nil #'luciano/goto-dashboard)
    (message "Killed all buffers → %s" (buffer-name))))

;; Catch stock Doom entry points too (SPC b K before remap, :killa, etc.).
(defadvice! luciano/after-doom-kill-all-buffers-a (&rest _)
  "After Doom kill-all, force the dashboard instead of *scratch*."
  :after #'doom/kill-all-buffers
  (luciano/goto-dashboard)
  (run-at-time 0 nil #'luciano/goto-dashboard))

(map! :leader
      (:prefix ("b" . "buffer")
       :desc "Kill buffer (ask save)" "k" #'luciano/kill-buffer-ask-save
       :desc "Kill buffer (ask save)" "d" #'luciano/kill-buffer-ask-save
       :desc "Kill all → dashboard" "K" #'luciano/kill-all-buffers-ask-save))

;;; ==========================================
;;; WORKSPACES — permanent SPC TAB TAB (modeline center)
;;; ==========================================
;; Doom's +workspace/display only flashes in the echo area. Keep that same
;; [1] name [2] name list centered on the modeline, always on one line.
(defun luciano/workspace-modeline-tabs ()
  "SPC TAB TAB workspace list for the doom modeline."
  (cond
   ((not (and (fboundp '+workspace-list-names)
              (bound-and-true-p persp-mode)))
    (propertize "(ws…)" 'face 'shadow))
   (t
    (let ((names (+workspace-list-names))
          (current (+workspace-current-name))
          (i 0))
      (mapconcat
       (lambda (name)
         (setq i (1+ i))
         (let* ((label (format "[%d]%s" i name))
                (active (equal name current))
                (map (make-sparse-keymap))
                (ws name))
           (define-key map [mode-line mouse-1]
             (lambda ()
               (interactive)
               (+workspace-switch ws t)))
           (define-key map [mode-line mouse-2]
             (lambda ()
               (interactive)
               (+workspace/display)))
           (propertize
            (concat " " label " ")
            'face (if active
                      '+workspace-tab-selected-face
                    '+workspace-tab-face)
            'mouse-face 'mode-line-highlight
            'help-echo (format "%s workspace — click to switch" name)
            'local-map map)))
       names
       "")))))

;;; ==========================================
;;; MODELINE — path left, workspaces center, rest right
;;; ==========================================
(after! doom-modeline
  (setq doom-modeline-persp-name nil
        doom-modeline-workspace-name nil
        ;; Prefer a single-line modeline when Emacs supports it.
        mode-line-compact 'long)
  (advice-add #'mode-line-invisible-mode :override #'ignore)

  (doom-modeline-def-segment luciano-workspaces
    "Centered SPC TAB TAB workspace list (one line)."
    (let* ((tabs (luciano/workspace-modeline-tabs))
           (w (string-width (substring-no-properties tabs))))
      ;; Push the group to the horizontal center of the mode line.
      (concat
       (propertize " " 'display `((space :align-to (- center ,(/ w 2)))))
       tabs)))

  (doom-modeline-def-modeline 'luciano-main
    ;; Left + centered workspaces (align-to handles centering).
    '(bar buffer-info remote-host luciano-workspaces)
    ;; Right: status only — do NOT put workspaces here (avoids wrap/dupe).
    '(misc-info major-mode process vcs check buffer-position))

  (defun luciano/doom-modeline-use-main ()
    "Use the luciano modeline as the default."
    (doom-modeline-set-modeline 'luciano-main 'default)
    (setq-default header-line-format nil)
    (dolist (buf (buffer-list))
      (with-current-buffer buf
        (kill-local-variable 'header-line-format))))

  (add-hook 'doom-modeline-mode-hook #'luciano/doom-modeline-use-main)
  (when (bound-and-true-p doom-modeline-mode)
    (luciano/doom-modeline-use-main))
  (when (boundp 'persp-activated-functions)
    (add-hook 'persp-activated-functions
              (lambda (&rest _) (force-mode-line-update t)))))

;;; ==========================================
;;; THEME — match Omarchy / Aether colors
;;; ==========================================
(defvar luciano/omarchy-colors nil
  "Alist of color keys from the active Omarchy/Aether colors.toml.")

(defun luciano/load-omarchy-colors ()
  "Load colors from the active Omarchy theme (Aether writes here)."
  (let ((file (expand-file-name
               "omarchy/current/theme/colors.toml"
               (or (getenv "XDG_STATE_HOME")
                   (expand-file-name "~/.local/state"))))
        colors)
    (unless (file-readable-p file)
      (setq file (expand-file-name "~/.config/omarchy/current/theme/colors.toml")))
    (when (file-readable-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (goto-char (point-min))
        (while (re-search-forward
                "^\\([a-z0-9_]+\\)\\s-*=\\s-*\"\\(#[A-Fa-f0-9]+\\)\"" nil t)
          (push (cons (match-string-no-properties 1)
                      (match-string-no-properties 2))
                colors)))
      (setq luciano/omarchy-colors (nreverse colors)))
    luciano/omarchy-colors))

(defun luciano/omarchy-color (key &optional default)
  "Return Omarchy color KEY or DEFAULT."
  (or (cdr (assoc key luciano/omarchy-colors)) default))

(defun luciano/apply-omarchy-theme-faces (&rest _)
  "Restyle Doom faces to match the active Aether/Omarchy palette."
  (when (luciano/load-omarchy-colors)
    (let* ((bg      (luciano/omarchy-color "background" "#000001"))
           (fg      (luciano/omarchy-color "foreground" "#efefe4"))
           (bg-alt  (or (luciano/omarchy-color "lighter_background")
                        (luciano/omarchy-color "lighter_bg")
                        "#1a1a1a"))
           (fg-dim  (or (luciano/omarchy-color "dark_foreground")
                        (luciano/omarchy-color "muted")
                        "#5b5e64"))
           (accent  (luciano/omarchy-color "accent" "#a0bcff"))
           (blue    (luciano/omarchy-color "blue" accent))
           (cyan    (luciano/omarchy-color "cyan" "#72dfe1"))
           (green   (luciano/omarchy-color "green" "#d4ca7c"))
           (yellow  (luciano/omarchy-color "yellow" "#f4ca84"))
           (red     (luciano/omarchy-color "red" "#fc9e8d"))
           (magenta (luciano/omarchy-color "magenta" "#eba8d9"))
           (orange  (luciano/omarchy-color "orange" "#fcad9e"))
           (region  (or (luciano/omarchy-color "selection") bg-alt)))
      (custom-set-faces!
       `(default :background ,bg :foreground ,fg)
       `(fringe :background ,bg)
       `(solaire-default-face :background ,bg-alt)
       `(hl-line :background ,bg-alt)
       `(region :background ,region :foreground ,fg)
       `(cursor :background ,accent)
       `(font-lock-comment-face :foreground ,fg-dim)
       `(font-lock-keyword-face :foreground ,blue)
       `(font-lock-function-name-face :foreground ,cyan)
       `(font-lock-string-face :foreground ,green)
       `(font-lock-constant-face :foreground ,orange)
       `(font-lock-variable-name-face :foreground ,fg)
       `(font-lock-type-face :foreground ,yellow)
       `(font-lock-builtin-face :foreground ,magenta)
       `(mode-line :background ,bg-alt :foreground ,fg)
       `(mode-line-inactive :background ,bg :foreground ,fg-dim)
       `(header-line :background ,bg-alt :foreground ,fg)
       `(vertical-border :foreground ,bg-alt)
       `(+workspace-tab-selected-face :background ,accent :foreground ,bg :weight bold)
       `(+workspace-tab-face :background ,bg-alt :foreground ,fg-dim)
       `(line-number :foreground ,fg-dim)
       `(line-number-current-line :foreground ,accent :weight bold)
       `(org-level-1 :foreground ,blue :weight bold)
       `(org-level-2 :foreground ,cyan)
       `(org-level-3 :foreground ,magenta)
       `(link :foreground ,blue :underline t)
       `(highlight :background ,bg-alt :foreground ,accent)
       `(doom-modeline-buffer-file :foreground ,fg :weight bold)
       `(doom-modeline-project-dir :foreground ,blue))
      (message "Doom faces synced to Omarchy/Aether (%s)" bg))))

;; Prefer Aether palette over stock doom-one colors.
(setq doom-theme 'doom-one)
(add-hook 'doom-load-theme-hook #'luciano/apply-omarchy-theme-faces)
(add-hook 'doom-after-init-hook #'luciano/apply-omarchy-theme-faces)
