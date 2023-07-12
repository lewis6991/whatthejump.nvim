# whatthejump.nvim

Show jump locations in a floating window.

https://github.com/lewis6991/whatthejump.nvim/assets/7904185/13cb71f4-57e1-4f8f-916f-b6c616d36480

## Usage

If no keymaps already exist, ones we will be automatically created for `<C-i>` and `<C-o>`.
Otherwise, if you use custom keymaps for jumping then use the following:

```lua
-- Jump backwards
vim.keymap.set('n', '<M-k>', function()
  require 'whatthejump'.show_jumps(false)
  return '<C-o>'
end, {expr = true})

-- Jump forwards
vim.keymap.set('n', '<M-j>', function()
  require 'whatthejump'.show_jumps(true)
  return '<C-i>'
end, {expr = true})
```
