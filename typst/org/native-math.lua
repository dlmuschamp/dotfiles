-- Org math contains native Typst, not TeX. Bypass Pandoc's texmath conversion.
function Math(el)
  local content = el.text
  if el.mathtype == 'DisplayMath' then
    return pandoc.RawInline('typst', '$ ' .. content .. ' $')
  end
  return pandoc.RawInline('typst', '$' .. content .. '$')
end
