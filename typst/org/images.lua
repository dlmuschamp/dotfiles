-- Keep ordinary Org images within the text area, without changing templates.
-- Ask Pandoc to serialize image paths, alt text, and explicit dimensions safely.
local function render_image(el)
  local native = pandoc.write(pandoc.Pandoc({pandoc.Plain({el})}), 'typst')
  -- Leave space for captions/prose and never enlarge small originals. Freeze
  -- the measured box before scaling so automatic image sizing cannot undo it.
  return '#layout(size => {\n'
    .. '  let body = [' .. native .. ']\n'
    .. '  let natural = measure(body, width: size.width)\n'
    .. '  let factor = calc.min(1, size.width / natural.width, '
    .. '5.5in / natural.width, 6.5in / natural.height, '
    .. 'size.height * 0.8 / natural.height)\n'
    .. '  scale(x: factor * 100%, y: factor * 100%, reflow: true, '
    .. 'box(width: natural.width, height: natural.height, body))\n'
    .. '})'
end

local function standalone(el)
  if #el.content == 1 and el.content[1].t == 'Image' then
    return pandoc.RawBlock('typst', '#align(center)[' .. render_image(el.content[1]) .. ']')
  end
end

-- Process standalone images before the inline pass. Plain covers captioned
-- figures, leaving Pandoc responsible for captions, numbering, and labels.
return {
  {Para = standalone, Plain = standalone},
  {Image = function(el) return pandoc.RawInline('typst', render_image(el)) end},
}
