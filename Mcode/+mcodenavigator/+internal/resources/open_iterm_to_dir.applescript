-- AppleScript to open a new iTerm2 tab with a shell session
-- starting in a given directory.
--
-- TODO: Smarter quoting of the path

on run argv

  set targetDir to item 1 of argv

  -- Make sure iTerm2 is running. Doing this unconditionally
  -- is the only way I've gotten this to work
  tell application "iTerm2"
    launch
  end tell

  tell application "iTerm2"
    activate

    -- Make sure it has a window open
    if exists current window
      tell the current window
        set newTab to create tab with default profile
      end
    else
      create window with default profile
    end

    tell the current window
      tell the current tab
        tell the current session
          write text "cd " & quoted form of targetDir
        end tell
      end tell
    end tell
  end tell

end
