#set page(paper: "us-letter", margin: 0.85in, numbering: "1")
#set text(font: "New Computer Modern", size: 11pt)
#set par(justify: true, spacing: 0.7em)
#set heading(numbering: "1.1")
#show raw: set text(font: "DejaVu Sans Mono", size: 9pt)
#let horizontalRule = line(length: 100%)
#let divider() = horizontalRule
$for(header-includes)$
$header-includes$
$endfor$
$if(title)$
#align(center)[#text(size: 20pt, weight: "bold")[$title$]]
$endif$
$if(author)$
#align(center)[$for(author)$$author$$sep$ / $endfor$]
$endif$
$if(date)$
#align(center)[$date$]
$endif$
$if(instructor)$Instructor: $instructor$ \$endif$
$if(course)$Course: $course$ \$endif$
$if(toc)$#outline()$endif$
$body$
