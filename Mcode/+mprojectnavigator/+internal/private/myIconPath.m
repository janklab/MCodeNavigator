function out = myIconPath(label)
packageDir = fileparts(fileparts(mfilename('fullpath')));
resourceDir = [packageDir '/resources'];
iconDir = [resourceDir '/icons/silk'];
switch label
    case 'topfolder';   file = 'box.png';
    case 'folder';      file = 'folder.png';
    case 'dot';         file = 'bullet_green.png';
    case 'file';        file = 'page_white.png';
    case 'none';        file = [resourceDir '/icons/Transparent.gif'];
    otherwise           file = [];
end
if isempty(file)
    out = [];
else
    out = [iconDir '/' file];
end
end

