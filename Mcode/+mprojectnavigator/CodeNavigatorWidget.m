classdef CodeNavigatorWidget < mprojectnavigator.TreeWidget
    % A navigator for Mcode definitions (packages/classes/functions)
    
    properties
    end
    
    methods
        function this = CodeNavigatorWidget()
        end
        
        function initializeGui(this)
            import java.awt.*
            import javax.swing.*
            
            initializeGui@mprojectnavigator.TreeWidget(this);
            
            % Don't show root handle; we're using it for namespaces
            this.jTree.setShowsRootHandles(true);
            this.jTree.setRootVisible(false);
            
            % Set callback functions
            set(this.treePeerHandle, 'NodeExpandedCallback', {@nodeExpandedCallback, this});
            
            this.completeRefreshGui;
        end
        
        function completeRefreshGui(this)
            root = this.rootTreenode();
            this.treePeer.setRoot(root);
            pause(0.005); % Allow widgets to catch up
            % Expand the root node one level, and expand the USER node
            this.expandNode(root, this.jTree, false);
            this.expandNode(root.getChildAt(0), this.jTree, false);
        end
        
        function out = rootTreenode(this)
            nodeData.type = 'root';
            out = this.oldUitreenode('<dummy>', 'Definitions', [], true);
            out.setAllowsChildren(true);
            set(out, 'userdata', nodeData);
            
            pathInfo = matlabPathInfo();
            out.add(this.codePathsNode('USER', pathInfo.user));
            out.add(this.codePathsNode('MATLAB', pathInfo.system));
        end
        
        function out = codePathsNode(this, label, paths)
            % A node representing a codebase with a list of paths
            nodeData.type = 'codepaths';
            nodeData.label = label;
            nodeData.paths = paths;
            out = this.createNode(label, nodeData);
        end
        
        function out = packageNode(this, packageName)
            label = ['+' packageName];
            nodeData.type = 'package';
            nodeData.packageName = packageName;
            out = this.createNode(label, nodeData);
        end
        
        function out = classNode(this, className)
            classBaseName = regexprep(className, '.*\.', '');
            nodeData.type = 'class';
            nodeData.className = className;
            nodeData.classBaseName = classBaseName;
            label = ['@' classBaseName];                
            out = this.createNode(label, nodeData);
        end
        
        function out = methodGroupNode(this, parentDefinition)
            nodeData.type = 'methodGroup';
            nodeData.parentDefinition = parentDefinition;
            label = 'Methods';
            out = this.createNode(label, nodeData);
        end
        
        function out = methodNode(this, defn)
            mustBeA(defn, 'meta.method');
            nodeData.type = 'method';
            nodeData.fcnDefn = defn;
            baseLabel = sprintf('%s (%s)', defn.Name, strjoin(defn.OutputNames, ', '));
            items = {baseLabel};
            if ~isempty(defn.OutputNames)
                items{end+1} = sprintf(':[%s]', strjoin(defn.OutputNames, ', '));
            end
            items(cellfun(@isempty, items)) = [];
            if ~isequal(defn.Access, 'public')
                items{end+1} = defn.Access;
            end
            quals = {'Static' 'Abstract' 'Sealed' 'Hidden'};
            for i = 1:numel(quals)
                if defn.(quals{i})
                    items{end+1} = lower(quals{i});
                end
            end
            label = regexprep(strjoin(items, ' '), '  +', ' ');
            out = this.createNode(label, nodeData, false);
        end
        
        function out = propertyGroupNode(this, parentDefinition)
            nodeData.type = 'propertyGroup';
            nodeData.parentDefinition = parentDefinition;
            label = 'Properties';
            out = this.createNode(label, nodeData);
        end
        
        function out = propertyNode(this, defn, klassDefn)
            mustBeA(defn, 'meta.property');
            nodeData.type = 'property';
            nodeData.defn = defn;
            label = this.propertyLabel(defn, klassDefn);
            out = this.createNode(label, nodeData, false);
        end
        
        function out = propertyLabel(this, defn, klassDefn)
            items = {};
            items{end+1} = defn.Name;
            if isequal(defn.GetAccess, defn.SetAccess)
                access = defn.GetAccess;
            else
                access = sprintf('%s/%s', defn.GetAccess, defn.SetAccess);
            end
            access = strrep(access, 'public', '');
            items{end+1} = access;
            quals = {'Constant', 'Abstract', 'Transient', 'Hidden', ...
                'AbortSet', 'NonCopyable'};
            for i = 1:numel(quals)
                if defn.(quals{i})
                    items{end+1} = lower(quals{i}); %#ok<AGROW>
                end
            end
            if defn.HasDefault
                items{end+1} = '=()';
            end
            if ~isequal(defn.DefiningClass.Name, klassDefn.Name)
                items{end+1} = sprintf('(from %s)', defn.DefiningClass.Name);
            end
            items(cellfun(@isempty, items)) = [];
            out = regexprep(strjoin(items, ' '), '  +', ' ');
        end
        
        function out = eventGroupNode(this, parentDefinition)
            nodeData.type = 'eventGroup';
            nodeData.parentDefinition = parentDefinition;
            label = 'Events';
            out = this.createNode(label, nodeData);
        end
        
        function out = eventNode(this, defn)
            mustBeA(defn, 'meta.event');
            nodeData.type = 'event';
            nodeData.defn = defn;
            label = defn.Name;
            out = this.createNode(label, nodeData, false);
        end
        
        function out = superclassGroupNode(this, parentDefinition)
            nodeData.type = 'superclassGroup';
            nodeData.parentDefinition = parentDefinition;
            label = 'Superclasses';
            out = this.createNode(label, nodeData);
        end
        
        function out = superclassNode(this, defn)
            nodeData.type = 'superclass';
            nodeData.defn = defn;
            label = [ '@' defn.Name];
            out = this.createNode(label, nodeData, false);
        end
        
        function out = enumerationGroupNode(this, parentDefinition)
            nodeData.type = 'enumerationGroup';
            nodeData.parentDefinition = parentDefinition;
            label = 'Enumerations';
            out = this.createNode(label, nodeData);
        end
        
        function out = enumerationNode(this, defn)
            nodeData.type = 'enumeration';
            nodeData.defn = defn;
            label = defn.Name;
            out = this.createNode(label, nodeData, false);
        end
        
        function out = createNode(this, label, nodeData, allowsChildren)
            if nargin < 4 || isempty(allowsChildren); allowsChildren = true; end
            out = this.oldUitreenode('<dummy>', label, [], true);
            out.setAllowsChildren(allowsChildren);
            set(out, 'userdata', nodeData);
            if allowsChildren
                dummyNode = this.oldUitreenode('<dummy>', 'Loading...', [], true);
                out.add(dummyNode);
            end
        end
        
        function nodeExpanded(this, src, evd)
            tree = this.treePeer;
            node = evd.getCurrentNode;
            nodeData = get(node, 'userdata');
            % HACK: Bypass root expansion
            if isequal(nodeData.type, 'root')
                return;
            end
            if ~tree.isLoaded(node)
                newChildNodes = this.buildChildNodes(node);
                % Only this array-based adding method seems to work properly
                jChildNodes = javaArray('com.mathworks.hg.peer.UITreeNode', numel(newChildNodes));
                for i = 1:numel(newChildNodes)
                    jChildNodes(i) = java(newChildNodes{i});
                end
                tree.removeAllChildren(node);
                tree.add(node, jChildNodes);
                tree.setLoaded(node, true);
            end
        end
                
        function out = buildChildNodes(this, node)
            out = {};
            nodeData = get(node, 'userdata');
            switch nodeData.type
                case 'root'
                    % NOP: Shouldn't get here
                case 'codepaths'
                    pkgs = listPackagesInCodeRoots(nodeData.paths);
                    for i = 1:numel(pkgs)
                        out{end+1} = this.packageNode(pkgs{i}); %#ok<AGROW>
                    end
                case 'package'
                    pkg = meta.package.fromName(nodeData.packageName);
                    for i = 1:numel(pkg.ClassList)
                        out{end+1} = this.classNode(pkg.ClassList(i).Name); %#ok<AGROW>
                    end
                    for i = 1:numel(pkg.FunctionList)
                        % These are really methods, not functions (???)
                        out{end+1} = this.methodNode(pkg.FunctionList(i)); %#ok<AGROW>
                    end
                    for i = 1:numel(pkg.PackageList)
                        out{end+1} = this.packageNode(pkg.PackageList(i).Name); %#ok<AGROW>
                    end
                case 'function'
                    % NOP: No expansion                    
                case 'class'
                    klass = meta.class.fromName(nodeData.className);
                    if ~isempty(dropInheritedDefinitions(klass.PropertyList, klass))
                        out{end+1} = this.propertyGroupNode(klass);
                    end
                    if ~isempty(dropInheritedDefinitions(klass.MethodList, klass))
                        out{end+1} = this.methodGroupNode(klass);
                    end
                    if ~isempty(dropInheritedDefinitions(klass.EventList, klass))
                        out{end+1} = this.eventGroupNode(klass);
                    end
                    if ~isempty(klass.EnumerationMemberList)
                        out{end+1} = this.enumerationGroupNode(klass);
                    end
                    if ~isempty(klass.SuperclassList)
                        out{end+1} = this.superclassGroupNode(klass);
                    end
                case 'methodGroup'
                    defn = nodeData.parentDefinition;
                    methodList = dropInheritedDefinitions(defn.MethodList, defn);
                    for i = 1:numel(methodList)
                        % Hide well-known auto-defined methods
                        if isequal(methodList(i).Name, 'empty') && methodList(i).Static ...
                                && methodList(i).Hidden
                            continue;
                        end
                        out{end+1} = this.methodNode(methodList(i)); %#ok<AGROW>
                    end
                case 'propertyGroup'
                    defn = nodeData.parentDefinition;
                    propList = dropInheritedDefinitions(defn.PropertyList, defn);
                    for i = 1:numel(propList)
                        out{end+1} = this.propertyNode(propList(i), defn); %#ok<AGROW>
                    end
                case 'eventGroup'
                    defn = nodeData.parentDefinition;
                    eventList = dropInheritedDefinitions(defn.EventList, defn);
                    for i = 1:numel(eventList)
                        out{end+1} = this.eventNode(eventList(i)); %#ok<AGROW>
                    end
                case 'enumerationGroup'
                    defn = nodeData.parentDefinition;
                    for i = 1:numel(defn.EnumerationMemberList)
                        out{end+1} = this.enumerationNode(defn.EnumerationMemberList(i)); %#ok<AGROW>
                    end
                case 'superclassGroup'
                    defn = nodeData.parentDefinition;
                    for i = 1:numel(defn.SuperclassList)
                        out{end+1} = this.classNode(defn.SuperclassList(i).Name); %#ok<AGROW>
                    end
                case {'method','event','enumeration'}
                    % NOP: No expansion
                otherwise
                    fprintf('No expansion handler for node type %s\n', nodeData.type);
            end
        end
    end
end

function out = matlabPathInfo()
mlRoot = matlabroot;
paths = strsplit(path, ':');
tfSystem = strncmpi(paths, mlRoot, numel(mlRoot));
out.system = paths(tfSystem);
out.user = paths(~tfSystem);
end

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

function nodeExpandedCallback(src, evd, this) %#ok<INUSL>
this.nodeExpanded(src, evd);
end

function out = dropInheritedDefinitions(defnList, parentDefn)
% Filters out definitions that were inherited from another class/definer
if isempty(defnList)
    out = defnList;
    return;
end
definer = [ defnList.DefiningClass ];
definerName = { definer.Name };
tfInherited = ~strcmp(definerName, parentDefn.Name);
out = defnList(~tfInherited);
end

