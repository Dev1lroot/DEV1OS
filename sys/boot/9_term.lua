local component = require("component")
local computer = require("computer")
local event = require("event")
local tty = require("tty")

event.listen("gpu_bound", function(_, gpu)
  gpu = component.proxy(gpu)
  tty.bind(gpu)
  computer.pushSignal("term_available")
end)

local function components_changed(ename, address, type)
  local window = tty.window
  if not window then
    return
  end

  if ename == "component_available" or ename == "component_unavailable" then
    type = address
  end

  if ename == "component_removed" or ename == "component_unavailable" then
    if type == "gpu" and window.gpu.address == address then
      window.gpu = nil
      window.keyboard = nil
    elseif type == "keyboard" then
      window.keyboard = nil
    end
    if (type == "screen" or type == "gpu") and not tty.isAvailable() then
      computer.pushSignal("term_unavailable")
    end
  elseif (ename == "component_added" or ename == "component_available") and type == "keyboard" then
    window.keyboard = nil
  end
end

event.listen("component_removed",     components_changed)
event.listen("component_added",       components_changed)
event.listen("component_available",   components_changed)
event.listen("component_unavailable", components_changed)

