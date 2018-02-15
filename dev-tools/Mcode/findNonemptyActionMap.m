function findNonemptyActionMap(component)
% Recursively find components that have a non-empty actionMap
%
% Examples:
%
% mainFrame = com.mathworks.mde.desk.MLDesktop.getInstance.getMainFrame;
% str = evalc('findNonemptyActionMap(mainFrame.getContentPane)');
% clipboard('copy',str)
% % Then paste it into a text editor for viewing

step(component, 'root');
end

function step(c, pathLabel)
import javax.swing.*

if ~isa(c, 'javax.swing.JComponent')
    return;
end
inputMaps = struct;
inputMaps.WHEN_FOCUSED = c.getInputMap(JComponent.WHEN_FOCUSED);
inputMaps.WHEN_IN_FOCUSED_WINDOW = c.getInputMap(JComponent.WHEN_IN_FOCUSED_WINDOW);
inputMaps.WHEN_ANCESTOR_OF_FOCUSED_COMPONENT = c.getInputMap(JComponent.WHEN_ANCESTOR_OF_FOCUSED_COMPONENT);
actionMap = c.getActionMap;

hasMap = ~isempty(actionMap) || ~isempty(inputMaps.WHEN_FOCUSED) ...
    || ~isempty(inputMaps.WHEN_IN_FOCUSED_WINDOW) ...
    || ~isempty(inputMaps.WHEN_ANCESTOR_OF_FOCUSED_COMPONENT);

if hasMap
    fprintf('Found: %s  - (%s)\n', pathLabel, class(c));
    % format for pretty word-wrapping in editors
    %fprintf('       %s\n', c.toString());
end
inputMapNames = { 'WHEN_FOCUSED', 'WHEN_IN_FOCUSED_WINDOW', 'WHEN_ANCESTOR_OF_FOCUSED_COMPONENT'};
for i = 1:numel(inputMapNames)
    dumpInputMap(inputMaps.(inputMapNames{i}), inputMapNames{i});
end
if ~isempty(actionMap)
    keys = actionMap.allKeys;
    if ~isempty(keys)
        dumpActionMap(actionMap);
    end
end
nKids = c.getComponentCount;
for i = 1:nKids
    kid = c.getComponent(i-1);
    kidText = regexprep(class(kid), '.*\.', '');
    kidPathLabel = sprintf('%s [%d](%s)', pathLabel, i-1, kidText);
    step(kid, kidPathLabel);
end
end


function dumpInputMap(inputMap, mapName)
keys = inputMap.keys;
if ~isempty(keys)
    fprintf('  InputMap: %s\n', mapName);
end
for i = 1:numel(keys)
    key = keys(i);
    val = inputMap.get(key);
    fprintf('    %-30s  -> %-60s (%s)\n', key.toString(), stringOf(val), class(val));
end
end


function out = stringOf(jObject)
if isempty(jObject)
    out = 'null';
elseif isjava(jObject)
    out = char(jObject.toString);
else
    out = jObject;
end
end