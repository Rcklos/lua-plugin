local guide = require("parser").guide
local helper = require("plugins.astHelper")

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
    cache = {}
  end
  for k,v in pairs(table) do
    if type(v) == "string" then
      v = "\'" .. v .. "\'"
    end
    if (type(v) == "table") then
      if depth > 6 then
        print(string.format("%s[%s]: %s", rep(depth), k, v))
      elseif cache[v] then
        print(string.format("%s[%s]: repate-%s", rep(depth), k, v))
      else
        cache[v] = true
        print(string.format("%s[%s]: %s", rep(depth), k, v))
        dumpTable(v, depth+1, cache)
      end
    else
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

local function addClassByCall(ast)
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
    if source.args and #source.args > 0 and source.args[1].type == "string" then
      -- dumpTable(source.args[1])
      cls_name = guide.getKeyName(source.args[1])
    end
    -- print(string.format("class_name: %s", cls_name))
    if cls_name then
      local group = {}
      helper.addClassDoc(ast, cls_name_node, cls_name, group)
      helper.addDoc(ast, cls_name_node, "field", "__cname string", group)
    end
  end)
end

local function debug_print(ast)
  print(string.format("dump: %s, size: %s", ast, #ast))
  dumpTable(ast)
end

function OnTransformAst(uri, ast)
  debug_print(ast)
  addClassByCall(ast)
end



