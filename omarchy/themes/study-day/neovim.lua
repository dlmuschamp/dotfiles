-- Omarchy's native entry point, including its plugins/theme.lua symlink.
local source = debug.getinfo(1, "S").source:sub(2)
local path = (vim.uv or vim.loop).fs_realpath(source) or source
return dofile(vim.fn.fnamemodify(path, ":h") .. "/nvim.lua")
