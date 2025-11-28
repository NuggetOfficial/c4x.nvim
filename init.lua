local M = {}

local session = {
  focus = nil,
  tabs = {},
  order = {}
}

local panel = {
  win = nil,
  buf = nil
}

local cfg = {}

local ensure_panel = function( opts )
  if panel.win and vim.api.nvim_win_is_valid(panel.win) then
    return panel
  end
  
  opts = opts or {}
  if opts.buf and vim.api.nvim_buf_is_valid(opts.buf) then
    panel.buf = opts.buf
  else
    panel.buf = vim.api.nvim_create_buf(false, true)
  end
  panel.win = vim.api.nvim_open_win(panel.buf, false, opts.window_config or
  {
    split = "right",
    win = 0,
    width = 80,
  })
  
  vim.api.nvim_buf_set_option(panel.buf, "filetype", "asm")
  vim.api.nvim_buf_set_option(panel.buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(panel.buf, "bufhidden", "wipe")
 
 
  return panel
end

local compile_to_asm = function(caller, opts)
  -- TODO add compiler layer that allows users to switch
  -- to clang or so, maybe also rust, needs to see which
  -- flags to use to get a good represenation of the used
  -- instructions
  opts = opts or {}
  
  local lines = table.concat(vim.api.nvim_buf_get_lines(caller, 0, -1, false),"\n");
  local gcc = {
    "gcc", opts.O or "-O3",
    string.format("-march=%s", opts.arch or "x86-64" ),
    string.format("-masm=%s" , opts.asm  or "intel"  ),
    string.format("-mtune=%s", opts.tune or "generic"),
    "-fno-asynchronous-unwind-tables",
    "-fzero-call-used-regs=skip",
    "-x", "c",
    "-S", "-", -- '-' maps to stdin
    "-o", "-"  -- '-' maps to stdout
  }
  
  local output = vim.system(gcc, {text = true, stdin = lines}):wait()
  if (output.stderr == "" or output.stderr == nil) then
    return output.stdout
  end

  return "cexpl: an error has occured\n" .. output.stderr
end

local filter_asm = function(asm, opts)
  opts = opts or {}
  local lines = vim.split(asm or "", "\n", {plain=true})

  local r = {}
  for _, line in ipairs(lines) do

    if (not line:match("^\t%.")) then
      if (line:match(":$") and not line:match("^%.")) then
        table.insert(r, "")
      end
      table.insert(r, line)
    end

  end
  return r
end

local emit_asm = function(caller, opts)
  opts = opts or {}
  local asm = compile_to_asm(caller, opts)
  local filtered = filter_asm(asm, opts)

  return filtered
end

local write_to_panel = function(start, stop, lines)
  vim.api.nvim_buf_set_option(panel.buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(panel.buf, start, stop, false, lines)
  vim.api.nvim_buf_set_option(panel.buf, "modifiable", false)
end

local update_tabs = function()

  local parts = {}
  for bufnr, tab in pairs(session.tabs) do
    if bufnr == session.focus then
      table.insert(parts, "[" .. tab.name .. "]")
    else
      table.insert(parts, " " .. tab.name .. " ")
    end
  end
  write_to_panel(0, 1, { table.concat(parts, " ") })

end

local update_current_tab = function()
  if session.focus then
    local asm = emit_asm(session.focus)
    write_to_panel(1, -1, asm)
  else
    write_to_panel(1, -1, {})
  end
end

local update_panel = function()
  if not panel.buf or not vim.api.nvim_buf_is_valid(panel.buf) then
    return
  end
  update_tabs()
  update_current_tab()
end

M.toggle_asm_panel = function()
  if panel.win and vim.api.nvim_win_is_valid(panel.win) then
    vim.api.nvim_win_close(panel.win, true)
    panel.win = nil
    return
  end

  ensure_panel({buf=panel.buf})
  update_panel()
  return
end


M.attach_buffer = function(bufnr, lang)
  if session.tabs[bufnr] then
    return
  end
  
  session.focus = bufnr
  session.tabs[bufnr] = {
    lang = lang,
    name = vim.fn.fnamemodify(
      vim.api.nvim_buf_get_name(bufnr),":t"
    )
  }
  table.insert(session.order, bufnr)
  
  vim.api.nvim_create_autocmd({"TextChanged", "InsertLeave"}, {
    buffer = bufnr,
    callback = function()
      session.focus = bufnr
      update_panel()
    end
  })
  -- Auto cleanup when C buffer is wiped
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = bufnr,
    callback = function()
      session[bufnr] = nil
    end,
  })
      
  end

M.remove_focus_buffer = function()
  local buf = session.focus

  session.tabs[buf] = nil
  for i, b in ipairs(session.order) do
    if b == buf then
      table.remove(session.order, i)
      break
    end
  end
  session.focus = session.order[#session.order]
  update_panel()
end

M.untrack_current_buffer = function()

  local buf = vim.api.nvim_get_current_buf()

  if session.tabs[buf] then
    session.tabs[buf] = nil
    for i, b in ipairs(session.order) do
      if b == buf then
        table.remove(session.order, i)
        break
      end
    end
  end
  update_panel()
end

M.track_current_buffer = function()

  local buf = vim.api.nvim_get_current_buf()

  if not session.tabs[buf] then
    M.attach_buffer(buf, "c")
    session.focus = buf
  end
  update_panel()
end

M.toggle_track_current_buffer = function()
  
  local buf = vim.api.nvim_get_current_buf()

  if not session.tabs[buf] then
    M.attach_buffer(buf, "c")
    session.focus = buf
  else
    session.tabs[buf] = nil
    for i, b in ipairs(session.order) do
      if b == buf then
        table.remove(session.order, i)
        session.focus = session.order[i]
        break
      end
    end
  end
  update_panel()
end

M.panel_go_left = function()
  for i, b in ipairs(session.order) do
    if b == session.focus then
      session.focus = session.order[i-1] or session.order[i]
      update_panel()
      break
    end
  end
end

M.panel_go_right = function()
  for i, b in ipairs(session.order) do
    if b == session.focus then
      session.focus = session.order[i+1] or session.order[i]
      update_panel()
      break
    end
  end
end




M.setup = function(opts) 
  opts = opts or {}

  vim.keymap.set("n","<leader>as", M.toggle_asm_panel, {desc="toggle live asm panel"})
  vim.keymap.set("n","<leader>aw", M.toggle_track_current_buffer,
    {desc="track/untrack current buffer"})
  vim.keymap.set("n","<leader>ad", M.remove_focus_buffer,
    {desc="stop tracking current focus"})

  vim.keymap.set("n","<leader>ah", M.panel_go_left)
  vim.keymap.set("n","<leader>al", M.panel_go_right)

  cfg.open_on_enter  = opts.open_on_enter  or true
  cfg.track_on_enter = opts.track_on_enter or true
end


vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "*.c",
  callback = function(ev)

    if cfg.open_on_enter then
      ensure_panel()
    end

    if cfg.track_on_enter and not session.tabs[ev.buf] then
      M.attach_buffer(ev.buf, "c")
    end

    if session.tabs[ev.buf] then
      session.focus = ev.buf
      update_panel()
    end  

    return
  end
})

return M
