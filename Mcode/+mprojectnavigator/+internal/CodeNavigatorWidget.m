classdef CodeNavigatorWidget < mprojectnavigator.internal.TreeWidget
    % A navigator for Mcode definitions (packages/classes/functions)
    
    properties (SetAccess = private)
        flatPackageView = getpref(PREFGROUP, 'code_flatPackageView', false);
        showHidden = getpref(PREFGROUP, 'code_showHidden', false);
        navigator;
    end
    
    methods
        function this = CodeNavigatorWidget(parentNavigator)
            this.navigator = parentNavigator;
            this.initializeGui;
        end
        
        function initializeGui(this)
            import java.awt.*
            import javax.swing.*
            
            initializeGui@mprojectnavigator.internal.TreeWidget(this);
            
            % Don't show root node; we're using multiple roots for code sets
            this.jTree.setShowsRootHandles(true);
            this.jTree.setRootVisible(false);
                        
            this.completeRefreshGui;
        end
        
        function setFlatPackageView(this, newState)
            if newState == this.flatPackageView
                return;
            end
            this.flatPackageView = newState;
            setpref(PREFGROUP, 'code_flatPackageView', this.flatPackageView);
            this.completeRefreshGui;
        end
        
        function setShowHidden(this, newState)
            if newState == this.showHidden
                return;
            end
            this.showHidden = newState;
            setpref(PREFGROUP, 'code_showHidden', this.showHidden);
            this.completeRefreshGui;
        end
        
        function completeRefreshGui(this)
            root = this.rootTreenode();
            this.treePeer.setRoot(root);
            pause(0.005); % Allow widgets to catch up
            % Expand the root node one level, and expand the USER node
            this.expandNode(root);
            this.expandNode(root.getChildAt(0));
        end
        
        function out = setupTreeContextMenu(this, node, nodeData)
            import javax.swing.*
            
            fileShellName = mprojectnavigator.internal.Utils.osFileBrowserName;
            
            if ~isempty(node) && ~this.isInSelection(node)
                this.setSelectedNode(node);
            end
            
            jmenu = JPopupMenu;
            menuItemEdit = JMenuItem('Edit');
            menuItemViewDoc = JMenuItem('View Doc');
            menuItemRevealInDesktop = JMenuItem(sprintf('Reveal in %s', fileShellName));
            menuItemFullyExpandNode = JMenuItem('Fully Expand');
            menuOptions = JMenu('Options');
            menuItemFlatPackageView = JCheckBoxMenuItem('Flat Package View');
            menuItemFlatPackageView.setSelected(this.flatPackageView);
            menuItemShowHidden = JCheckBoxMenuItem('Show Hidden Items');
            menuItemShowHidden.setSelected(this.showHidden);
            
            nd = nodeData;
            if isempty(nd)
                [isTargetClass,isTargetMethod,isTargetFunction,isTargetProperty,...
                    isTargetEvent,isTargetEnum] = deal(false);
            else
                isTargetClass = isequal(nd.type, 'class');
                isTargetMethod = isequal(nd.type, 'method');
                isTargetFunction = isequal(nd.type, 'function');
                isTargetProperty = isequal(nd.type, 'property');
                isTargetEvent = isequal(nd.type, 'event');
                isTargetEnum = isequal(nd.type, 'enumeration');
            end
            isTargetEditable = isTargetClass || isTargetMethod || isTargetFunction;
            isTargetDocable = isTargetClass || isTargetMethod || isTargetProperty ...
                || isTargetEvent || isTargetEnum || isTargetFunction;
            isTargetRevealable = isTargetClass;
            menuItemEdit.setEnabled(isTargetEditable);
            
            function setCallback(item, callback)
                set(handle(item,'CallbackProperties'), 'ActionPerformedCallback', callback);
            end
            setCallback(menuItemEdit, {@ctxEditCallback, this, nodeData});
            setCallback(menuItemViewDoc, {@ctxViewDocCallback, this, nodeData});
            setCallback(menuItemRevealInDesktop, {@ctxRevealInDesktopCallback, this, nodeData});
            setCallback(menuItemFullyExpandNode, {@ctxFullyExpandNodeCallback, this, node, nodeData});
            setCallback(menuItemFlatPackageView, {@ctxFlatPackageViewCallback, this, nodeData});
            setCallback(menuItemShowHidden, {@ctxShowHiddenCallback, this, nodeData});
            
            if isTargetEditable
                jmenu.add(menuItemEdit);
            end
            if isTargetDocable
                jmenu.add(menuItemViewDoc);
            end
            if isTargetRevealable
                jmenu.add(menuItemRevealInDesktop);
            end
            if isTargetEditable || isTargetDocable || isTargetRevealable
                jmenu.addSeparator;
            end
            %TODO: Fix fully-expand. It's currently doing nothing.
            %if ~isempty(node) && ~node.isLeaf
            %    jmenu.add(menuItemFullyExpandNode);
            %    jmenu.addSeparator;
            %end
            menuOptions.add(menuItemFlatPackageView);
            menuOptions.add(menuItemShowHidden);
            jmenu.add(menuOptions);
            out = jmenu;
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
            icon = myIconPath('topfolder');
            out = this.createNode(label, nodeData, [], icon);
        end
        
        function out = codePathsGlobalsNode(this, paths, found)
            % A node representing global definitions under a codepath set
            nodeData.type = 'codepaths_globals';
            nodeData.paths = paths;
            nodeData.found = found;
            icon = myIconPath('folder');
            out = this.createNode('<Global>', nodeData, [], icon);
        end
        
        function out = globalClassesNode(this, classNames)
            nodeData.type = 'global_classes';
            nodeData.classNames = classNames;
            icon = myIconPath('folder');
            out = this.createNode('Classes', nodeData, [], icon);
        end
        
        function out = globalFunctionsNode(this, functionNames)
            nodeData.type = 'global_functions';
            nodeData.functionNames = functionNames;
            icon = myIconPath('folder');
            out = this.createNode('Functions', nodeData, [], icon);
        end
        
        function out = packageNode(this, packageName)
            label = ['+' packageName];
            nodeData.type = 'package';
            nodeData.packageName = packageName;
            icon = myIconPath('folder');
            out = this.createNode(label, nodeData, [], icon);
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
            icon = myIconPath('none');
            out = this.createNode(label, nodeData, [], icon);
        end
        
        function out = methodNode(this, defn, packageName)
            mustBeA(defn, 'meta.method');
            nodeData.type = 'method';
            nodeData.defn = defn;
            nodeData.packageName = packageName;
            inputArgStr = ifthen(isequal(defn.InputNames, {'rhs1'}), '...', ...
                strjoin(defn.InputNames, ', '));
            baseLabel = sprintf('%s (%s)', defn.Name, inputArgStr);
            items = {baseLabel};
            if ~isempty(defn.OutputNames) && ~isequal(defn.OutputNames, {'lhs1'})
                items{end+1} = sprintf(':[%s]', strjoin(defn.OutputNames, ', '));
            end
            items(cellfun(@isempty, items)) = [];
            if ~isequal(defn.Access, 'public')
                items{end+1} = defn.Access;
            end
            quals = {'Static' 'Abstract' 'Sealed' 'Hidden'};
            for i = 1:numel(quals)
                if defn.(quals{i})
                    items{end+1} = lower(quals{i}); %#ok<AGROW>
                end
            end
            label = regexprep(strjoin(items, ' '), '  +', ' ');
            icon = myIconPath('dot');
            out = this.createNode(label, nodeData, false, icon);
        end
        
        function out = functionNode(this, functionName)
            nodeData.type = 'function';
            nodeData.functionName = functionName;
            icon = myIconPath('dot');
            out = this.createNode(functionName, nodeData, false, icon);
        end
        
        function out = propertyGroupNode(this, parentDefinition)
            nodeData.type = 'propertyGroup';
            nodeData.parentDefinition = parentDefinition;
            label = 'Properties';
            icon = myIconPath('none');
            out = this.createNode(label, nodeData, [], icon);
        end
        
        function out = propertyNode(this, defn, klassDefn)
            mustBeA(defn, 'meta.property');
            nodeData.type = 'property';
            nodeData.defn = defn;
            label = this.propertyLabel(defn, klassDefn);
            icon = myIconPath('dot');
            out = this.createNode(label, nodeData, false, icon);
        end
        
        function out = propertyLabel(this, defn, klassDefn) %#ok<INUSL>
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
            icon = myIconPath('none');
            out = this.createNode(label, nodeData, [], icon);
        end
        
        function out = eventNode(this, defn)
            mustBeA(defn, 'meta.event');
            nodeData.type = 'event';
            nodeData.defn = defn;
            label = defn.Name;
            icon = myIconPath('dot');
            out = this.createNode(label, nodeData, false, icon);
        end
        
        function out = superclassGroupNode(this, parentDefinition)
            nodeData.type = 'superclassGroup';
            nodeData.parentDefinition = parentDefinition;
            label = 'Superclasses';
            icon = myIconPath('none');
            out = this.createNode(label, nodeData, [], icon);
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
        
        function out = createNode(this, label, nodeData, allowsChildren, icon)
            if nargin < 4 || isempty(allowsChildren); allowsChildren = true; end
            if nargin < 5 || isempty(icon);  icon = [];  end
            
            out = this.oldUitreenode('<dummy>', label, icon, true);
            out.setAllowsChildren(allowsChildren);
            set(out, 'userdata', nodeData);
            if allowsChildren
                dummyIcon = myIconPath('none');
                dummyNode = this.oldUitreenode('<dummy>', 'Loading...', dummyIcon, true);
                out.add(dummyNode);
            end
        end
        
        function nodeExpanded(this, src, evd) %#ok<INUSL>
            tree = this.treePeer;
            node = evd.getCurrentNode;
            nodeData = get(node, 'userdata');
            % HACK: Bypass root expansion
            if isequal(nodeData.type, 'root')
                return;
            end
            % We could check ~tree.isLoaded(node) to avoid re-loading nodes.
            % But that could end up with stale definitions. For now, just always
            % reload nodes, so user can refresh them by re-expanding.
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
        
        function out = rejectPackagesWithNoImmediateMembers(this, pkgNames)
            tf = true(size(pkgNames));
            for i = 1:numel(pkgNames)
                pkg = meta.package.fromName(pkgNames{i});
                tf(i) = ~isempty(pkg.ClassList) || ~isempty(pkg.FunctionList);
            end
            out = pkgNames(tf);
        end
        
        function out = buildChildNodes(this, node)
            out = {};
            nodeData = get(node, 'userdata');
            switch nodeData.type
                case 'root'
                    % NOP: Shouldn't get here
                case 'codepaths'
                    listMode = ifthen(this.flatPackageView, 'flat', 'nested');
                    found = scanCodeRoots(nodeData.paths, listMode);
                    if ~isempty(found.mfiles) || ~isempty(found.classdirs)
                        out{end+1} = this.codePathsGlobalsNode(nodeData.paths, found);
                    end
                    pkgs = sortCaseInsensitive(found.packages);
                    if this.flatPackageView
                        pkgs = this.rejectPackagesWithNoImmediateMembers(pkgs);
                    end
                    for i = 1:numel(pkgs)
                        out{end+1} = this.packageNode(pkgs{i}); %#ok<AGROW>
                    end
                case 'codepaths_globals'
                    [paths, found] = deal(nodeData.paths, nodeData.found);
                    % Ugh, now we have to scan the files to see if they're
                    % classes or functions
                    probed = scanCodeRootGlobals(paths, found);
                    if ~isempty(probed.classes)
                        out{end+1} = this.globalClassesNode(probed.classes);
                    end
                    if ~isempty(probed.functions)
                        out{end+1} = this.globalFunctionsNode(probed.functions);
                    end
                case 'global_classes'
                    classNames = nodeData.classNames;
                    for i = 1:numel(classNames)
                        out{end+1} = this.classNode(classNames{i}); %#ok<AGROW>
                    end
                case 'global_functions'
                    functionNames = nodeData.functionNames;
                    for i = 1:numel(functionNames)
                        out{end+1} = this.functionNode(functionNames{i}); %#ok<AGROW>
                    end
                case 'package'
                    pkg = meta.package.fromName(nodeData.packageName);
                    if ~this.flatPackageView
                        pkgList = sortDefnsByName(pkg.PackageList);
                        for i = 1:numel(pkgList)
                            out{end+1} = this.packageNode(pkgList(i).Name); %#ok<AGROW>
                        end
                    end
                    classList = sortDefnsByName(pkg.ClassList);
                    for i = 1:numel(classList)
                        out{end+1} = this.classNode(classList(i).Name); %#ok<AGROW>
                    end
                    functionList = sortDefnsByName(pkg.FunctionList);
                    for i = 1:numel(functionList)
                        % These are really methods, not functions (???)
                        out{end+1} = this.methodNode(functionList(i), nodeData.packageName); %#ok<AGROW>
                    end
                case 'class'
                    klass = meta.class.fromName(nodeData.className);
                    if ~isempty(this.maybeRejectHidden(...
                            rejectInheritedDefinitions(klass.PropertyList, klass)))
                        out{end+1} = this.propertyGroupNode(klass);
                    end
                    if ~isempty(this.maybeRejectHidden(...
                            rejectInheritedDefinitions(klass.MethodList, klass)))
                        out{end+1} = this.methodGroupNode(klass);
                    end
                    if ~isempty(this.maybeRejectHidden(...
                            rejectInheritedDefinitions(klass.EventList, klass)))
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
                    methodList = rejectInheritedDefinitions(defn.MethodList, defn);
                    methodList = sortDefnsByName(this.maybeRejectHidden(methodList));
                    for i = 1:numel(methodList)
                        % Hide well-known auto-defined methods
                        if isequal(methodList(i).Name, 'empty') && methodList(i).Static ...
                                && methodList(i).Hidden
                            continue;
                        end
                        pkgName = ifthen(isempty(defn.ContainingPackage), '', defn.ContainingPackage.Name);
                        out{end+1} = this.methodNode(methodList(i), pkgName); %#ok<AGROW>
                    end
                case 'propertyGroup'
                    defn = nodeData.parentDefinition;
                    propList = rejectInheritedDefinitions(defn.PropertyList, defn);
                    propList = sortDefnsByName(this.maybeRejectHidden(propList));
                    for i = 1:numel(propList)
                        out{end+1} = this.propertyNode(propList(i), defn); %#ok<AGROW>
                    end
                case 'eventGroup'
                    defn = nodeData.parentDefinition;
                    eventList = rejectInheritedDefinitions(defn.EventList, defn);
                    eventList = sortDefnsByName(this.maybeRejectHidden(eventList));
                    for i = 1:numel(eventList)
                        out{end+1} = this.eventNode(eventList(i)); %#ok<AGROW>
                    end
                case 'enumerationGroup'
                    defn = nodeData.parentDefinition;
                    enumList = sortDefnsByName(defn.EnumerationMemberList);
                    for i = 1:numel(enumList)
                        out{end+1} = this.enumerationNode(enumList(i)); %#ok<AGROW>
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
        
        function out = maybeRejectHidden(this, defns)
            if this.showHidden
                out = defns;
            else
                out = defns(~[defns.Hidden]);
            end
        end
        
        function treeMousePressed(this, hTree, eventData) %#ok<INUSL>
            % Mouse click callback
            
            %fprintf('mousePressed()\n');
            % Get the clicked node
            clickX = eventData.getX;
            clickY = eventData.getY;
            jtree = eventData.getSource;
            treePath = jtree.getPathForLocation(clickX, clickY);
            % This method of detecting right-clicks avoids confusion with Cmd-clicks on Mac
            isRightClick = eventData.getButton == java.awt.event.MouseEvent.BUTTON3;
            if isRightClick
                % Right-click
                if ~isempty(treePath)
                    node = treePath.getLastPathComponent;
                    nodeData = get(node, 'userdata');
                else
                    node = [];
                    nodeData = [];
                end
                jmenu = this.setupTreeContextMenu(node, nodeData);
                jmenu.show(jtree, clickX, clickY);
                jmenu.repaint;
                %TODO: Do I need to explicitly dispose of that JMenu?
            elseif eventData.getClickCount == 2
                % Double-click
                if isempty(treePath)
                    % Click was not on a node
                    return;
                end
                % Haven't decided on an action for double-click yet. Do nothing.
            end
        end
        
    end
end

function out = matlabPathInfo()
mlRoot = matlabroot;
paths = strsplit(path, pathsep);
tfSystem = strncmpi(paths, mlRoot, numel(mlRoot));
out.system = paths(tfSystem);
out.user = paths(~tfSystem);
end

function out = scanCodeRoots(paths, mode)
if nargin < 2 || isempty(mode); mode = 'nested'; end
assert(ismember(mode, {'nested','flat'}), 'Invalid mode: %s', mode);

paths = cellstr(paths);

allPackages = {};
allClassDirs = {};
allMfiles = {};
for iPath = 1:numel(paths)
    p = paths{iPath};
    if ~isdir(p)
        continue;
    end
    kids = dir(p);
    subdirNames = {kids([kids.isdir]).name};
    tfLooksLikePackage = ~cellfun(@isempty, regexp(subdirNames, '^\+\w+$'));
    packageNames = strrep(subdirNames(tfLooksLikePackage), '+', '');
    allPackages = [allPackages; packageNames(:)]; %#ok<AGROW>
    tfLooksLikeClassDir = ~cellfun(@isempty, regexp(subdirNames, '^@'));
    classDirNames = subdirNames(tfLooksLikeClassDir);
    allClassDirs = [allClassDirs; {p classDirNames(:)}]; %#ok<AGROW>
    kidFiles = {kids(~[kids.isdir]).name};
    tfMfile = ~cellfun(@isempty, regexpi(kidFiles, '\.m$'));
    mfiles = kidFiles(tfMfile);
    allMfiles = [allMfiles; {p mfiles(:)}]; %#ok<AGROW>
end

allPackages = unique(allPackages);

if isequal(mode, 'flat')
    allPackages = expandPackageListRecursively(allPackages);
end

out.packages = allPackages;
out.classdirs = allClassDirs;
out.mfiles = allMfiles;

end

function out = scanCodeRootGlobals(paths, found) %#ok<INUSL>
classNames = {};
functionNames = {};
for iRoot = 1:size(found.classdirs, 1)
    someClassNames = strrep(found.classdirs{iRoot,2}, '@', '');
    classNames = [classNames someClassNames(:)']; %#ok<AGROW>
end
for iRoot = 1:size(found.mfiles, 1)
    [codeRoot,mfiles] = found.mfiles{iRoot,:};
    for iFile = 1:numel(mfiles)
        [~,identifier,~] = fileparts(mfiles{iFile});
        filePath = [codeRoot '/' mfiles{iFile}];
        mfileType = probeMfileForType(filePath);
        switch mfileType
            case 'class'
                classNames{end+1} = identifier; %#ok<AGROW>
            case 'function'
                functionNames{end+1} = identifier; %#ok<AGROW>
            otherwise
                % Silently ignore; it's probably just a script
        end
    end
end
out.classes = sort(classNames);
out.functions = sort(functionNames);
end

function out = probeMfileForType(file)
[fid,msg] = fopen(file, 'r', 'n', 'UTF-8');
out = '';
if fid == -1
    warning('apj:mprojectnavigator:FileError', 'Could not read file %s: %s', ...
        file, msg);
    return;
end
RAII.fid = onCleanup(@() fclose(fid));
line = fgets(fid);
while ~isequal(line, -1)
    if strncmp(line, 'classdef ', 9)
        out = 'class';
    elseif strncmp(line, 'function ', 9)
        out = 'function';
    end
    line = fgets(fid);
end
end

function out = expandPackageListRecursively(names)
out = {};
for i = 1:numel(names)
    out = [out allSubpackagesUnderPackage(meta.package.fromName(names{i}))]; %#ok<AGROW>
end
end

function out = allSubpackagesUnderPackage(pkgDefn)
out = {pkgDefn.Name};
for i = 1:numel(pkgDefn.PackageList)
    out = [out allSubpackagesUnderPackage(pkgDefn.PackageList(i))]; %#ok<AGROW>
end
end

function ctxFlatPackageViewCallback(src, evd, this, nodeData) %#ok<INUSD,INUSL>
this.setFlatPackageView(src.isSelected);
end

function ctxShowHiddenCallback(src, evd, this, nodeData) %#ok<INUSD,INUSL>
this.setShowHidden(src.isSelected);
end

function ctxEditCallback(src, evd, this, nodeData) %#ok<INUSL>
switch nodeData.type
    case 'class'
        edit(nodeData.className);
    case 'function'
        edit(nodeData.functionName);
    case 'method'
        defn = nodeData.defn;
        klassDefn = defn.DefiningClass;
        if isempty(klassDefn)
            if isempty(nodeData.packageName)
                qualifiedName = defn.Name;
            else
                qualifiedName = [nodeData.packageName '.' defn.Name];
            end
        else
            qualifiedName = [klassDefn.Name '.' defn.Name];
        end
        edit(qualifiedName);
    otherwise
        % Shouldn't get here
        fprintf('Editing not supported for node type %s\n', nodeData.type);
end
end

function ctxViewDocCallback(src, evd, this, nodeData) %#ok<INUSL>
switch nodeData.type
    case 'class'
        doc(nodeData.className);
    case 'function'
        doc(nodeData.functionName);
    case {'method', 'property', 'event', 'enumeration'}
        defn = nodeData.defn;
        klassDefn = defn.DefiningClass;
        if isempty(klassDefn)
            if isempty(nodeData.packageName)
                qualifiedName = defn.Name;
            else
                qualifiedName = [nodeData.packageName '.' defn.Name];
            end
        else
            qualifiedName = [klassDefn.Name '.' defn.Name];
        end
        doc(qualifiedName);
    otherwise
        % Shouldn't get here
        fprintf('Editing not supported for node type %s\n', nodeData.type);
end
end

function ctxRevealInDesktopCallback(src, evd, this, nodeData) %#ok<INUSL>
switch nodeData.type
    case 'class'
        w = which(nodeData.className);
        if strfind(w, 'is a built-in')
            uiwait(errordlg({sprintf('Cannot reveal %s because it is a built-in', ...
                nodeData.className)}, 'Error'));
        else
            mprojectnavigator.internal.Utils.guiRevealFileInDesktopFileBrowser(w);
        end
    otherwise
        % NOP
end
end

function ctxFullyExpandNodeCallback(src, evd, this, node, nodeData) %#ok<INUSD,INUSL>
fprintf('ctxFullyExpandNodeCallback()\n');
this.expandNode(node, 'recurse');
end

function out = rejectInheritedDefinitions(defnList, parentDefn)
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

function out = sortDefnsByName(defns)
if isempty(defns)
    out = defns;
else
    [~,ix] = sort(lower({defns.Name}));
    out = defns(ix);
end
end

function out = sortCaseInsensitive(x)
[~,ix] = sort(lower(x));
out = x(ix);
end

