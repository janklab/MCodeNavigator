function editorFileTrackerCallback(varargin)

persistent lastSeenPath

path = varargin{1};
if isequal(path, lastSeenPath)
    return
end

MProjectNavigator('-editorfrontfile', path);
lastSeenPath = path;

end