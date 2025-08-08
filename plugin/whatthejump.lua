if vim.g.loaded_whatthejump then
  return
end

vim.g.loaded_whatthejump = true

if vim.fn.maparg('<C-o>') == '' then
  vim.keymap.set('n', '<C-o>', function()
    require('whatthejump').show_jumps(false)
    return '<C-o>'
  end, { expr = true, desc = 'show jumps' })
end

if vim.fn.maparg('<C-i>') == '' then
  vim.keymap.set('n', '<C-i>', function()
    require('whatthejump').show_jumps(true)
    return '<C-i>'
  end, { expr = true, desc = 'show jumps' })
end
