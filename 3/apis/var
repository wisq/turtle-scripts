-- ex: ft=lua

function dump(value, depth, key)
  local output = ""
  local linePrefix = ""
  local spaces = ""
  
  if key ~= nil then
    linePrefix = "["..key.."] = "
  end
  
  if depth == nil then
    depth = 0
  else
    depth = depth + 1
    for i=1, depth do spaces = spaces .. "  " end
  end
  
  if type(value) == 'table' then
    mTable = getmetatable(value)
    if mTable == nil then
      output = output .. spaces .. linePrefix .. "(table)\n"
    else
      output = output .. spaces .. "(metatable)\n"
        value = mTable
    end		
    for tableKey, tableValue in pairs(value) do
      output = output .. dump(tableValue, depth, tableKey)
    end
  elseif type(value)	== 'function' or 
      type(value)	== 'thread' or 
      type(value)	== 'userdata' or
      value		== nil
  then
    output = output .. spaces .. tostring(value) .. "\n"
  else
    output = output .. spaces .. linePrefix .. "(" .. type(value) .. ") " .. tostring(value) .. "\n"
  end

  return output
end

function dumpFile(value, depth, key)
  fh = fs.open("var.dump", "w")
  fh.write(dump(value, depth, key))
  fh.close()
end

