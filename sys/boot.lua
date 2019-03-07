local raw_loadfile = ...

_G._OSNAME = "DEV1OS"
_G._OSVERSION = "v1.1 MAR 07 2019"

local component = component
local computer = computer
local unicode = unicode

local runlevel, shutdown = "S", computer.shutdown
computer.runlevel = function() return runlevel end
computer.shutdown = function(reboot)
  runlevel = reboot and 6 or 0
  if os.sleep then
    computer.pushSignal("shutdown")
    os.sleep(0.1)
  end
  shutdown(reboot)
end

local gpu = component.list("gpu", true)()
gpu = component.proxy(gpu)
local w, h

function rectangle(xf,yf,xt,yt,str)
	xf=xf-1
	yf=yf-1
	gpu.fill(xf, yf, xt-xf, yt-yf, str)
end

for address in component.list('screen', true) do
	screen = address
	_G.boot_screen = screen
  	gpu.bind(address)
  	w, h = gpu.maxResolution()
  	gpu.setResolution(w, h)
  	gpu.setBackground(0x000000)
  	gpu.setForeground(0xFFFFFF)
  	gpu.fill(1, 1, w, h, " ")
  	gpu.setBackground(0xFFFFFF)
  	--D
  	rectangle(56,22,61,22," ")
  	rectangle(56,22,56,28," ")
  	rectangle(56,28,61,28," ")
  	rectangle(62,23,62,27," ")
  	--E
  	rectangle(65,22,71,22," ")
  	rectangle(65,25,71,25," ")
  	rectangle(65,28,71,28," ")
  	--V
  	rectangle(74,22,74,23," ")
  	rectangle(80,22,80,23," ")
  	rectangle(75,24,75,25," ")
  	rectangle(79,24,79,25," ")
  	rectangle(76,26,76,27," ")
  	rectangle(78,26,78,27," ")
  	rectangle(77,28,77,28," ")
  	--1
  	gpu.setBackground(0xFF0000)
  	rectangle(83,22,83,22," ")
  	rectangle(84,22,84,27," ")
  	rectangle(83,28,85,28," ")
  	--O
  	gpu.setBackground(0xFFFFFF)
  	rectangle(88,23,88,27," ")
  	rectangle(94,23,94,27," ")
  	rectangle(89,22,93,22," ")
  	rectangle(89,28,93,28," ")
  	--S
  	rectangle(98,22,102,22," ")
  	rectangle(98,25,102,25," ")
  	rectangle(98,28,102,28," ")
  	rectangle(97,23,97,24," ")
  	rectangle(97,27,97,27," ")
  	rectangle(103,23,103,23," ")
  	rectangle(103,26,103,27," ")
  	--ADDRESS
  	gpu.setBackground(0x000000)
  	gpu.set(55, 30, 'The screen: ' .. address)
end

local y = 1
local uptime = computer.uptime
local pull = computer.pullSignal
local last_sleep = uptime()
local loadfile = function(file)
  return raw_loadfile(file)
end
local function dofile(file)
  local program, reason = loadfile(file)
  if program then
    local result = table.pack(pcall(program))
    if result[1] then
      return table.unpack(result, 2, result.n)
    else
      error(result[2])
    end
  else
    error(reason)
  end
end
local package = dofile("/lib/package.lua")

do
  _G.component = nil
  _G.computer = nil
  _G.process = nil
  _G.unicode = nil
  _G.package = package

  package.loaded.component = component
  package.loaded.computer = computer
  package.loaded.unicode = unicode
  package.loaded.buffer = assert(loadfile("/lib/buffer.lua"))()
  package.loaded.filesystem = assert(loadfile("/lib/filesystem.lua"))()

  _G.io = assert(loadfile("/lib/io.lua"))()
end

require("filesystem").mount(computer.getBootAddress(), "/")

local function rom_invoke(method, ...)
  return component.invoke(computer.getBootAddress(), method, ...)
end
local scripts = {}
for _, file in ipairs(rom_invoke("list", "sys/boot")) do
  local path = "sys/boot/" .. file
  if not rom_invoke("isDirectory", path) then
    table.insert(scripts, path)
  end
end
table.sort(scripts)
for i = 1, #scripts do
  dofile(scripts[i])
end

for c, t in component.list() do
  computer.pushSignal("component_added", c, t)
end

computer.pushSignal("init")
require("event").pull(1, "init")
_G.runlevel = 1