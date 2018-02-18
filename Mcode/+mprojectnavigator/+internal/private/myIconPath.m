function out = myIconPath(label)
packageDir = fileparts(fileparts(mfilename('fullpath')));
resourceDir = [packageDir '/resources'];
silkDir = [resourceDir '/icons/silk'];
isFullPath = false;

switch label
    case 'topfolder';   file = 'box.png';
    case 'folder';      file = 'folder.png';
    case 'dot';         file = 'bullet_green.png';
    case 'file';        file = 'page_white.png';
    case 'error';       file = 'error.png';
    case 'none'
        file = [resourceDir '/icons/Transparent.gif'];
        isFullPath = true;
    case 'broken-image' 
        file = [resourceDir '/icons/broken-image.png'];
        isFullPath = true;
    otherwise
        logdebugf('Unrecognized icon name: ''%s''', label);
        file = [resourceDir '/icons/broken-image.png'];
        isFullPath = true;
end

if isempty(file)
    out = [];
elseif isFullPath
    out = file;
else
    out = [silkDir '/' file];
end
end

