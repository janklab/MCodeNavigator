on run argv
  set dir to quoted form of (first item of argv)
  tell application "Terminal"
    launch
  end tell
  tell app "Terminal" to do script "cd " & dir
end run