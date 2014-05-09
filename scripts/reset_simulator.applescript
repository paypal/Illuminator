(* commented out printer section for now
tell application "iPhone Simulator" to activate

tell application "System Events"
    tell process "iPhone Simulator"
        tell menu bar 1
            tell menu bar item "File"
                tell menu "File"
                    click menu item "Open Printer Simulator"
                end tell
            end tell
        end tell
    end tell
end tell
*)

tell application "iPhone Simulator" to launch

set inTime to current date
repeat
    tell application "System Events"
        if "iPhone Simulator" is in (get name of processes) then exit repeat
    end tell
    if (current date) - inTime is greater than 10 then exit repeat
    delay 0.2
end repeat

tell application "iPhone Simulator" to activate

set inTime to current date
repeat
    tell application "System Events"
        if visible of process "iPhone Simulator" is true then exit repeat
    end tell
    if (current date) - inTime is greater than 10 then exit repeat
    delay 0.2
end repeat

tell application "System Events"
    tell process "iPhone Simulator"
        tell menu bar 1
            tell menu bar item "iOS Simulator"
                tell menu "iOS Simulator"
                    click menu item "Reset Content and Settings…"
                end tell
            end tell
        end tell

        tell window 1
            click button "Reset"
        end tell
    end tell
end tell

tell application "iPhone Simulator" to quit

set inTime to current date
repeat
    tell application "System Events"
        if "iPhone Simulator" is not in (get name of processes) then exit repeat
    end tell
    if (current date) - inTime is greater than 10 then exit repeat
    delay 0.2
end repeat


-- tell application "System Events" to tell process "Printer Simulator" to set visible to false
