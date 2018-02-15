function out = listPackagesInCodeRoots(paths)
paths = cellstr(paths);

out = {};
for iPath = 1:numel(paths)
    p = paths{iPath};
    if ~isdir(p)
        continue;
    end
    kids = dir(p);
    subdirNames = {kids([kids.isdir]).name};
    tfLooksLikePackage = ~cellfun(@isempty, regexp(subdirNames, '^\+\w+$'));
    packageNames = strrep(subdirNames(tfLooksLikePackage), '+', '');
    out = [out; packageNames(:)]; %#ok<AGROW>
end

out = unique(out);

end