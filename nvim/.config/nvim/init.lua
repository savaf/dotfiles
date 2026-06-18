-- ============================================================================
-- Neovim configuration (minimal, portable across Ubuntu/WSL and macOS)
-- No plugin manager: works out of the box on any machine. Extend as needed.
-- ============================================================================

local opt = vim.opt
local g = vim.g

-- Leader keys (set before any mappings)
g.mapleader = " "
g.maplocalleader = " "

-- ---------------------------------------------------------------------------
-- General
-- ---------------------------------------------------------------------------
opt.number = true            -- show line numbers
opt.relativenumber = true    -- relative line numbers
opt.mouse = "a"              -- enable mouse in all modes
opt.clipboard = "unnamedplus" -- use the system clipboard
opt.undofile = true          -- persistent undo
opt.swapfile = false
opt.confirm = true           -- ask to save instead of failing
opt.updatetime = 250

-- ---------------------------------------------------------------------------
-- UI
-- ---------------------------------------------------------------------------
opt.termguicolors = true     -- true color support
opt.signcolumn = "yes"       -- always show sign column
opt.cursorline = true        -- highlight current line
opt.scrolloff = 8            -- keep lines of context around cursor
opt.wrap = false
opt.splitright = true
opt.splitbelow = true

-- ---------------------------------------------------------------------------
-- Indentation
-- ---------------------------------------------------------------------------
opt.expandtab = true         -- spaces instead of tabs
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2
opt.smartindent = true

-- ---------------------------------------------------------------------------
-- Search
-- ---------------------------------------------------------------------------
opt.ignorecase = true
opt.smartcase = true         -- case-sensitive if query has uppercase
opt.hlsearch = true
opt.incsearch = true

-- ---------------------------------------------------------------------------
-- Key mappings
-- ---------------------------------------------------------------------------
local map = vim.keymap.set

-- Clear search highlight
map("n", "<leader>h", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

-- Save / quit
map("n", "<leader>w", "<cmd>write<CR>", { desc = "Save file" })
map("n", "<leader>q", "<cmd>quit<CR>", { desc = "Quit" })

-- Better window navigation
map("n", "<C-h>", "<C-w>h", { desc = "Window left" })
map("n", "<C-j>", "<C-w>j", { desc = "Window down" })
map("n", "<C-k>", "<C-w>k", { desc = "Window up" })
map("n", "<C-l>", "<C-w>l", { desc = "Window right" })

-- Move selected lines up/down in visual mode
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- ---------------------------------------------------------------------------
-- Highlight on yank
-- ---------------------------------------------------------------------------
vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking text",
  callback = function()
    vim.highlight.on_yank()
  end,
})
