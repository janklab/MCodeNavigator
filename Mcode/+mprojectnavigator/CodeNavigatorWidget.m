classdef CodeNavigatorWidget < mprojectnavigator.TreeWidget
    % A navigator for Mcode definitions (packages/classes/functions)
    
    properties (Constant, Hidden)
        iconPath = [matlabroot '/toolbox/matlab/icons'];
    end
    
    properties (SetAccess = private)
        flatPackageView = false;
        showHidden = false;
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
            set(this.jTreeHandle, 'MousePressedCallback', {@treeMousePressed, this});
            
            this.completeRefreshGui;
        end
        
        function setFlatPackageView(this, newState)
        if newState == this.flatPackageView
            return;
        end
        this.flatPackageView = newState;
        this.completeRefreshGui;
        end
        
        function setShowHidden(this, newState)
        if newState == this.showHidden
            return;
        end
        this.showHidden = newState;
        this.completeRefreshGui;
        end
        
        function completeRefreshGui(this)
            root = this.rootTreenode();
            this.treePeer.setRoot(root);
            pause(0.005); % Allow widgets to catch up
            % Expand the root node one level, and expand the USER node
            this.expandNode(root, false);
            this.expandNode(root.getChildAt(0), false);
        end
        
        function out = setupTreeContextMenu(this, node, nodeData) %#ok<INUSL>
            import javax.swing.*
                        
            if      ismac;    fileShellName = 'Finder';
            elseif  ispc;     fileShellName = 'Windows Explorer';
            else;              fileShellName = 'File Browser';
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
                [isTargetClass,isTargetMethod,isTargetProperty,...
                    isTargetEvent,isTargetEnum] = deal(false);
            else
                isTargetClass = isequal(nd.type, 'class');
                isTargetMethod = isequal(nd.type, 'method');
                isTargetProperty = isequal(nd.type, 'property');
                isTargetEvent = isequal(nd.type, 'event');
                isTargetEnum = isequal(nd.type, 'enumeration');
            end
            isTargetEditable = isTargetClass || isTargetMethod;
            isTargetDocable = isTargetClass || isTargetMethod || isTargetProperty ...
                || isTargetEvent || isTargetEnum;
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
                    items{end+1} = lower(quals{i}); %#ok<AGROW>
                end
            end
            label = regexprep(strjoin(items, ' '), '  +', ' ');
            icon = myIconPath('dot');
            out = this.createNode(label, nodeData, false, icon);
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
                dummyNode = this.oldUitreenode('<dummy>', 'Loading...', icon, true);
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
                    listMode = ifthen(this.flatPackageView, 'flat', 'nested');
                    pkgs = listPackagesInCodeRoots(nodeData.paths, listMode);
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
                        out{end+1} = this.methodNode(pkg.FunctionList(i), nodeData.packageName); %#ok<AGROW>
                    end
                    if ~this.flatPackageView
                        for i = 1:numel(pkg.PackageList)
                            out{end+1} = this.packageNode(pkg.PackageList(i).Name); %#ok<AGROW>
                        end
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
                    methodList = this.maybeRejectHidden(methodList);
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
                    propList = this.maybeRejectHidden(propList);
                    for i = 1:numel(propList)
                        out{end+1} = this.propertyNode(propList(i), defn); %#ok<AGROW>
                    end
                case 'eventGroup'
                    defn = nodeData.parentDefinition;
                    eventList = rejectInheritedDefinitions(defn.EventList, defn);
                    eventList = this.maybeRejectHidden(eventList);
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
        
        function out = mlIconFile(this, name)
            out = [this.iconPath '/' name];            
        end
        
        function out = maybeRejectHidden(this, defns)
            if this.showHidden
                out = defns;
            else
                out = defns(~[defns.Hidden]);
            end
        end
        
        
        
    end
end

function treeMousePressed(hTree, eventData, this) %#ok<INUSL>
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
    node = treePath.getLastPathComponent;
    nodeData = get(node, 'userdata');
    if nodeData.isDummy
        return;
    end
    if ~nodeData.isDir
        % File node was double-clicked
        edit(nodeData.path);
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

function out = listPackagesInCodeRoots(paths, mode)
if nargin < 2 || isempty(mode); mode = 'nested'; end
assert(ismember(mode, {'nested','flat'}), 'Invalid mode: %s', mode);

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

if isequal(mode, 'flat')
    out = expandPackageListRecursively(out);
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

function nodeExpandedCallback(src, evd, this)
this.nodeExpanded(src, evd);
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
            mprojectnavigator.Utils.guiRevealFileInDesktopFileBrowser(w);
        end
    otherwise
        % NOP
end
end

function ctxFullyExpandNodeCallback(src, evd, this, node, nodeData)
fprintf('ctxFullyExpandNodeCallback()\n');
this.expandNode(node, true);
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

