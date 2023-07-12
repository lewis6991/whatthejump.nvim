local api, uv = vim.api, vim.loop

--- @class Jump
--- @field bufnr integer
--- @field col integer
--- @field coladd integer
--- @field lnum integer
--- @field filename? string

local ns = api.nvim_create_namespace('whatthejump')

local gwin --- @type integer?

-- Autocmd ID for cursor moved
local cmoved_au ---@type integer?

local function close_win()
  if not gwin then
    return
  end
  api.nvim_win_close(gwin, true)
  gwin = nil
end

local function enable_cmoved_au()
  cmoved_au = api.nvim_create_autocmd({'CursorMoved', 'CursorMovedI'}, {
    once = true,
    callback = function()
      close_win()
      cmoved_au = nil
    end
  })
end

local function disable_cmoved_au()
  if cmoved_au then
    api.nvim_del_autocmd(cmoved_au)
    cmoved_au = nil
  end
end

--- @param height integer
--- @param width integer
--- @return integer
local function refresh_win(height, width)
  if gwin then
    api.nvim_win_set_config(gwin, {
      width = width,
      height = height,
    })
    return gwin
  end

  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].undolevels = -1
  vim.bo[buf].bufhidden = 'wipe'

  gwin = api.nvim_open_win(buf, false, {
    relative = 'win',
    anchor = 'ne',
    col = api.nvim_win_get_width(0),
    row = 0,
    zindex = 200,
    width = width,
    height = height,
    style = 'minimal',
  })
  vim.wo[gwin].winblend = 15

  return gwin
end

local WIN_TIMEOUT = 2000

local win_timer --- @type uv_timer_t?

local function refresh_win_timer()
  if not win_timer then
    win_timer = assert(uv.new_timer())
  end

  win_timer:start(WIN_TIMEOUT, 0, function()
    win_timer:close()
    win_timer = nil
    vim.schedule(close_win)
  end)
end

---@param buf integer
---@param lines string[]
---@param current_line integer
local function render_buf(buf, lines, current_line)
  if api.nvim_buf_line_count(buf) < #lines then
    local blank = {} ---@type string[]
    for i = 1, #lines do
      blank[i] = ''
    end

    api.nvim_buf_set_lines(buf, 0, -1, false, blank)
  end

  api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for i, l in ipairs(lines) do
    api.nvim_buf_set_extmark(buf, ns, i-1, 0, {
      virt_text = l,
      hl_mode = 'combine',
      line_hl_group = i == current_line and 'Visual' or nil,
    })
  end
end

--- @param x Jump
--- @return {[1]: string, [2]: string?}[]
local function jump_to_virttext(x)
  local name --- @type {[1]: string, [2]: string?}
  if x.filename then
    name = { x.filename, 'Tag' }
  elseif api.nvim_buf_is_valid(x.bufnr) then
    name = { vim.fn.fnamemodify(api.nvim_buf_get_name(x.bufnr), ':~:.'), 'Tag' }
  else
    name = { 'invalid buf '..x.bufnr, 'ErrorMsg' }
  end

  local line --- @type {[1]: string, [2]: string?}?

  if api.nvim_buf_is_loaded(x.bufnr) then
    local text = api.nvim_buf_get_lines(x.bufnr, x.lnum - 1, x.lnum, false)[1]
    if text then
      text = '\t'..vim.trim(text)
      line = { text, 'SpecialKey' }
    end
  end

  return {
    name,
    { string.format(':%d:%d', x.lnum, x.col), 'Directory' },
    line
  }
end

--- @param x {[1]: string, [2]: string?}[]
--- @return integer
local function virt_text_len(x)
  local len = 0
  for _, v in ipairs(x) do
    len = len + #v[1]
  end
  return len
end

local CONTEXT_MAX = 8
local CONTEXT_BEFORE = 10
local CONTEXT_AFTER = 4

--- @param jumplist Jump[]
--- @param current integer
--- @return string[] lines
--- @return integer current_line
--- @return integer width
local function get_text(jumplist, current)
  local width = 0
  local lines = {} --- @type table[]
  local current_lnum --- @type integer

  -- Determine the longest required width from the full jumplist
  for _, j in ipairs(jumplist) do
    local len = virt_text_len(jump_to_virttext(j))
    if len > width then
      width = len
    end
  end

  for i = current - CONTEXT_AFTER, current + CONTEXT_BEFORE do
    local j = jumplist[i]
    if j then
      lines[#lines+1] = jump_to_virttext(j)
      if current == i then
        current_lnum = #lines
      end
      if #lines > CONTEXT_MAX then
        break
      end
    end
  end

  return lines, current_lnum, width
end

local M = {}

--- @param forward? boolean
function M.show_jumps(forward)
  disable_cmoved_au()

  --- @type Jump[], integer
  local jumplist, last_jump_pos = unpack(vim.fn.getjumplist())
  local target = last_jump_pos + 1 + (forward and 1 or -1)

  target = math.max(target, 1)
  target = math.min(target, #jumplist)

  local lines, current_line, width = get_text(jumplist, target)

  vim.schedule(function()
    local win = refresh_win(#lines, width+2)
    local buf = api.nvim_win_get_buf(win)
    render_buf(buf, lines, current_line)
    refresh_win_timer()
    enable_cmoved_au()
  end)
end

return M
