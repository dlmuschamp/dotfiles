#set page(paper: "us-letter", margin: 0.65in, numbering: "1")
#set text(font: "New Computer Modern", size: 10pt)
#set par(spacing: 0.5em)
#set heading(numbering: none)
#show heading: set block(above: 1em, below: 0.5em)
#show raw: set text(font: "DejaVu Sans Mono", size: 8pt)
#let horizontalRule = line(length: 100%)
#let divider() = horizontalRule
$for(header-includes)$
$header-includes$
$endfor$
$if(title)$#text(size: 16pt, weight: "bold")[$title$]$endif$
$if(author)$$for(author)$$author$$sep$ / $endfor$$endif$
$if(date)$$date$$endif$
$if(instructor)$Instructor: $instructor$ \$endif$
$if(course)$Course: $course$ \$endif$
$body$
