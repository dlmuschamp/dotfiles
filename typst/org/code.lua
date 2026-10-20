-- Emit code as data, never as executable Typst, and keep tabs/indentation.
local aliases = {
  ['c++'] = 'cpp', ['C++'] = 'cpp', C = 'c',
  js = 'javascript', ts = 'typescript', py = 'python',
  sh = 'bash', shell = 'bash', octave = 'matlab',
  ['emacs-lisp'] = 'lisp', commonlisp = 'lisp', typst = 'typ',
}

local function quote(text)
  local escapes = { ['\\'] = '\\\\', ['"'] = '\\"', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
  return '"' .. text:gsub('[\\"%c]', function(char)
    return escapes[char] or string.format('\\u{%x}', string.byte(char))
  end) .. '"'
end

-- Normalize before layout: Typst tab glyph widths can otherwise depend on the
-- surrounding paragraph/font. Count Unicode characters, not UTF-8 bytes.
local function expand_tabs(text)
  local result, column = {}, 0
  for _, codepoint in utf8.codes(text) do
    if codepoint == 9 then
      local width = 4 - column % 4
      result[#result + 1] = string.rep(' ', width)
      column = column + width
    else
      result[#result + 1] = utf8.char(codepoint)
      column = (codepoint == 10 or codepoint == 13) and 0 or column + 1
    end
  end
  return table.concat(result)
end

function CodeBlock(el)
  local language = el.classes[1] or el.attributes['org-language'] or ''
  language = aliases[language] or language:lower()
  local raw = '#raw(' .. quote(expand_tabs(el.text)) .. ', block: true, tab-size: 4'
  if language ~= '' then
    raw = raw .. ', lang: ' .. quote(language)
  end
  raw = raw .. ')'
  -- Keep named Org source listings available as link targets.
  if el.identifier ~= '' then
    raw = raw .. ' #label(' .. quote(el.identifier) .. ')'
  end
  return pandoc.RawBlock('typst', raw)
end
