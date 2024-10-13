function class(name)
  return setmetatable({}, {
    __cname = name
  })
end

local _M = class("MyTestClass")


_M.log = "hello"

function _M:print()
  print("hello")
end

return _M
