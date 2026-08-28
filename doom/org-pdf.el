;;; org-pdf.el -*- lexical-binding: t; -*-
;;
;; Clean, minimal, technical PDF export for Org.
;;
;; Two document classes are provided:
;;
;;   spec   — sans-serif, unindented paragraphs with vertical spacing, ruled
;;            section headings, running header/footer. Datasheet / technical
;;            write-up feel. This is the default.
;;   essay  — serif body, indented paragraphs, wider leading. Long-form prose.
;;
;; Select per file with:  #+LATEX_CLASS: essay
;;
;; Export with  SPC m e l o  (org-export → LaTeX → PDF and open).

;;; ---------------------------------------------------------------------------
;;; Engine

(after! ox-latex
  ;; XeLaTeX so we can use system OpenType fonts (IBM Plex) via fontspec.
  (setq org-latex-compiler "xelatex"
        org-latex-pdf-process
        '("latexmk -f -pdfxe -interaction=nonstopmode -output-directory=%o %f")
        ;; latexmk already reruns as needed; don't let Org delete the log we
        ;; need when a build fails.
        org-latex-remove-logfiles t
        org-latex-logfiles-extensions
        '("aux" "bcf" "fdb_latexmk" "fls" "figlist" "idx" "nav" "out" "ptc"
          "run.xml" "snm" "toc" "vrb" "xdv"))

  ;; booktabs rules instead of \hline; looks far cleaner in print.
  (setq org-latex-tables-booktabs t
        org-latex-tables-centered t
        org-latex-caption-above '(table)
        org-latex-prefer-user-labels t
        org-latex-src-block-backend 'listings
        org-latex-image-default-width "\\linewidth"
        org-latex-default-class "spec"
        ;; Emit #+SUBTITLE as its own \subtitle command. Org's default folds it
        ;; into \title, which would drag it into the running header too.
        org-latex-subtitle-separate t
        org-latex-subtitle-format "\\subtitle{%s}")

  ;; Default export switches: numbered sections, no TOC unless asked, no
  ;; "Created with Emacs" footer.
  (setq org-export-with-toc nil
        org-export-with-section-numbers t
        org-export-with-smart-quotes t
        org-export-with-sub-superscripts '{}
        org-export-preserve-breaks nil
        org-export-with-author t
        org-export-with-date t
        org-export-time-stamp-file nil)

;;; -------------------------------------------------------------------------
;;; Shared preamble

  (defvar luciano/latex-preamble-common
    (concat
     "[NO-DEFAULT-PACKAGES]\n"
     "[NO-PACKAGES]\n"
     "\\usepackage{fontspec}\n"
     "\\usepackage{geometry}\n"
     "\\usepackage{microtype}\n"
     "\\usepackage[table]{xcolor}\n"
     "\\usepackage{etoolbox}\n"
     "\\usepackage{titlesec}\n"
     "\\usepackage{fancyhdr}\n"
     "\\usepackage{lastpage}\n"
     "\\usepackage{booktabs}\n"
     "\\usepackage{longtable}\n"
     "\\usepackage{tabularx}\n"
     "\\usepackage{array}\n"
     "\\usepackage{graphicx}\n"
     "\\usepackage{wrapfig}\n"
     "\\usepackage{rotating}\n"
     "\\usepackage{caption}\n"
     "\\usepackage{enumitem}\n"
     "\\usepackage{listings}\n"
     "\\usepackage{amsmath}\n"
     "\\usepackage{amssymb}\n"
     "\\usepackage{textcomp}\n"
     "\\usepackage[normalem]{ulem}\n"
     "\\usepackage{needspace}\n"
     "\\usepackage{hyperref}\n"
     "\n"
     ;; -- palette: restrained, print-safe -------------------------------
     "\\definecolor{accent}{HTML}{15497B}\n"
     "\\definecolor{ink}{HTML}{16191D}\n"
     "\\definecolor{muted}{HTML}{5B6570}\n"
     "\\definecolor{rulegray}{HTML}{C8CDD3}\n"
     "\\definecolor{codebg}{HTML}{F7F8F9}\n"
     "\\definecolor{strgreen}{HTML}{1F6F4A}\n"
     "\n"
     ;; -- fonts ---------------------------------------------------------
     ;; Loaded by filename rather than family name: fontconfig on Arch
     ;; abbreviates the style names ("SmBld"), which fontspec cannot resolve.
     ;; The "Text" cut is Plex's body-copy weight — slightly heavier than
     ;; Regular and noticeably steadier on paper.
     "\\defaultfontfeatures{Path=/usr/share/fonts/TTF/, Extension=.ttf}\n"
     "\\setsansfont{IBMPlexSans-}[\n"
     "  UprightFont=*Text, ItalicFont=*TextItalic,\n"
     "  BoldFont=*SemiBold, BoldItalicFont=*SemiBoldItalic]\n"
     "\\setmonofont{IBMPlexMono-}[Scale=MatchLowercase,\n"
     "  UprightFont=*Regular, ItalicFont=*Italic,\n"
     "  BoldFont=*Bold, BoldItalicFont=*BoldItalic]\n"
     "\\newfontfamily\\headingfont{IBMPlexSans-}[\n"
     "  UprightFont=*SemiBold, ItalicFont=*SemiBoldItalic,\n"
     "  BoldFont=*Bold, BoldItalicFont=*BoldItalic]\n"
     "\n"
     "\\color{ink}\n"
     "\n"
     ;; -- links ---------------------------------------------------------
     "\\hypersetup{colorlinks=true, linkcolor=accent, urlcolor=accent,\n"
     "  citecolor=accent, breaklinks=true}\n"
     "\\urlstyle{same}\n"
     "\n"
     ;; -- running header / footer --------------------------------------
     "\\makeatletter\n"
     "\\pagestyle{fancy}\n"
     "\\fancyhf{}\n"
     "\\fancyhead[L]{\\sffamily\\fontsize{8}{10}\\selectfont\\color{muted}\\@title}\n"
     "\\fancyhead[R]{\\sffamily\\fontsize{8}{10}\\selectfont\\color{muted}\\@date}\n"
     "\\fancyfoot[R]{\\sffamily\\fontsize{8}{10}\\selectfont\\color{muted}%\n"
     "  \\thepage\\,/\\,\\pageref{LastPage}}\n"
     "\\renewcommand{\\headrule}{\\color{rulegray}\\hrule height 0.4pt}\n"
     "\\renewcommand{\\footrulewidth}{0pt}\n"
     "\\fancypagestyle{plain}{\\fancyhf{}%\n"
     "  \\fancyfoot[R]{\\sffamily\\fontsize{8}{10}\\selectfont\\color{muted}%\n"
     "    \\thepage\\,/\\,\\pageref{LastPage}}%\n"
     "  \\renewcommand{\\headrulewidth}{0pt}}\n"
     "\\makeatother\n"
     "\n"
     ;; -- title block: rule, title, subtitle, author/date, hairline -----
     "\\makeatletter\n"
     "\\newcommand{\\@subtitle}{}\n"
     "\\newcommand{\\subtitle}[1]{\\renewcommand{\\@subtitle}{#1}}\n"
     "\\renewcommand{\\maketitle}{%\n"
     "  \\begingroup\n"
     "  \\setlength{\\parindent}{0pt}\n"
     "  {\\color{accent}\\rule{\\textwidth}{1.2pt}}\\par\\vspace{7pt}\n"
     "  {\\headingfont\\fontsize{21}{25}\\selectfont\\color{ink}\\@title\\par}\n"
     "  \\ifdefempty{\\@subtitle}{}{%\n"
     "    \\vspace{4pt}{\\sffamily\\fontsize{11.5}{15}\\selectfont\\color{muted}\\@subtitle\\par}}\n"
     "  \\vspace{9pt}\n"
     "  {\\sffamily\\fontsize{8.5}{11}\\selectfont\\color{muted}%\n"
     "    \\@author\\hfill\\@date\\par}\n"
     "  \\vspace{5pt}\n"
     "  {\\color{rulegray}\\rule{\\textwidth}{0.4pt}}\\par\n"
     "  \\vspace{20pt}\n"
     "  \\endgroup\n"
     "  \\thispagestyle{fancy}}\n"
     "\\makeatother\n"
     "\n"
     ;; -- headings ------------------------------------------------------
     "\\titleformat{\\section}\n"
     "  {\\headingfont\\fontsize{13.5}{17}\\selectfont\\color{accent}}\n"
     "  {\\thesection}{0.8em}{}\n"
     "  [\\vspace{2pt}{\\color{rulegray}\\titlerule[0.4pt]}]\n"
     "\\titlespacing*{\\section}{0pt}{20pt plus 4pt minus 2pt}{9pt}\n"
     "\\titleformat{\\subsection}\n"
     "  {\\headingfont\\fontsize{11}{14}\\selectfont\\color{ink}}\n"
     "  {\\thesubsection}{0.7em}{}\n"
     "\\titlespacing*{\\subsection}{0pt}{14pt plus 3pt minus 2pt}{5pt}\n"
     "\\titleformat{\\subsubsection}\n"
     "  {\\headingfont\\fontsize{9.8}{13}\\selectfont\\color{muted}}\n"
     "  {\\thesubsubsection}{0.6em}{}\n"
     "\\titlespacing*{\\subsubsection}{0pt}{12pt plus 2pt}{4pt}\n"
     "\\titleformat{\\paragraph}[runin]\n"
     "  {\\headingfont\\normalsize\\color{ink}}{}{0pt}{}[.\\hspace{0.5em}]\n"
     ;; Never leave a heading stranded at the foot of a page.
     "\\pretocmd{\\section}{\\Needspace{4\\baselineskip}}{}{}\n"
     "\\pretocmd{\\subsection}{\\Needspace{3\\baselineskip}}{}{}\n"
     "\n"
     ;; -- lists, captions, tables ---------------------------------------
     "\\setlist[itemize]{leftmargin=1.3em, itemsep=2pt, parsep=0pt, topsep=5pt}\n"
     "\\setlist[enumerate]{leftmargin=1.5em, itemsep=2pt, parsep=0pt, topsep=5pt}\n"
     "\\setlist[description]{leftmargin=0pt, itemsep=3pt, topsep=6pt,\n"
     "  font=\\headingfont\\color{ink}}\n"
     "\\captionsetup{font={sf,small}, labelfont={sf,bf},\n"
     "  labelsep=period, justification=raggedright, singlelinecheck=false,\n"
     "  skip=6pt}\n"
     "\\renewcommand{\\arraystretch}{1.25}\n"
     "\\setlength{\\tabcolsep}{8pt}\n"
     "\\setlength{\\heavyrulewidth}{0.8pt}\n"
     "\\setlength{\\lightrulewidth}{0.4pt}\n"
     "\\arrayrulecolor{rulegray}\n"
     "\n"
     ;; -- block quote: hairline in the left margin ----------------------
     "\\renewenvironment{quote}\n"
     "  {\\par\\vspace{8pt}\\begingroup\\color{muted}%\n"
     "   \\setlength{\\leftskip}{1.2em}\\rightskip=1.2em\\small}\n"
     "  {\\par\\endgroup\\vspace{8pt}}\n"
     "\n"
     ;; -- source blocks -------------------------------------------------
     "\\lstset{%\n"
     "  basicstyle=\\ttfamily\\fontsize{8.5}{11}\\selectfont\\color{ink},\n"
     "  backgroundcolor=\\color{codebg},\n"
     "  frame=single, framerule=0.4pt, rulecolor=\\color{rulegray},\n"
     "  framesep=7pt, xleftmargin=9pt, xrightmargin=0pt,\n"
     "  numbers=left, numberstyle=\\ttfamily\\tiny\\color{muted}, numbersep=9pt,\n"
     "  keywordstyle=\\color{accent}, commentstyle=\\color{muted}\\itshape,\n"
     "  stringstyle=\\color{strgreen},\n"
     "  showstringspaces=false, breaklines=true, breakatwhitespace=true,\n"
     "  breakindent=1.5em, columns=fullflexible, keepspaces=true, upquote=true,\n"
     "  aboveskip=12pt, belowskip=12pt, tabsize=2,\n"
     "  captionpos=b}\n"
     "\\renewcommand{\\lstlistingname}{Listing}\n")
    "Preamble shared by every clean export class.")

;;; -------------------------------------------------------------------------
;;; Classes

  (defvar luciano/latex-class-spec
    (concat
     ;; 10pt sans reads about the same size as 11pt serif; the sans face has a
     ;; larger x-height, so it does not need the extra point.
     "\\documentclass[10pt]{article}\n"
     luciano/latex-preamble-common
     "\\geometry{letterpaper, top=1in, bottom=1in, left=1.05in, right=1.05in,\n"
     "  headheight=14pt, headsep=16pt, footskip=26pt}\n"
     ;; Technical documents read better unindented with air between blocks.
     "\\setlength{\\parindent}{0pt}\n"
     "\\setlength{\\parskip}{0.62em}\n"
     "\\renewcommand{\\baselinestretch}{1.12}\n"
     "\\renewcommand{\\familydefault}{\\sfdefault}\n")
    "Sans-serif technical write-up / datasheet class.")

  (defvar luciano/latex-class-essay
    (concat
     "\\documentclass[11pt]{article}\n"
     luciano/latex-preamble-common
     "\\setmainfont{IBMPlexSerif-}[\n"
     "  UprightFont=*Text, ItalicFont=*TextItalic,\n"
     "  BoldFont=*SemiBold, BoldItalicFont=*SemiBoldItalic]\n"
     ;; Narrower measure — ~68 characters per line for comfortable reading.
     "\\geometry{letterpaper, top=1.1in, bottom=1.1in, left=1.4in, right=1.4in,\n"
     "  headheight=14pt, headsep=16pt, footskip=26pt}\n"
     "\\setlength{\\parindent}{1.4em}\n"
     "\\setlength{\\parskip}{0pt}\n"
     "\\renewcommand{\\baselinestretch}{1.22}\n"
     "\\renewcommand{\\familydefault}{\\rmdefault}\n")
    "Serif long-form prose class.")

  (dolist (spec (list (cons "spec"  luciano/latex-class-spec)
                      (cons "essay" luciano/latex-class-essay)))
    (setf (alist-get (car spec) org-latex-classes nil nil #'equal)
          (list (cdr spec)
                '("\\section{%s}" . "\\section*{%s}")
                '("\\subsection{%s}" . "\\subsection*{%s}")
                '("\\subsubsection{%s}" . "\\subsubsection*{%s}")
                '("\\paragraph{%s}" . "\\paragraph*{%s}"))))

;;; -------------------------------------------------------------------------
;;; Language names for listings
;;; `listings' has no lexer for these, so map them onto the closest one it
;;; does know rather than emitting an unhighlighted block.

  (dolist (pair '((emacs-lisp "Lisp") (elisp "Lisp") (lisp "Lisp")
                  (sh "bash") (shell "bash") (bash "bash") (zsh "bash")
                  (json "Java") (jsonc "Java") (js "Java")
                  (javascript "Java") (typescript "Java")
                  (yaml "XML") (toml "XML") (conf "XML")
                  (nix "Haskell") (org "TeX")))
    (setf (alist-get (car pair) org-latex-listings-langs)
          (cdr pair))))

;;; ---------------------------------------------------------------------------
;;; Convenience command

(defun luciano/org-export-pdf-open ()
  "Export the current Org buffer to PDF and open it in the system viewer."
  (interactive)
  (let ((pdf (org-latex-export-to-pdf)))
    (when pdf
      (message "Exported %s" pdf)
      (browse-url-xdg-open (expand-file-name pdf)))))

(map! :after org
      :map org-mode-map
      :localleader
      :desc "Export PDF and open" "E" #'luciano/org-export-pdf-open)

(provide 'org-pdf)
;;; org-pdf.el ends here
