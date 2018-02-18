function editorFileChangedCallback(path)

persistent lastSeenPath

if isequal(path, lastSeenPath)
    return
end

MProjectNavigator('-editorfrontfile', path);
lastSeenPath = path;

end