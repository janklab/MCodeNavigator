function editorFileChangedCallback(path)

persistent lastSeenPath

if isequal(path, lastSeenPath)
    return
end

MCodeNavigator('-editorfrontfile', path);
lastSeenPath = path;

end