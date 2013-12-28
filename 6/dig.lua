-- ex: ft=lua

local min_fuel = 1000
local min_filler = 5

local slot_blacklist_min = 1
local slot_blacklist_max = 3

local slot_cargo_min = slot_blacklist_max + 1
local slot_cargo_max = 14

local slot_filler = 15
local slot_ender_chest = 16

local depth_bedrock = 2 -- assumes flat bedrock

local debug_file = "log"
local debug_file_rotate = "log.old"
local debug_fh = nil

function debug_rotate()
  if fs.exists(debug_file) then
    if fs.exists(debug_file_rotate) then
      fs.delete(debug_file_rotate)
    end
    fs.move(debug_file, debug_file_rotate)
  end
  debug_fh = fs.open(debug_file, "w")
end

debug_rotate()

function debug_log(text)
  debug_fh.writeLine(text)

  if fs.getSize(debug_file) >= 100000 then
    debug_fh.writeLine("Rotating log.")
    debug_fh.close()
    debug_rotate()
  else
    debug_fh.flush()
  end
end

function debug(text)
  print(text)
  debug_log(text)
end
function debug_error(text)
  debug_log("FATAL: " .. text)
  error(text)
end

function supplies_check()
  if need_supplies() then
    ender_exchange()
    return true
  else
    return false
  end
end

function need_supplies()
  local fuel = turtle.getFuelLevel()
  local filler = turtle.getItemCount(slot_filler)
  local cargo_full = turtle.getItemCount(slot_cargo_max) > 0
  local refill = false

  if fuel < min_fuel then
    debug("Need to refuel (" .. fuel .. ").")
    refill = true
  end

  if filler < min_filler then
    debug("Need more filler (" .. filler .. ").")
    refill = true
  end

  if cargo_full then
    debug("Cargo full, need to offload.")
    refill = true
  end

  return refill
end

function ender_exchange()
  debug("Performing enderchest exchange ...")

  place_ender_chest()
  local chest = peripheral.wrap("front")
  local size  = chest.getInventorySize()

  local done = false
  while not done do
    for slot = slot_blacklist_min, slot_cargo_max do
      local count = turtle.getItemCount(slot)

      if count > 0 then
        turtle.select(slot)
        if slot <= slot_blacklist_max then
          turtle.drop(count - 1) -- drop all but the 1 we need to compare
        else
          turtle.drop()
        end
      end
    end

    local contents = chest.getAllStacks()

    for index, stack in pairs(contents) do
      if stack['id'] == 4 and stack['dmg'] == 0 then
        ender_cobble(chest, index)
      elseif stack['id'] == 327 and stack['dmg'] == 0 then
        ender_lava(chest, index)
      end
    end

    turtle.select(slot_ender_chest)
    if turtle.getItemCount(slot_ender_chest) > 0 and not turtle.compare() then
      debug("Ender chest slot contains items?!  Getting rid of them.")
      turtle.drop()
    end

    if need_supplies() then
      debug("Still need supplies!  Waiting and trying again.")
      sleep(5)
    else
      done = true
    end
  end

  turtle.dig()
  debug("Done enderchest exchange.")
end

inverse_facings = {}
inverse_facings[lama.side.north] = "south"
inverse_facings[lama.side.south] = "north"
inverse_facings[lama.side.east]  = "west"
inverse_facings[lama.side.west]  = "east"

function inverse_facing()
  return inverse_facings[lama.getFacing()]
end

function ender_cobble(chest, index)
  local needed = 64 - turtle.getItemCount(slot_filler)

  if needed > 0 then
    debug("Grabbing " .. needed .. " cobblestone ...")
    local grabbed = chest.pushItemIntoSlot(inverse_facing(), index, needed, slot_filler)
    if grabbed < needed then
      debug("Only got " .. grabbed .. " cobblestone. :(")
    end
  end
end

function ender_lava(chest, index)
  local fuel = turtle.getFuelLevel()
  if fuel < min_fuel then
    debug("Grabbing fuel ...")
    chest.pushItemIntoSlot(inverse_facing(), index, 1, slot_cargo_max)
    turtle.select(slot_cargo_max)
    if turtle.refuel() then
      debug("Refuelled: " .. fuel .. " -> " .. turtle.getFuelLevel())
    else
      debug("Failed to refuel. :(")
    end
    chest.pullItem(inverse_facing(), slot_cargo_max, 1)
  end
end

function place_ender_chest()
  if turtle.getItemCount(slot_ender_chest) < 1 then
    debug_error("No ender chest found!")
  end

  turtle.select(slot_ender_chest)

  for i = 1, 4 do
    if turtle.place() then
      return true
    end
    lama.turnRight()
  end

  debug("Can't find a clear direction, digging ...")

  for i = 1, 4 do
    if turtle.dig() and turtle.place() then
      return true
    end
    lama.turnRight()
  end

  -- TODO: error recovery, like trying to return to the surface?
  debug_error("Can't place ender chest!")
end

function circle_check()
  local found = 0
  for i = 1, 4 do
    if i > 1 then -- only make 3 turns to save time
      lama.turnRight()
    end
    if ore_check() then
      found = found + 1
    end
  end
  debug("Found " .. found .. " ore at depth " .. lama.getY() .. ".")
end

function ore_check()
  if not turtle.detect() then
    return false
  end

  for slot = slot_blacklist_min, slot_blacklist_max do
    turtle.select(slot)
    if turtle.compare() then
      return false
    end
  end

  turtle.select(1)
  turtle.dig()
  return true
end

function aggressive_down()
  return aggressive_moveto(lama.getX(), lama.getY() - 1, lama.getZ())
end
function aggressive_up()
  return aggressive_moveto(lama.getX(), lama.getY() + 1, lama.getZ())
end

function aggressive_moveto(x, y, z)
  while true do
    success, reason = lama.moveto(x, y, z, nil, 5, true)

    if success then
      return true
    elseif reason == lama.reason.unbreakable_block then
      debug("Hit bedrock; can't go further!")
      return false
    elseif reason == lama.reason.fuel then
      debug("Out of fuel!")
      supplies_check()
    else
      debug("Can't progress: " .. reason .. " ... will try again.")
    end

    sleep(5)
  end
end

function mining_run(target_y, refill)
  local done = false

  debug("Commencing mining run from y=" .. lama.getY() .. " to y=" .. target_y .. " ...")
  if refill then
    debug("Will refill blocks behind me.")
  end

  while not done do
    supplies_check()
    circle_check()
    turtle.select(slot_cargo_min)

    if lama.getY() > target_y then
      if not aggressive_down() then
        done = true
      end

      if refill then
        turtle.select(slot_filler)
        turtle.placeUp()
      end
    else
      if not aggressive_up() then
        done = true
      end

      if refill then
        turtle.select(slot_filler)
        turtle.placeDown()
      end
    end

    if lama.getY() == target_y then
      debug("I've reached y=" .. target_y .. ", so I'm done.")
      done = true
    end
  end
end

function reposition(x, z, surface_y)
  local orig_x = lama.getX()
  local orig_y = lama.getY()
  local orig_z = lama.getZ()

  debug("Repositioning to (" .. x .. "," .. z .. ") ...")

  if aggressive_moveto(x, orig_y, z) then
    return true
  else
    debug("Reposition failed!  Trying to backtrack ...")

    if not aggressive_moveto(orig_x, orig_y, orig_z) then
      debug("Backtrack failed!")
    end

    debug("Fleeing to the surface!")
    if aggressive_moveto(lama.getX(), surface_y, lama.getZ()) then
      debug_error("Whew, made it!")
    else
      debug_error("I'm stuck at x=" .. lama.getX() .. ", y=" .. lama.getY() .. ", z=" .. lama.getZ() .. ".  HALP!")
    end
  end
end

local start_y = lama.getY()
mining_run(2, true)
reposition(lama.getX() + 2, lama.getZ() + 1, start_y)
mining_run(start_y, true)
