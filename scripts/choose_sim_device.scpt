#!/usr/bin/env osascript

(*

Updates by Ian Katz for environment variable support (switching Xcodes)

Based on:

Copyright (c) 2012 Jonathan Penn (http://cocoamanifest.net/)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

Chooses a device type from the iPhone Simulator using menu
selection events.

To use, make sure this file is executable, then run from the terminal:

  bin/choose_sim_device "iPad (Retina)"

Originally, I tried to do this by editing the Preference file for the
simulator, and it worked under Xcode 4.3, but now it ignores those changes
often enough that I chose to use this menu-selection route.

*)

on run argv
  set simType to item 1 of argv
  set iosVersion to item 2 of argv
  set developerDir to item 3 of argv

  set my_executable to developerDir & "/Platforms/iPhoneSimulator.platform/Developer/Applications/iPhone Simulator.app"

  activate application my_executable
  tell application "System Events"
    tell process "iOS Simulator"

      -- TODO: need to fall back for iOS simulator 6 which does not nest its menus
      
      tell menu bar 1
        tell menu bar item "Hardware" -- Hardware menu bar item
          tell menu 1                 -- Hardware menu

            -- determine if we are on version 6 of the sim by trying to find the version menu item
            try
              tell menu item "Version"
                click
              end tell
              set simVersion to 6
            on error errMsg
              set simVersion to 7
            end try
            --tell app "System Events" to display dialog simVersion


            if simVersion equals 6 then
              -- VERSION 6 INSTRUCTIONS
              -- HACKS for backwards compatibility, since Apple isn't into that
              if simType equals "iPhone Retina (3.5-inch)" then set simType to "iPhone (Retina 3.5-inch)"
              if simType equals "iPhone Retina (4-inch)" then   set simType to "iPhone (Retina 4-inch)"
              if iosVersion equals "iOS 6.0" then set iosVersion to "6.0 (10A403)"
              if iosVersion equals "iOS 6.1" then set iosVersion to "6.1 (10B141)"
              click menu item simType of menu 1 of menu item "Device"
              click menu item iosVersion of menu 1 of menu item "Version"

            else

              -- VERSION 7 INSTRUCTIONS
              tell menu item "Device"   -- Device menu item
                tell menu 1             -- Device sub menu

                  tell menu item simType
                    try
                      -- If this has a submenu, then find the iOS version.
                      set iosVersions to value of attribute "AXTitle" of every menu item of menu simType
                      repeat with iosVersionMenu in iosVersions
                        if iosVersionMenu contains iosVersion then
                          -- iOS Version
                          click menu item iosVersionMenu of menu simType
                          exit repeat
                        else

                        end if
                      end repeat
                    on error errMsg
                      -- If this is not a submenu, then just click.
                      click
                    end try
                  end tell
                end tell
              end tell

            end if -- version 6/7

          end tell
        end tell
      end tell
    end tell
  end tell

  -- Need to show the simulator again after changing device,
  -- or else the simulator be hidden when launched by instruments
  -- for some odd reason.
  tell application "System Events"
    set visible of process "iOS Simulator" to true
  end tell

end run
