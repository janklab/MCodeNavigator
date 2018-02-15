function dumpActionMap(actionMap)

keys = actionMap.allKeys();
if ~isempty(keys)
    fprintf('  ActionMap:\n');
end
for i = 1:numel(keys)
    key = keys(i);
    action = actionMap.get(key);
    fprintf('    %-30s => %-80s (%s)\n', key, stringOf(action), class(action));
end

end

function out = stringOf(jObject)
if isempty(jObject)
    out = 'null';
else
    out = char(jObject.toString());
end
end