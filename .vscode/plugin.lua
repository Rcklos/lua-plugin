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

local cls_map = {}
local function calc_base(uri)
  return uri:match("(.*)/.*%.lua")
end

local function find_cls(uri, source)
  if source.type ~= 'local' then
    return false, "local"
  end
  local value = source.value
  if not value.type == 'select' then
    return false, "select"
  end
  local vararg = value.vararg
  if not vararg.type == 'call' or not guide.getKeyName(vararg.node) == 'require' then
    return false, string.format("vararg, %s, %s", vararg.type, guide.getKeyName(vararg.node))
  end
  if vararg.args and vararg.args[1] and vararg.args[1].type == "string" then
    local name = guide.getKeyName(vararg.args[1])
    local base = calc_base(uri)
    local find_uri = string.format("%s/%s.lua", base, name)
    print("find_uri", cls_map[find_uri])
    return cls_map[find_uri]
  end
end

local function addClassMap(uri, ast, node, cls)
  guide.eachSourceType(ast, "main", function(source)
    if source.returns and source.returns[1] then
      local rtn = source.returns[1][1] and source.returns[1][1].node or source.returns[1].type
      if rtn and rtn == node then
        cls_map[uri] = cls
      end
    end
  end)
end

local function addClassByCall(uri, ast)
  guide.eachSourceType(ast, "call", function(source)
    local node = source.node
    if guide.getKeyName(node) ~= 'class' then
      return
    end
    local wants = {
      ['local'] = true,
      ['setglobal'] = true,
    }
    local cls_name_node = guide.getParentTypes(source, wants)
    if not cls_name_node then
      return
    end
    local cls_name = guide.getKeyName(cls_name_node)
    local group = {}
    if source.args and #source.args > 0 and source.args[1].type == "string" then
      -- dumpTable(source.args[1])
      cls_name = guide.getKeyName(source.args[1])
    end
    if source.args and source.args[2] and guide.getKeyType(source.args[2]) == 'local' then
      local super = find_cls(uri, source.args[2].node)
      if super then
        cls_name = string.format("%s: %s", cls_name, super)
      end
    end
    print(string.format("class_name: %s", cls_name))
    if cls_name then
      helper.addClassDoc(ast, cls_name_node, cls_name, group)
      -- helper.addDoc(ast, cls_name_node, "field", "__cname string", group)
      addClassMap(uri, ast, cls_name_node, cls_name)
    end
  end)
end

local function debug_print(ast)
  print(string.format("dump: %s, size: %s", ast, #ast))
  -- dumpTable(ast)
  guide.eachSourceType(ast, "call", function(source)
    local node = source.node
    if guide.getKeyName(node) ~= 'class' then
      return
    end
    -- 直接找上一行
    local start = (node.start // LimitMulti - 1) * LimitMulti
    if not ast.state then
      print("state")
      return
    end
    local comms = ast.state.comms
    if not comms then
      print("comms")
      return
    end
    for _, comm in pairs(comms) do
      if comm.finish + LimitMulti > start then
        if comm.text:match('^-@field') or comm.text:match('^-@class') then
          return
        end
      end
    end
  end)
end

function OnTransformAst(uri, ast)
  debug_print(ast)
  -- addClassByCall(uri, ast)
end



