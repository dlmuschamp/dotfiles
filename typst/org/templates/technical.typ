#set page(paper: "us-letter", margin: 1in, numbering: "1")
#set text(font: "New Computer Modern", size: 11pt)
#set par(justify: false, leading: 0.65em, spacing: 0.8em)
#set heading(numbering: "1.1")
#show raw: set text(font: "DejaVu Sans Mono", size: 9pt)
#show raw.where(block: true): it => block(width: 100%, inset: 10pt,
  fill: luma(96%), radius: 3pt, breakable: true, it)
#set table(inset: 6pt, stroke: 0.5pt + luma(65%))
#let horizontalRule = line(length: 100%)
#let divider() = horizontalRule
$for(header-includes)$
$header-includes$
$endfor$
$if(title)$#align(center)[#text(size: 20pt, weight: "bold")[$title$]]$endif$
$if(author)$#align(center)[$for(author)$$author$$sep$ / $endfor$]$endif$
$if(instructor)$Instructor: $instructor$ \$endif$
$if(course)$Course: $course$ \$endif$
$if(date)$$date$$endif$
$if(toc)$#outline()$endif$
$body$
