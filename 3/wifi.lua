local modem = peripheral.wrap("right")
modem.closeAll()
modem.open(202)

local fh = fs.open("wifi.log", "w")

local last_distance = "no messages yet"
while true do
  local event, key, _, _, message, distance = os.pullEvent()

  if event == "char" then
    if key == " " then
      print("Last message distance: " .. last_distance)
    end
  elseif event == "modem_message" then
    print(message)
    fh.writeLine(message)
    fh.flush()
    last_distance = distance
  end
end
