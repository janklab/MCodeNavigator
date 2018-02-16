function out = isFolder(path)
    jFile = java.io.File(path);
    out = jFile.isDirectory();
end
