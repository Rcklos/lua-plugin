local guide = require("parser").guide
local helper = require("plugins.astHelper")
local LimitMulti = 10000

function dumpTable(table, depth, cache)
  local rep = function(d)
    return string.rep('  ', d)
  end
  if depth and (depth > 200) then
    print("Error: Depth > 200 in dumpTable()")
    return
  elseif not depth then
    depth = 0
  end
  if not cache then
    print(string.format("dump table: %s", table))
    cache = {}
    cache[table] = true
  end
  for k,v in pairs(table) do
    if type(v) == "string" then
      v = "\'" .. v .. "\'"
    end
    if (type(v) == "table") then
      if cache[v] then
        print(string.format("%s[%s]: repate-%s", rep(depth), k, v))
      elseif depth > 15 then
        print(string.format("%s[%s]: %s", rep(depth), k, v))
      else
        cache[v] = true
        print(string.format("%s[%s]: %s", rep(depth), k, v))
        dumpTable(v, depth+1, cache)
      end
    else
      if k == 'lua' or k == 'originText' then
        v = '[lua code...]'
      end
      print(string.format("%s[%s]: %s", rep(depth), k, v))
    end
  end
end

function OnSetText(uri, text)
    local diffs = {}

    for start, realName, finish in text:gmatch [=[require[ ]*["']()__(.-)()["']]=] do
        diffs[#diffs+1] = {
            start  = start,
            finish = finish - 1,
            text   = realName,
        }
    end

    if #diffs == 0 then
        return nil
    end

    return diffs
end

local function calc_uri(uri, name)
  if uri:match("%.lua") then
    -- 不是目录，转成目录
    uri = uri:match("(.*)/.*%.lua")
  end
  uri = string.format("%s/%s.lua", uri, name)
  return uri
end

---@class ast_mod
---@field rtn table
---@field ast table

local ast_mod_map = {}
local function saveAst(uri, ast)
  local mod = {}
  mod.ast = ast
  if ast.returns and #ast.returns > 0 then
    local rtn = ast.returns[1]
    if rtn.type == 'return' then
      mod.rtn = rtn[1].node
    end
  end
  if not mod.rtn then
    print(string.format("rtn --> %s", uri))
  end
  ast_mod_map[uri] = mod
end

function OnTransformAst(uri, ast)
  if not uri:match("lua.plugin") then
    return
  end
  guide.eachSourceType(ast, "call", function(source)
    dumpTable(source)
  end)
  print(string.format("uri: %s", uri))
  saveAst(uri, ast)
  dumpTable(ast)
end



