local shell = require("shell")
local rc = shell.resolve("rc", "lua")
if rc then 
  dofile(rc)
end
