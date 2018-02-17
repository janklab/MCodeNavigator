classdef CodeBase
    
    properties
        pathString
        roots
        userRoots
        sysRoots
    end
    
    methods
        function this = CodeBase()
            this.pathString = path;
            s = parsePathStr(this.pathString);
            this.roots = s.allRoots;
            this.userRoots = s.userRoots;
            this.sysRoots = s.sysRoots;
        end
        
        function out = defnForMfile(this, file)
            % Given a file path to an mfile, return what it defines
            %
            % Returns struct<type,name,basename,package,private,scope>
            
            % See if it's on the path
            relPath = [];
            for i = 1:numel(this.roots)
                if strncmpi(this.roots{i}, file, numel(this.roots{i}))
                    relPath = file(numel(this.roots{i})+2:end);
                end
            end
            if isempty(relPath)
                % File is not on the path; it doesn't define anything
                out = [];
                return;
            end
            if strncmpi(file, matlabroot, numel(matlabroot))
                out.scope = 'system';
            else
                out.scope = 'user';
            end
            
            % Parse the relative file path into package etc
            p = strsplit(relPath, filesep);
            pkgEls = {};
            iPkgEnd = 0;
            for i = 1:numel(p)
                if p{i}(1) == '+'
                    pkgEls{end+1} = p{i}(2:end); %#ok<AGROW>
                else
                    iPkgEnd = i - 1;
                end
            end
            packageName = strjoin(pkgEls, '.');
            if iPkgEnd == numel(p)
                % It's a package directory
                out.package = strjoin(pkgEls(1:end-1), '.');
                out.type = 'package';
                out.name = packageName;
                out.basename = pkgEls{end};
                out.private = false;
            end
            i = iPkgEnd + 1;
            if numel(p) > i + 1
                out = [];
                return;
            end
            if p{i}(1) == '@'
                % classdir definition format
                classBaseName = p{i}(2:end);
                [~,identifier,~] = fileparts(p{i+1});
                out.package = packageName;
                out.basename = identifier;
                out.private = false;
                if isequal(identifier, classBaseName)
                    % it's a class constructor
                    out.type = 'class';
                    out.name = [packageName '.' classBaseName];
                else
                    % it's a method
                    out.type = 'method';
                    out.name = [packageName '.' classBaseName '.' identifier];
                end
            elseif isequal(lower(p{i}), 'private')
                % private folder; must be a function
                [~,identifier,~] = fileparts(p{i+1});
                out.type = 'function';
                out.name = [packageName '.' identifier];
                out.basename = identifier;
                out.package = packageName;
                out.private = true;
            elseif i == numel(p)
                out.package = packageName;
                out.private = false;
                [~,identifier,~] = fileparts(p{i});
                out.basename = identifier;
                % assume that we were passed a legit extension
                name = ifthen(isempty(packageName), identifier, [packageName '.' identifier]);
                out.name = name;
                tryKlass = meta.class.fromName(name);
                if ~isempty(tryKlass)
                    % found a class definition
                    out.type = 'class';
                else
                    % not a class definition; see if it's a function
                    if ~isempty(packageName)
                        pkg = meta.package.fromName(packageName);
                        if isempty(pkg.FunctionList)
                            functionNames = {};
                        else
                            functionNames = {pkg.FunctionList.Name};
                        end
                        if ismember(identifier, functionNames)
                            % Functions inside packages are called 'method's by the
                            % metadata system
                            out.type = 'method';
                        else
                            % must be a Contents.m or script or some junk
                            out = [];
                        end
                    else
                        w = which(identifier);
                        if isequal(w, file)
                            % It's a global function
                            out.type = 'function';
                        else
                            % Must be a script or some junk
                            out = [];
                        end
                    end
                end
            else
                % It's in a random subfolder under the class; it's not an
                % Mcode definition
                out = [];
                return;
            end
        end
        
        function out = mfileForDefn(this, defnName) %#ok<INUSL>
            % Given a class or function name, return the path to its definition file
            out = which(defnName); % This one is really easy
        end
        
        function out = mfileForClass(this, className) %#ok<INUSL>
            % Given a class, return the path to its definition file
            out = which(className);
        end
        
        function out = mfileForFunction(this, functionName) %#ok<INUSL>
            out = which(functionName);
        end
        
        function out = locationInfoForDefn(this, defn, file)
            if strncmpi(file, matlabroot, numel(matlabroot))
                out.scope = 'system';
            else
                out.scope = 'user';
            end
        end
    end
    
    methods (Static = true)
        function out = matlabPathInfo()
            mlRoot = matlabroot;
            paths = strsplit(path, pathsep);
            tfSystem = strncmpi(paths, mlRoot, numel(mlRoot));
            out.system = paths(tfSystem);
            out.user = paths(~tfSystem);
        end
    end
    
end

function out = parsePathStr(pathStr)
roots = strsplit(pathStr, pathsep);
sysprefix = matlabroot;
userRoots = {};
sysRoots = {};
for i = 1:numel(roots)
    if strncmpi(sysprefix, roots{i}, numel(sysprefix))
        sysRoots{end+1} = roots{i}; %#ok<AGROW>
    else
        userRoots{end+1} = roots{i}; %#ok<AGROW>
    end
end
out.allRoots = roots;
out.userRoots = userRoots;
out.sysRoots = sysRoots;
end