// Metadata is escaped Pandoc content, never interpolated into code strings.
#set text(font: "Liberation Serif", size: 12pt, hyphenate: false,
  // Typst measures bottom edges upward: negative 0.2em is below baseline.
  top-edge: 0.8em, bottom-edge: -0.2em)
#set page(paper: "us-letter", margin: 1in,
  header: align(right)[$if(surname)$$surname$$else$Muschamp$endif$ #context counter(page).display("1")],
  // Header content is bottom-aligned, so reserve its 12pt line height.
  header-ascent: 0.5in - 1em)
#set par(justify: false, leading: 1em, spacing: 1em,
  first-line-indent: (amount: 0.5in, all: true))
#set heading(numbering: none)
#show heading: set par(first-line-indent: 0pt)
#show raw: set text(font: "DejaVu Sans Mono", size: 10pt)
#let horizontalRule = line(length: 100%)
#let divider() = horizontalRule
// Entries are manually supplied paragraphs, not an automatic citation style.
#let works-cited(body) = {
  pagebreak()
  set par(first-line-indent: 0pt)
  align(center)[Works Cited]
  set par(hanging-indent: 0.5in)
  body
}
$for(header-includes)$
$header-includes$
$endfor$
#block[
#set par(first-line-indent: 0pt)
$if(author)$$for(author)$$author$$sep$ / $endfor$ \$endif$
$if(instructor)$$instructor$ \$endif$
$if(course)$$course$ \$endif$
$if(date)$$date$$endif$
]
$if(title)$
#align(center)[#set par(first-line-indent: 0pt)
$title$]
$endif$
$body$
