local component = require("component")
local computer = require("computer")
local event = require("event")

local adding = {}
local primaries = {}
-------------------------------------------------------------------------------
setmetatable(component, {
  __index = function(_, key)
    return component.getPrimary(key)
  end,
  __pairs = function(self)
    local parent = false
    return function(_, key)
      if parent then
        return next(primaries, key)
      else
        local k, v = next(self, key)
        if not k then
          parent = true
          return next(primaries)
        else
          return k, v
        end
      end
    end
  end
})

function component.get(address, componentType)
  checkArg(1, address, "string")
  checkArg(2, componentType, "string", "nil")
  for c in component.list(componentType, true) do
    if c:sub(1, address:len()) == address then
      return c
    end
  end
  return nil, "no such component"
end

function component.isAvailable(componentType)
  checkArg(1, componentType, "string")
  if not primaries[componentType] and not adding[componentType] then
    component.setPrimary(componentType, component.list(componentType, true)())
  end
  return primaries[componentType] ~= nil
end

function component.isPrimary(address)
  local componentType = component.type(address)
  if componentType then
    if component.isAvailable(componentType) then
      return primaries[componentType].address == address
    end
  end
  return false
end

function component.getPrimary(componentType)
  checkArg(1, componentType, "string")
  assert(component.isAvailable(componentType),
    "no primary '" .. componentType .. "' available")
  return primaries[componentType]
end

function component.setPrimary(componentType, address)
  checkArg(1, componentType, "string")
  checkArg(2, address, "string", "nil")
  if address ~= nil then
    address = component.get(address, componentType)
    assert(address, "no such component")
  end

  local wasAvailable = primaries[componentType]
  if wasAvailable and address == wasAvailable.address then
    return
  end
  local wasAdding = adding[componentType]
  if wasAdding and address == wasAdding.address then
    return
  end
  if wasAdding then
    event.cancel(wasAdding.timer)
  end
  primaries[componentType] = nil
  adding[componentType] = nil

  local primary = address and component.proxy(address) or nil
  if wasAvailable then
    computer.pushSignal("component_unavailable", componentType)
  end
  if primary then
    if wasAvailable or wasAdding then
      adding[componentType] = {
        address=address,
        proxy = primary,
        timer=event.timer(0.1, function()
          adding[componentType] = nil
          primaries[componentType] = primary
          computer.pushSignal("component_available", componentType)
        end)
      }
    else
      primaries[componentType] = primary
      computer.pushSignal("component_available", componentType)
    end
  end
end
-------------------------------------------------------------------------------
local function onComponentAdded(_, address, componentType)
  local prev = primaries[componentType] or (adding[componentType] and adding[componentType].proxy)
  if prev then
    if componentType == "screen" then
      if #prev.getKeyboards() == 0 then
        local first_kb = component.invoke(address, 'getKeyboards')[1]
        if first_kb then
          component.setPrimary("keyboard", first_kb)
          prev = nil
        end
      end
    elseif componentType == "keyboard" then
      if address ~= prev.address then
        local current_screen = primaries.screen or (adding.screen and adding.screen.proxy)
        if current_screen then
          prev = address ~= current_screen.getKeyboards()[1]
        end
      end
    end
  end

  if not prev then
    component.setPrimary(componentType, address)
  end
end
local function onComponentRemoved(_, address, componentType)
  if primaries[componentType] and primaries[componentType].address == address or
     adding[componentType] and adding[componentType].address == address
  then
    local next = component.list(componentType, true)()
    component.setPrimary(componentType, next)
    if componentType == "screen" and next then
      local proxy = (primaries.screen or (adding.screen and adding.screen.proxy))
      if proxy then
        local next_kb = proxy.getKeyboards()[1]
        local old_kb = primaries.keyboard or adding.keyboard
        if next_kb and (not old_kb or old_kb.address ~= next_kb) then
          component.setPrimary("keyboard", next_kb)
        end
      end
    end
  end
end
event.listen("component_added", onComponentAdded)
event.listen("component_removed", onComponentRemoved)
if _G.boot_screen then
  component.setPrimary("screen", _G.boot_screen)
end
_G.boot_screen = nil
