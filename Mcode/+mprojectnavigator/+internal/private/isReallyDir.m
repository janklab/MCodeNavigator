function out = isReallyDir(path)
    jFile = java.io.File(path);
    out = jFile.isDirectory();
end
