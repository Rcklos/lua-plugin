local _Super = require("super")

local _M = class("MyClass", _Super)


local function print(self)
    self:super_print()
end

return _M