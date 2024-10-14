--print(require("test").log)
function class(name, super)
    return setmetatable({}, {
      __cname = name,
      __index = function(_, k)
        return super[k]
      end
    })
end

local cls = require("test")
cls:print()
--require("test"):print()

