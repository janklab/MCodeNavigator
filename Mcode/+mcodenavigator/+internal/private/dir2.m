function out = dir2(path)
    out = dir(path);
    % Ignore all hidden files
    out(~cellfun(@isempty, regexp({out.name}, '^\.', 'once'))) = [];
end
