-- four terminals

-- these events go to only the focused coroutine
local to_focused = {
  mouse_click = true,
  mouse_drag = true,
  mouse_scroll = true,
  mouse_up = true,
  key = true,
  key_up = true,
  char = true,
  terminated = true
}

local w, h = term.getSize()

local ww, wh = math.floor(w / 2), math.floor(h / 2)

local windows = {
  window.create(term.current(), 1, 1, ww, wh, true),
  window.create(term.current(), 1, wh+2, ww, wh, true),
  window.create(term.current(), ww+2, 1, ww, wh, true),
  window.create(term.current(), ww+2, wh+2, ww, wh, true),
}

local function on_resize()
  term.setBackgroundColor(colors.gray)
  term.clear()
  term.setBackgroundColor(colors.black)
  for i=1, #windows, 1 do
    windows[i].setVisible(false)
    windows[i].setVisible(true)
  end
end

on_resize()
for i=1, #windows, 1 do
  windows[i].clear()
end

local coro_func = function()
  loadfile("/rom/programs/shell.lua")()
end

local coros = {
  coroutine.create(coro_func),
  coroutine.create(coro_func),
  coroutine.create(coro_func),
  coroutine.create(coro_func),
}

local focused = 1

local exited = 0
local function drawWindow(i, sig)
  local window = windows[i]
  term.redirect(window.redirectTarget or window)
  if i == focused or not to_focused[sig[1]] then
    local ok, err = coroutine.resume(coros[i], table.unpack(sig))
    if not ok then
      exited = exited + 1
      printError(err)
      coros[i] = coroutine.create(function()while true do coroutine.yield() end end)
    end
    window.redirectTarget = term.current()
  end
  window.restoreCursor()
end
local function draw(sig)
  local old = term.current()
  for i, window in ipairs(windows) do
    if i ~= focused then
      drawWindow(i, sig)
    end
  end
  drawWindow(focused, sig)
  term.redirect(old)
end

os.queueEvent("dummy")
while exited < 4 do
  local sig = table.pack(os.pullEventRaw())
  if sig[1] == "mouse_click" then
    local x, y = sig[3], sig[4]
    if x <= ww and y <= wh then
      focused = 1
    elseif y <= wh then
      focused = 3
    elseif x <= ww then
      focused = 2
    else
      focused = 4
    end
  end
  if sig[1]:match("mouse") then
    local x, y = sig[3], sig[4]
    local wx, wy = windows[focused].getPosition()
    sig[3] = x - wx + 1
    sig[4] = y - wy + 1
  elseif sig[1] == "term_resize" then
    local w, h = term.getSize()
    ww, wh = math.floor(w / 2), math.floor(h / 2)
    for i, window in ipairs(windows) do
      if i == 2 then
        window.reposition(ww+2, 1, ww, wh)
      elseif i == 4 then
        window.reposition(ww+2, wh+2, ww, wh)
      elseif i == 1 then
        window.reposition(1, 1, ww, wh)
      elseif i == 3 then
        window.reposition(1, wh+2, ww, wh)
      end
    end
    on_resize()
  end
  draw(sig)
end

sleep(2)
term.clear()
