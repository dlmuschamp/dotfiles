#set page(paper: "us-letter", margin: 1in, numbering: "1")
#set text(font: "New Computer Modern", size: 11pt)
#set par(justify: false, leading: 0.7em, spacing: 0.8em)
#set heading(numbering: "1.1")
#set math.equation(numbering: "(1)")
#show math.equation.where(block: true): set block(above: 1.2em, below: 1.2em)
#show raw: set text(font: "DejaVu Sans Mono", size: 9pt)
#let horizontalRule = line(length: 100%)
#let divider() = horizontalRule
$for(header-includes)$
$header-includes$
$endfor$
$if(title)$#align(center)[#text(size: 18pt, weight: "bold")[$title$]]$endif$
$if(author)$#align(center)[$for(author)$$author$$sep$ / $endfor$]$endif$
$if(instructor)$Instructor: $instructor$ \$endif$
$if(course)$Course: $course$ \$endif$
$if(date)$$date$$endif$
$if(toc)$#outline()$endif$
$body$
