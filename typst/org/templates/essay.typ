// Pandoc Typst template. Metadata is emitted as escaped content, not code strings.
#set page(paper: "us-letter", margin: 1in,
  header: align(right)[Muschamp #context counter(page).display("1")],
  header-ascent: 0.5in)
#set text(font: "New Computer Modern", size: 12pt)
#set par(leading: 0.55em, spacing: 0.55em, first-line-indent: 1.8em, justify: true)
#set heading(numbering: none)
#show heading: set block(above: 1.4em, below: 1em)
#show raw: set text(font: "DejaVu Sans Mono", size: 9pt)
#let horizontalRule = line(length: 100%)
#let divider() = horizontalRule
$for(header-includes)$
$header-includes$
$endfor$
#align(left)[
$if(author)$
$for(author)$$author$$sep$ / $endfor$ \
$else$
Damian Luciano Muschamp \
$endif$
$if(instructor)$$instructor$ \$endif$
$if(course)$$course$ \$endif$
$if(date)$$date$$endif$
]
$if(title)$
#align(center)[#text(weight: "bold")[$title$]]
$endif$
$body$
