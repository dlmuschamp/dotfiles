// MLA Page Set Up
#set page(
  margin: 1in,
  header: align(right)[
    Muschamp #context counter(page).display("1")
  ],
  header-ascent: 0.5in,
)

// LaTeX Inspired Style
#set text(font: "New Computer Modern", size: 12pt)
#set par(leading: 0.55em, spacing: 0.55em, first-line-indent: 1.8em, justify: true)
#show raw: set text(font: "New Computer Modern")
#show math.equation: set text(weight: "regular")
#show heading: set block(above: 1.4em, below: 1em)

// Title and Info
#align(left)[
  Damian Luciano Muschamp \
  [Instructor Name] \
  [Course Name] \
  #datetime.today().display("[day] [month repr:long] [year]")
]

#align(center)[
  #heading(level: 1, outlined: false)[{{TITLE}}]
]

// Begin writing below this line

