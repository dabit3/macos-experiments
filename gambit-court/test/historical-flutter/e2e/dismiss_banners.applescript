-- Close every macOS notification banner so none can cover a client window
-- in the screen recording. Prints the number of banners closed.
on closeIn(e, depth)
  tell application "System Events"
    try
      repeat with a in actions of e
        if (name of a as text) contains "Close" then
          perform a
          return true
        end if
      end repeat
    end try
    if depth < 8 then
      try
        repeat with c in UI elements of e
          if my closeIn(c, depth + 1) then return true
        end repeat
      end try
    end if
  end tell
  return false
end closeIn

on closeOne()
  tell application "System Events"
    if not (exists process "NotificationCenter") then return false
    tell process "NotificationCenter"
      if not (exists window "Notification Center") then return false
      return my closeIn(window "Notification Center", 1)
    end tell
  end tell
end closeOne

set closed to 0
repeat 20 times
  if not closeOne() then exit repeat
  set closed to closed + 1
  delay 0.2
end repeat
return closed
