classdef ClassesNavigatorWidget < mprojectnavigator.internal.TreeWidget
    % A navigator for Mcode definitions (packages/classes/functions)
    %
    % TODO: Get this to recognize newly-added/removed classes and update the
    % display.
    % BUG: Newly-added items might show up out-of-order with respect to their
    % siblings.
    % BUG: The isRefreshing detection doesn't seem to work. Maybe handles can't
    % be correctly stashed in UINode userdata? Or maybe the expansion events
    % queue up in a thread that's blocked while refresh is happening, so the
    % expansion request isn't even delivered until the initial refresh is done.
    % Hmm. The latter seems more likely, considering that the refreshNode() log
    % messages appear slowly when I do multiple refreshes on a slowly-loading
    % node.
    % TODO: Track package-privates in file map and support syncing/refreshing of
    % them.
    properties (SetAccess = private)
        flatPackageView = getpref(PREFGROUP, 'code_flatPackageView', false);
        showHidden = getpref(PREFGROUP, 'code_showHidden', false);
        navigator;
        % A Map<String,Node> of definition IDs to nodes in tree
        defnMap = java.util.HashMap;
        % A Map<File,Node> that tracks what nodes are backed by given files
        fileToNodeMap = java.util.HashMap;
    end
    
    methods
        function this = ClassesNavigatorWidget(parentNavigator)
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
            root = this.buildRootNode();
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
            menuItemRefresh = JMenuItem('Refresh');
            
            nd = nodeData;
            if isempty(nd)
                [isTargetClass,isTargetMethod,isTargetFunction,isTargetProperty,...
                    isTargetEvent,isTargetEnum,isFile] = deal(false);
            else
                isTargetClass = isequal(nd.type, 'class');
                isTargetMethod = isequal(nd.type, 'method');
                isTargetFunction = isequal(nd.type, 'function');
                isTargetProperty = isequal(nd.type, 'property');
                isTargetEvent = isequal(nd.type, 'event');
                isTargetEnum = isequal(nd.type, 'enumeration');
                isFile = nd.isFile;
            end
            isTargetEditable = isTargetClass || isTargetMethod || isTargetFunction ...
                || isTargetProperty || isTargetEnum || isFile;
            isTargetDocable = isTargetClass || isTargetMethod || isTargetProperty ...
                || isTargetEvent || isTargetEnum || isTargetFunction;
            isTargetRevealable = isTargetClass || isFile;
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
            setCallback(menuItemRefresh, {@ctxRefreshCallback, this})
            
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
            menuOptions.addSeparator;
            menuOptions.add(menuItemRefresh);
            jmenu.add(menuOptions);
            out = jmenu;
        end
        
        function registerNode(this, defn, node)
            this.defnMap.put(idForDefn(defn), node);
        end
        
        function deregisterNode(this, node)
            defn = get(node, 'userdata');
            this.defnMap.remove(idForDefn(defn));
        end
        
        function out = buildRootNode(this)
            nodeData = ClassesNodeData('root', 'root');
            out = this.oldUitreenode('<dummy>', 'Definitions', [], true);
            out.setAllowsChildren(true);
            set(out, 'userdata', nodeData);
            
            out.add(this.buildCodePathsNode('USER'));
            out.add(this.buildCodePathsNode('MATLAB'));
            nodeData.isPopulated = true;
        end
        
        function out = buildCodePathsNode(this, pathsType)
            % A node representing a codebase with a list of paths
            label = pathsType;
            nodeData = ClassesNodeData('codepaths', label);
            nodeData.pathsType = pathsType;
            icon = myIconPath('topfolder');
            out = this.createNode('codepaths', label, nodeData, [], icon);
        end
        
        function out = buildCodePathsGlobalsNode(this, paths, found)
            % A node representing global definitions under a codepath set
            nodeData = ClassesNodeData('codepaths_globals');
            nodeData.paths = paths;
            nodeData.found = found;
            icon = myIconPath('folder');
            out = this.createNode('<Global>', '<Global>', nodeData, [], icon);
        end
        
        function out = buildGlobalClassesNode(this, classNames)
            mustBeA(classNames, 'cellstr');
            nodeData = ClassesNodeData('global_classes');
            nodeData.classNames = sortCaseInsensitive(classNames);
            icon = myIconPath('folder');
            out = this.createNode('Classes', 'Classes', nodeData, [], icon);
        end
        
        function out = buildGlobalFunctionsNode(this, functionNames)
            mustBeA(functionNames, 'cellstr');
            nodeData = ClassesNodeData('global_functions');
            nodeData.functionNames = sortCaseInsensitive(functionNames);
            icon = myIconPath('folder');
            out = this.createNode('Functions', 'Functions', nodeData, [], icon);
        end
        
        function out = buildPackageNode(this, packageName)
            mustBeA(packageName, 'char');
            tag = ['+' packageName];
            nodeData = ClassesNodeData('package', packageName);
            nodeData.name = packageName;
            nodeData.basename = regexprep(packageName, '.*\.', '');
            icon = myIconPath('folder');
            out = this.createNode(tag, packageName, nodeData, [], icon);
            this.registerNode(nodeData, out);
        end
        
        function out = buildPackagePrivateNode(this, packageName)
            mustBeA(packageName, 'char');
            label = 'private';
            nodeData = ClassesNodeData('package_private', packageName);
            nodeData.package = packageName;
            icon = myIconPath('none');
            out = this.createNode('<pkgprivate>', label, nodeData, [], icon);
            this.registerNode(nodeData, out);
        end
        
        function out = buildErrorMessageNode(this, message)
            nodeData = ClassesNodeData('error_message');
            nodeData.label = message;
            icon = myIconPath('error');
            out = this.createNode(message, message, nodeData, false, icon);
        end
        
        function out = buildDummyNode(this)
            nodeData = ClassesNodeData('<dummy>');
            icon = myIconPath('none');
            out = this.createNode('<dummy>', 'Loading...', nodeData, false, icon);
        end
        
        function out = buildClassNode(this, className, showFqName)
            if nargin < 3 || isempty(showFqName);  showFqName = false;  end
            mustBeA(className, 'char');
            classBaseName = regexprep(className, '.*\.', '');
            nodeData = ClassesNodeData('class');
            nodeData.name = className;
            nodeData.basename = classBaseName;
            if showFqName
                label = ['@' className];
            else
                label = ['@' classBaseName];
            end
            out = this.createNode(label, label, nodeData);
            % Get ready for file change notifications: List the files that go in
            % to this class definition, and register them
            % Hack: for now, just register the constructor, and be sloppy about
            % 'which' output for builtins; they'll never change
            w = which(className);
            this.fileToNodeMap.put(w, out);
            this.registerNode(nodeData, out);
        end
        
        function out = buildPackagePrivateThingNode(this, name, path, key)
            nodeData = ClassesNodeData('package_private_thing', key);
            nodeData.basename = name;
            nodeData.path = path;
            nodeData.isFile = true;
            icon = myIconPath('none');
            out = this.createNode(key, name, nodeData, false, icon);
            this.registerNode(nodeData, out);
            this.fileToNodeMap.put(path, out);
        end
        
        function out = buildMethodGroupNode(this, parentDefinition)
            mustBeA(parentDefinition, 'meta.class');
            nodeData = ClassesNodeData('method_group');
            nodeData.definingClass = parentDefinition.Name;
            label = 'Methods';
            icon = myIconPath('none');
            out = this.createNode(label, label, nodeData, [], icon);
        end
        
        function out = buildMethodNode(this, defn, packageName)
            mustBeA(defn, 'meta.method');
            mustBeA(packageName, 'char');
            if isempty(defn.DefiningClass)
                fqName = ifthen(isempty(packageName), defn.Name, [packageName '.' defn.Name]);
            else
                fqName = [defn.DefiningClass.Name '.' defn.Name];
            end
            nodeData = ClassesNodeData('method', fqName);
            nodeData.basename = regexprep(defn.Name, '.*\.', '');
            nodeData.package = packageName;
            if isempty(defn.DefiningClass)
                nodeData.definingClass = [];
            else
                nodeData.definingClass = defn.DefiningClass.Name;
            end
            icon = myIconPath('dot');
            label = this.labelForMethod(defn);
            out = this.createNode(nodeData.basename, label, nodeData, false, icon);
            nodeData.isPopulated = true;
            this.registerNode(nodeData, out);
        end
        
        function out = buildFunctionNode(this, functionName)
            % Build function node
            % Only works for global functions, not functions inside a package
            mustBeA(functionName, 'char');
            nodeData = ClassesNodeData('function');
            nodeData.name = functionName;
            nodeData.basename = functionName;
            nodeData.package = [];
            icon = myIconPath('dot');
            out = this.createNode(functionName, functionName, nodeData, false, icon);
            this.registerNode(nodeData, out);
        end
        
        function out = buildPropertyGroupNode(this, parentDefinition)
            mustBeA(parentDefinition, 'meta.class');
            nodeData = ClassesNodeData('property_group');
            nodeData.definingClass = parentDefinition.Name;
            label = 'Properties';
            icon = myIconPath('none');
            out = this.createNode(label, label, nodeData, [], icon);
        end
        
        function out = buildPropertyNode(this, defn, klassDefn)
            mustBeA(defn, 'meta.property');
            nodeData = ClassesNodeData('property');
            nodeData.defn = defn;
            nodeData.basename = defn.Name;
            nodeData.name = [klassDefn.Name '.' defn.Name];
            nodeData.definingClass = klassDefn.Name;
            label = this.labelForProperty(defn, klassDefn);
            icon = myIconPath('dot');
            out = this.createNode(nodeData.basename, label, nodeData, false, icon);
            this.registerNode(nodeData, out);
        end
        
        function out = memberAccessLabel(~, accessDefn)
        if ischar(accessDefn)
            out = accessDefn;
        elseif iscell(accessDefn)
            s = cell(1, numel(accessDefn));
            for i = 1:numel(accessDefn)
                if ischar(accessDefn{i})
                    s{i} = accessDefn{i};
                elseif isa(accessDefn{i}, 'meta.class')
                    s{i} = accessDefn{i}.Name;
                else
                    error('Unrecognized Member Access definition type: %s', class(accessDefn{i}));
                end
            end
            out = strjoin(s, ', ');
        end
        end
        
        function out = labelForProperty(this, defn, klassDefn)
            mustBeA(defn, 'meta.property');
            mustBeA(klassDefn, 'meta.class');
            items = {};
            items{end+1} = defn.Name;
            getAccess = this.memberAccessLabel(defn.GetAccess);
            setAccess = this.memberAccessLabel(defn.SetAccess);
            if isequal(getAccess, setAccess)
                access = getAccess;
            else
                access = sprintf('%s/%s', getAccess, setAccess);
            end
            access = strrep(access, 'public', '');
            if ~isempty(access)
                access = ['[' access ']'];
            end
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
        
        function out = buildEventGroupNode(this, parentDefinition)
            mustBeA(parentDefinition, 'meta.class');
            nodeData = ClassesNodeData('event_group');
            nodeData.definingClass = parentDefinition.Name;
            label = 'Events';
            icon = myIconPath('none');
            out = this.createNode(label, label, nodeData, [], icon);
        end
        
        function out = buildEventNode(this, defn)
            mustBeA(defn, 'meta.event');
            nodeData = ClassesNodeData('event');
            nodeData.defn = defn;
            nodeData.basename = defn.Name;
            nodeData.name = defn.Name; % hack
            label = defn.Name;
            icon = myIconPath('dot');
            out = this.createNode(nodeData.basename, label, nodeData, false, icon);
            this.registerNode(nodeData, out);
        end
        
        function out = buildSuperclassGroupNode(this, parentDefinition)
            mustBeA(parentDefinition, 'meta.class');
            nodeData = ClassesNodeData('superclass_group');
            nodeData.type = 'superclass_group';
            nodeData.definingClass = parentDefinition.Name;
            superclassNames = metaObjNames(parentDefinition.SuperclassList);
            superclassBaseNames = regexprep(superclassNames, '.*\.', '');
            upwardThickArrow = char(hex2dec('21E7'));
            label = [upwardThickArrow ': ' strjoin(superclassBaseNames, ', ')];
            icon = myIconPath('none');
            out = this.createNode('Superclasses', label, nodeData, [], icon);
        end
        
        function out = buildEnumerationGroupNode(this, parentDefinition)
            mustBeA(parentDefinition, 'meta.class');
            nodeData = ClassesNodeData('enumeration_group');
            nodeData.definingClass = parentDefinition.Name;
            label = 'Enumerations';
            icon = myIconPath('none');
            out = this.createNode(label, label, nodeData, [], icon);
        end
        
        function out = buildEnumerationNode(this, defn)
            mustBeA(defn, 'meta.EnumeratedValue');
            nodeData = ClassesNodeData('enumeration');
            nodeData.defn = defn;
            nodeData.name = defn.Name;
            label = defn.Name;
            out = this.createNode(defn.Name, label, nodeData, false);
            this.registerNode(nodeData, out);
        end
        
        function out = createNode(this, tag, label, nodeData, allowsChildren, icon)
            if nargin < 5 || isempty(allowsChildren); allowsChildren = true; end
            if nargin < 6 || isempty(icon);  icon = [];  end
            
            out = this.oldUitreenode(tag, label, icon, true);
            out.setAllowsChildren(allowsChildren);
            set(out, 'userdata', nodeData);
            if allowsChildren
                out.add(this.buildDummyNode);
            end
        end
        
        function refreshNodeSingle(this, node)
            nodeData = get(node, 'userdata');
            switch nodeData.type
                case 'root'                     % NOP; its contents are static
                case 'codepaths';               this.refreshCodePathsNode(node);
                case 'codepaths_globals';       this.refreshCodePathsGlobalsNode(node);
                case 'global_classes';          this.refreshGlobalClassesNode(node);
                case 'global_functions';        this.refreshGlobalFunctionsNode(node);
                case 'package';                 this.refreshPackageNode(node);
                case 'class';                   this.refreshClassNode(node);
                case 'method_group';            this.refreshMethodGroupNode(node);
                case 'property_group';          this.refreshPropertyGroupNode(node);
                case 'event_group';             this.refreshEventGroupNode(node);
                case 'enumeration_group';       this.refreshEnumerationGroupNode(node);
                case 'superclass_group';        this.refreshSuperclassGroupNode(node);
                case 'package_private';         this.refreshPackagePrivateNode(node);
                case 'package_private_thing'    % NOP
                case 'error_message'            % NOP
                case 'method';                  this.refreshMethodNode(node);
                case 'function'                 % NOP
                case 'property';                this.refreshPropertyNode(node);
                case 'event'                    % NOP
                otherwise
                    refreshNodeSingle@mprojectnavigator.internal.TreeWidget(this, node);
            end
        end
        
        function markDirty(this, node)
            markDirty@mprojectnavigator.internal.TreeWidget(this, node);
            % Some node types need recursive dirtying
            nodeData = get(node, 'userdata');
            if ismember(nodeData.type, {'class','method_group','property_group',...
                    'event_group','enumeration_group'})
                for i = 1:node.getChildCount
                    this.markDirty(node.getChildAt(i-1));
                end
            end
        end
        
        function out = rejectPackagesWithNoImmediateMembers(this, pkgNames) %#ok<INUSL>
            tf = true(size(pkgNames));
            for i = 1:numel(pkgNames)
                pkg = meta.package.fromName(pkgNames{i});
                tf(i) = ~isempty(pkg.ClassList) || ~isempty(pkg.FunctionList);
            end
            out = pkgNames(tf);
        end
        
        function refreshPackageNode(this, node)
            nodeData = get(node, 'userdata');
            packageName = nodeData.name;
            childNodeValues = getChildNodeValues(node);
            nodesToAdd = {};
            nodesToAddValues = {};
            nodesToRemoveValues = {};
            pkg = meta.package.fromName(nodeData.name);
            pkgPrivateDirs = this.locatePrivateDirsForPackage(packageName);
            % Detect subpackages to add/remove
            if ~this.flatPackageView
                pkgList = sortDefnsByName(pkg.PackageList);
                subPkgNames = metaObjNames(pkgList);
                subPkgTags = strcat('+', subPkgNames);
                for i = 1:numel(pkgList)
                    pkgKey = ['+' pkgList(i).Name];
                    if ~ismember(pkgKey, childNodeValues)
                        nodesToAdd{end+1} = this.buildPackageNode(pkgList(i).Name); %#ok<AGROW>
                        nodesToAddValues{end+1} = pkgKey; %#ok<AGROW>
                    end
                end
                pkgChildNodeValues = selectRegexp(childNodeValues, '^+');
                pkgChildNodeValuesToRemove = setdiff(pkgChildNodeValues, subPkgTags);
                nodesToRemoveValues = [nodesToRemoveValues pkgChildNodeValuesToRemove];
            end
            % Detect classes to add/remove
            classList = sortDefnsByName(pkg.ClassList);
            classBasenames = regexprep(metaObjNames(classList), '.*\.', '');
            classValues = strcat('@', classBasenames);
            classChildNodeValues = selectRegexp(childNodeValues, '^@');
            ixToAdd = find(~ismember(classValues, childNodeValues));
            for i = 1:numel(ixToAdd)
                nodesToAdd{end+1} = this.buildClassNode(classList(i).Name); %#ok<AGROW>
                nodesToAddValues{end+1} = classBasenames{i}; %#ok<AGROW>
            end
            classChildNodeValuesToRemove = setdiff(classChildNodeValues, classValues);
            nodesToRemoveValues = [nodesToRemoveValues classChildNodeValuesToRemove];
            % Detect functions to add/remove
            functionList = sortDefnsByName(pkg.FunctionList);
            functionNames = metaObjNames(functionList);
            functionChildNodeValues = selectRegexp(childNodeValues, '^\w[^@+]');
            ixToAdd = find(~ismember(functionNames, functionChildNodeValues));
            for i = 1:numel(ixToAdd)
                ix = ixToAdd(i);
                nodesToAdd{end+1} = this.buildMethodNode(functionList(ix), packageName); %#ok<AGROW>
                nodesToAddValues{end+1} = functionNames{ix}; %#ok<AGROW>
            end
            functionChildNodeValuesToRemove = setdiff(functionChildNodeValues, functionNames);
            nodesToRemoveValues = [nodesToRemoveValues functionChildNodeValuesToRemove];
            if isempty(nodesToRemoveValues)
                % This isempty() check is needed to work around a weird edge
                % case with cell array expansion using "end+1"
                nodesToRemoveValues = {};
            end
            if isempty(pkgPrivateDirs)
                if ismember('<pkgprivate>', childNodeValues)
                    nodesToRemoveValues{end+1} = '<pkgprivate>';
                end
            else
                if ~ismember('<pkgprivate>', childNodeValues)
                    nodesToAdd{end+1} = this.buildPackagePrivateNode(packageName);
                end
            end
            % Remove dummy node
            if ismember('<dummy>', childNodeValues)
                nodesToRemoveValues{end+1} = '<dummy>';
            end
            % Do the adding and removal
            % TODO: Figure out how to insert new nodes in the right order WRT
            % existing nodes
            [~,ixNodesToRemove] = ismember(nodesToRemoveValues, childNodeValues);
            this.treePeer.remove(node, ixNodesToRemove-1);
            this.treePeer.add(node, [nodesToAdd{:}]);
        end
        
        function refreshClassNode(this, node)
            nodeData = get(node, 'userdata');
            klass = meta.class.fromName(nodeData.name);
            if isempty(klass)
                error('Failed getting class definition for class ''%s''', nodeData.name);
            end
            properties = this.maybeRejectHidden(...
                rejectInheritedDefinitions(klass.PropertyList, klass));
            methods = this.maybeRejectHidden(...
                rejectInheritedDefinitions(klass.MethodList, klass));
            events = this.maybeRejectHidden(...
                rejectInheritedDefinitions(klass.EventList, klass));
            enumerations = klass.EnumerationMemberList;
            superclasses = klass.SuperclassList;
            dummyNode = getChildNodeByValue(node, '<dummy>');
            if ~isempty(dummyNode)
                this.treePeer.remove(node, dummyNode);
            end
            % TODO: Figure out how to get the ordering right on these groups
            % when adding to an existing list. (cosmetic issue)
            % Superclasses
            child = getChildNodeByValue(node, 'Superclasses');
            if isempty(superclasses)
                if ~isempty(child)
                    this.treePeer.remove(node, child);
                end
            else
                if isempty(child)
                    this.treePeer.add(node, this.buildSuperclassGroupNode(klass));
                end
            end
            % Properties
            child = getChildNodeByValue(node, 'Properties');
            if isempty(properties)
                if ~isempty(child)
                    this.treePeer.remove(node, child);
                end
            else
                if isempty(child)
                    newPropertiesNode = this.buildPropertyGroupNode(klass);
                    this.treePeer.add(node, newPropertiesNode);
                    this.expandNode(newPropertiesNode);
                end
            end
            % Methods
            child = getChildNodeByValue(node, 'Methods');
            if isempty(methods)
                if ~isempty(child)
                    this.treePeer.remove(node, child);
                end
            else
                if isempty(child)
                    newMethodsNode = this.buildMethodGroupNode(klass);
                    this.treePeer.add(node, newMethodsNode);
                    this.expandNode(newMethodsNode);
                end
            end
            % Events
            child = getChildNodeByValue(node, 'Events');
            if isempty(events)
                if ~isempty(child)
                    this.treePeer.remove(node, child);
                end
            else
                if isempty(child)
                    this.treePeer.add(node, this.buildEventGroupNode(klass));
                end
            end
            % Enumerations
            child = getChildNodeByValue(node, 'Enumerations');
            if isempty(enumerations)
                if ~isempty(child)
                    this.treePeer.remove(node, child);
                end
            else
                if isempty(child)
                    this.treePeer.add(node, this.buildEnumerationGroupNode(klass));
                end
            end
        end
        
        function refreshCodePathsNode(this, node)
            nodeData = get(node, 'userdata');
            pathsType = nodeData.pathsType;
            pathInfo = mprojectnavigator.internal.CodeBase.matlabPathInfo();
            switch pathsType
                case 'USER'
                    paths = pathInfo.user;
                case 'MATLAB'
                    paths = pathInfo.system;
                otherwise
                    error('Invalid pathsType: %s', pathsType);
            end
            listMode = ifthen(this.flatPackageView, 'flat', 'nested');
            found = scanCodeRoots(paths, listMode);
            % "Globals" node
            globalsNode = getChildNodeByValue(node, '<Global>');
            if ~isempty(found.mfiles) || ~isempty(found.classdirs)
                if isempty(globalsNode)
                    globalsNode = this.buildCodePathsGlobalsNode(paths, found);
                    this.treePeer.insert(node, globalsNode, 0);
                end
            else
                if ~isempty(globalsNode)
                    this.treePeer.remove(node, globalsNode);
                end
            end
            % Package nodes
            pkgs = sortCaseInsensitive(found.packages);
            childNodeValues = getChildNodeValues(node);
            nodesToAdd = {};
            if this.flatPackageView
                pkgs = this.rejectPackagesWithNoImmediateMembers(pkgs);
            end
            childNodePkgNames = strrep(setdiff(childNodeValues, {'<Global>','<dummy>'}), '+', '');
            pkgsToAdd = sortCaseInsensitive(setdiff(pkgs, childNodePkgNames));
            pkgsToRemove = setdiff(childNodePkgNames, pkgs);
            [~,ixToRemove] = ismember(strcat('+',pkgsToRemove), childNodeValues);
            % Handle dummy node
            [tf,ixDummy] = ismember('<dummy>', childNodeValues);
            if tf
                ixToRemove(end+1) = ixDummy;
            end
            ixToRemove = sort(ixToRemove);
            % Do the add/removes
            for i = 1:numel(pkgsToAdd)
                nodesToAdd{end+1} = this.buildPackageNode(pkgsToAdd{i}); %#ok<AGROW>
            end
            this.treePeer.remove(node, ixToRemove-1);
            this.treePeer.add(node, [nodesToAdd{:}]);
        end
        
        function refreshCodePathsGlobalsNode(this, node)
            nodeData = get(node, 'userdata');
            [paths, found] = deal(nodeData.paths, nodeData.found);
            % Ugh, now we have to scan the files to see if they're classes or
            % functions
            probed = scanCodeRootGlobals(paths, found);
            
            classesNode = getChildNodeByValue(node, 'Classes');
            if isempty(probed.classes)
                if ~isempty(classesNode)
                    this.treePeer.remove(node, classesNode);
                end
            else
                if isempty(classesNode)
                    this.treePeer.add(node, this.buildGlobalClassesNode(probed.classes));
                end
            end
            functionsNode = getChildNodeByValue(node, 'Functions');
            if isempty(probed.functions)
                if ~isempty(functionsNode)
                    this.treePeer.remove(node, functionsNode);
                end
            else
                if isempty(functionsNode)
                    this.treePeer.add(node, this.buildGlobalFunctionsNode(probed.functions));
                end
            end
            dummyNode = getChildNodeByValue(node, '<dummy>');
            if ~isempty(dummyNode)
                this.treePeer.remove(node, dummyNode);
            end
        end
        
        function refreshGlobalClassesNode(this, node)
            nodeData = get(node, 'userdata');
            classNames = sortCaseInsensitive(nodeData.classNames);
            % This node's data is static, so we can just do the simple initial-population case
            dummyNode = getChildNodeByValue(node, '<dummy>');
            if ~isempty(dummyNode)
                nodesToAdd = {};
                for i = 1:numel(classNames)
                    nodesToAdd{end+1} = this.buildClassNode(classNames{i}); %#ok<AGROW>
                end
                this.treePeer.remove(node, dummyNode);
                this.treePeer.add(node, [nodesToAdd{:}]);
            end
        end
        
        function refreshGlobalFunctionsNode(this, node)
            nodeData = get(node, 'userdata');
            functionNames = sortCaseInsensitive(nodeData.functionNames);
            % This node's data is static, so we can just do the simple initial-population case
            dummyNode = getChildNodeByValue(node, '<dummy>');
            if ~isempty(dummyNode)
                nodesToAdd = {};
                for i = 1:numel(functionNames)
                    nodesToAdd{end+1} = this.buildFunctionNode(functionNames{i}); %#ok<AGROW>
                end
                this.treePeer.remove(node, dummyNode);
                this.treePeer.add(node, [nodesToAdd{:}]);
            end
        end
        
        function refreshPackagePrivateNode(this, node)
            % Refresh package-private node
            %
            % This implementation is incomplete: private dirs can have many
            % types of things, and I'm only supporting a couple types for now.
            nodeData = get(node, 'userdata');
            packageName = nodeData.package;
            % Re-scan directories every time, because they might change, and I
            % don't want to do differential logic in the package node refresh
            dirs = this.locatePrivateDirsForPackage(packageName);
            % Merge all the dir contents into a single display
            % c is { key, type, name, path; ... }
            c = {};
            types = {'m' 'mlapp' 'mat' 'mex' 'mdl' 'slx' 'p' 'classes' 'packages'};
            for iDir = 1:numel(dirs)
                w = what(dirs{iDir});
                for iType = 1:numel(types)
                    type = types{iType};
                    filePaths = fullfile(dirs{iDir}, w.(type));
                    c = [c; [strcat(type,{':'},filePaths) repmat({type},size(w.(type))) ...
                        w.(type) filePaths]]; %#ok<AGROW>
                end
            end
            [~,ix] = sortCaseInsensitive(c(:,3));
            c = c(ix,:);
            childNodeValues = getChildNodeValues(node);
            [~,ixToAdd] = setdiff(c(:,1), childNodeValues);
            [~,ixToRemove] = setdiff(childNodeValues, c(:,1));
            nodesToAdd = {};
            for i = 1:numel(ixToAdd)
                ix = ixToAdd(i);
                nodesToAdd{i} = this.buildPackagePrivateThingNode(c{ix,3}, c{ix,4}, c{ix,1}); %#ok<AGROW>
                nodesToAdd{i}.UserData.isFile = true; %#ok<AGROW>
            end
            
            this.treePeer.remove(node, ixToRemove-1);
            this.treePeer.add(node, [nodesToAdd{:}]);
        end
        
        function refreshMethodGroupNode(this, node)
            nodeData = get(node, 'userdata');
            childNodeValues = getChildNodeValues(node);
            nodesToAdd = {};
            classDefn = meta.class.fromName(nodeData.definingClass);
            if isempty(classDefn.ContainingPackage)
                pkgName = '';
            else
                pkgName = classDefn.ContainingPackage.Name;
            end
            defnList = rejectInheritedDefinitions(classDefn.MethodList, classDefn);
            defnList = sortDefnsByName(this.maybeRejectHidden(defnList));
            % Hide well-known auto-defined methods
            for i = numel(defnList):-1:1
                if isequal(defnList(i).Name, 'empty') && defnList(i).Static ...
                        && defnList(i).Hidden
                    defnList(i) = [];
                end
            end
            
            defnNames = metaObjNames(defnList);
            childDefnNames = setdiff(childNodeValues, '<dummy>');
            defnsToAdd = sortCaseInsensitive(setdiff(defnNames, childDefnNames));
            defnsToRemove = setdiff(childDefnNames, defnNames);
            [~,ixToRemove] = ismember(defnsToRemove, childNodeValues);
            [~,loc] = ismember(defnsToAdd, defnNames);
            for i = 1:numel(defnsToAdd)
                nodesToAdd{end+1} = this.buildMethodNode(defnList(loc(i)), pkgName); %#ok<AGROW>
            end
            % Handle dummy node
            [tf,ixDummy] = ismember('<dummy>', childNodeValues);
            if tf
                ixToRemove(end+1) = ixDummy;
            end
            
            this.treePeer.remove(node, ixToRemove-1);
            this.treePeer.add(node, [nodesToAdd{:}]);
            nodeData.isPopulated = true;
        end
        
        function refreshPropertyGroupNode(this, node)
            nodeData = get(node, 'userdata');
            childNodeValues = getChildNodeValues(node);
            nodesToAdd = {};
            classDefn = meta.class.fromName(nodeData.definingClass);
            defnList = rejectInheritedDefinitions(classDefn.PropertyList, classDefn);
            defnList = sortDefnsByName(this.maybeRejectHidden(defnList));
            
            defnNames = metaObjNames(defnList);
            childDefnNames = setdiff(childNodeValues, '<dummy>');
            defnsToAdd = sortCaseInsensitive(setdiff(defnNames, childDefnNames));
            defnsToRemove = setdiff(childDefnNames, defnNames);
            [~,ixToRemove] = ismember(defnsToRemove, childNodeValues);
            [~,loc] = ismember(defnsToAdd, defnNames);
            for i = 1:numel(defnsToAdd)
                nodesToAdd{end+1} = this.buildPropertyNode(defnList(loc(i)), classDefn); %#ok<AGROW>
            end
            % Handle dummy node
            [tf,ixDummy] = ismember('<dummy>', childNodeValues);
            if tf
                ixToRemove(end+1) = ixDummy;
            end
            
            this.treePeer.remove(node, ixToRemove-1);
            this.treePeer.add(node, [nodesToAdd{:}]);
        end
        
        function refreshEventGroupNode(this, node)
            nodeData = get(node, 'userdata');
            childNodeValues = getChildNodeValues(node);
            nodesToAdd = {};
            classDefn = meta.class.fromName(nodeData.definingClass);
            defnList = rejectInheritedDefinitions(classDefn.EventList, classDefn);
            defnList = sortDefnsByName(this.maybeRejectHidden(defnList));
            
            defnNames = metaObjNames(defnList);
            childDefnNames = setdiff(childNodeValues, '<dummy>');
            defnsToAdd = sortCaseInsensitive(setdiff(defnNames, childDefnNames));
            defnsToRemove = setdiff(childDefnNames, defnNames);
            [~,ixToRemove] = ismember(defnsToRemove, childNodeValues);
            [~,loc] = ismember(defnsToAdd, defnNames);
            for i = 1:numel(defnsToAdd)
                nodesToAdd{end+1} = this.buildEventNode(defnList(loc(i))); %#ok<AGROW>
            end
            % Handle dummy node
            [tf,ixDummy] = ismember('<dummy>', childNodeValues);
            if tf
                ixToRemove(end+1) = ixDummy;
            end
            
            this.treePeer.remove(node, ixToRemove-1);
            this.treePeer.add(node, [nodesToAdd{:}]);
        end
        
        function refreshEnumerationGroupNode(this, node)
            nodeData = get(node, 'userdata');
            classDefn = meta.class.fromName(nodeData.definingClass);
            childNodeValues = getChildNodeValues(node);
            nodesToAdd = {};
            defnList = sortDefnsByName(classDefn.EnumerationMemberList);
            
            defnNames = metaObjNames(defnList);
            childDefnNames = setdiff(childNodeValues, '<dummy>');
            defnsToAdd = sortCaseInsensitive(setdiff(defnNames, childDefnNames));
            defnsToRemove = setdiff(childDefnNames, defnNames);
            [~,ixToRemove] = ismember(defnsToRemove, childNodeValues);
            [~,loc] = ismember(defnsToAdd, defnNames);
            for i = 1:numel(defnsToAdd)
                nodesToAdd{end+1} = this.buildEnumerationNode(defnList(loc(i))); %#ok<AGROW>
            end
            % Handle dummy node
            [tf,ixDummy] = ismember('<dummy>', childNodeValues);
            if tf
                ixToRemove(end+1) = ixDummy;
            end
            
            this.treePeer.remove(node, ixToRemove-1);
            this.treePeer.add(node, [nodesToAdd{:}]);
        end
        
        function refreshMethodNode(this, node)
            nodeData = get(node, 'userdata');
            if isempty(nodeData.definingClass)
                pkgDefn = meta.package.fromName(nodeData.package);
                parentMethodList = pkgDefn.FunctionList;
                parentDescr = sprintf('package %s', nodeData.package);
            else
                klassDefn = meta.class.fromName(nodeData.definingClass);
                parentMethodList = klassDefn.MethodList;
                parentDescr = sprintf('class %s', nodeData.definingClass);
            end
            defn = [];
            for i = 1:numel(parentMethodList)
                if isequal(parentMethodList(i).Name, nodeData.basename)
                    defn = parentMethodList(i);
                    break;
                end
            end
            if isempty(defn)
                error('Could not find method definition for %s in %s', ...
                    nodeData.basename, parentDescr);
            end
            label = this.labelForMethod(defn);
            node.setName(label);
            if ~isequal(label, node.getName)
                this.setNodeName(node, label);
            end
            nodeData.isPopulated = true;
        end
        
        function refreshPropertyNode(this, node)
            nodeData = get(node, 'nodedata');
            klassDefn = meta.class.fromName(nodeData.definingClass);
            defn = getMetaDefnByName(klassDefn.MethodList, nodeData.basename);
            label = this.labelForProperty(defn, klassDefn);
            if ~isequal(label, node.getName)
                logdebugf('New property label: %s', label);
                this.setNodeName(node, label);
            else
                logdebugf('Keeping existing property label: %s', label);
            end
        end
        
        function out = labelForMethod(this, defn)
            inputArgStr = ifthen(isequal(defn.InputNames, {'rhs1'}), '...', ...
                strjoin(defn.InputNames, ', '));
            baseLabel = sprintf('%s (%s)', defn.Name, inputArgStr);
            items = {baseLabel};
            if ~isempty(defn.OutputNames) && ~isequal(defn.OutputNames, {'lhs1'})
                items{end+1} = sprintf(':[%s]', strjoin(defn.OutputNames, ', '));
            end
            items(cellfun(@isempty, items)) = [];
            if ~isequal(defn.Access, 'public')
                items{end+1} = this.memberAccessLabel(defn.Access);
            end
            quals = {'Static' 'Abstract' 'Sealed' 'Hidden'};
            for i = 1:numel(quals)
                if defn.(quals{i})
                    items{end+1} = lower(quals{i}); %#ok<AGROW>
                end
            end
            label = regexprep(strjoin(items, ' '), '  +', ' ');
            out = label;
        end
        
        function refreshSuperclassGroupNode(this, node)
            nodeData = get(node, 'userdata');
            classDefn = meta.class.fromName(nodeData.definingClass);
            childNodeValues = getChildNodeValues(node);
            nodesToAdd = {};
            % Do not sort the list in this case! Order of inheritance is
            % significant, so preserve it. (I assume that SuperclassList is in
            % inheritance order; and a couple tests I did support that.)
            defnList = classDefn.SuperclassList;
            
            defnNames = metaObjNames(defnList);
            childDefnNames = setdiff(childNodeValues, '<dummy>');
            defnsToAdd = setdiff(defnNames, childDefnNames, 'stable');
            defnsToRemove = setdiff(childDefnNames, defnNames);
            [~,ixToRemove] = ismember(defnsToRemove, childNodeValues);
            [~,loc] = ismember(defnsToAdd, defnNames);
            for i = 1:numel(defnsToAdd)
                nodesToAdd{end+1} = this.buildClassNode(defnList(loc(i)).Name, true); %#ok<AGROW>
            end
            % Handle dummy node
            [tf,ixDummy] = ismember('<dummy>', childNodeValues);
            if tf
                ixToRemove(end+1) = ixDummy;
            end
            
            this.treePeer.remove(node, ixToRemove-1);
            this.treePeer.add(node, [nodesToAdd{:}]);
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
                editNode(this, nodeData);
            end
        end
        
        function revealDefn(this, defn, file)
            % Reveal the node for a given definition
            
            % Fast path: look up by file
            if ~isempty(file) && this.fileToNodeMap.containsKey(file)
                logdebugf('revealDefn: fast path by file: %s', file);
                defnNode = this.fileToNodeMap.get(file);
            elseif isempty(defn)
                % Ignore empty definitions. That means it's a file outside of
                % our code base. Or it's a function in a private/ folder, which
                % we can't currently see.
                logdebugf('revealDefn: ignoring empty definition: %s', file);
                return;
            else
                id = idForDefn(defn);
                node = this.defnMap.get(id);
                if ~isempty(node)
                    % Easy case: the node already exists
                    logdebugf('revealDefn: fast path by id: %s', file);
                    defnNode = node;
                else
                    % Hard case: we may need to start at the top and expand nodes in
                    % order to vivify the node for this definition
                    logdebugf('revealDefn: hard path: %s', file);
                    root = this.treePeer.getRoot;
                    scopeNodeName = ifthen(isequal(defn.scope, 'system'), 'MATLAB', 'USER');
                    scopeNode = getChildNodeByName(root, scopeNodeName);
                    this.populateNode(scopeNode);
                    if ~isequal(defn.type, 'package') && isempty(defn.package)
                        parentNode = getChildNodeByName(scopeNode, '<Global>');
                        this.refreshNode(parentNode, {'force','populate'});
                    else
                        parentNode = scopeNode;
                        this.refreshNode(parentNode, {'force','populate'});
                        if this.flatPackageView
                            if ~isempty(defn.package)
                                parentNode = getChildNodeByName(scopeNode, ['+' defn.package]);
                                this.refreshNode(parentNode, {'force','populate'});
                            end
                        else
                            pkgParts = strsplit(defn.package, '.');
                            for i = 1:numel(pkgParts)
                                nextPackageDown = ['+' strjoin(pkgParts(1:i), '.')];
                                nextParentNode = getChildNodeByName(parentNode, nextPackageDown);
                                if isempty(nextParentNode)
                                    logwarnf('Definition not found in code base: missing parent package for %s', ...
                                        defn.name);
                                    return;
                                end
                                parentNode = nextParentNode;
                                this.refreshNode(parentNode, {'force','populate'});
                            end
                        end
                    end
                    if isequal(defn.type, 'function')
                        groupNode = getChildNodeByName(parentNode, 'Functions');
                        this.refreshNode(groupNode, {'force','populate'});
                        defnNode = getChildNodeByName(groupNode, defn.basename);
                    elseif isequal(defn.type, 'class')
                        % Parent node was populated, so this node should exist now
                        defnNode = this.defnMap.get(id);
                    elseif isequal(defn.type, 'method') && ...
                            (~isfield(defn, 'definingClass') || isempty(defn.definingClass))
                        % Package functions. Same as with class; parent was
                        % populated
                        defnNode = this.defnMap.get(id);
                    else
                        switch defn.type
                            case 'method';    groupName = 'Methods';
                            case 'property';  groupName = 'Properties';
                            otherwise
                                % Other types won't be passed in to this method.
                                error('Unrecognized defn.type: %s', defn.type);
                        end
                        groupNode = getChildNodeByName(parentNode, groupName);
                        this.refreshNode(groupNode, {'force','populate'});
                        defnNode = this.defnMap.get(id);
                    end
                end
            end
            if isempty(defnNode)
                % This is not a warning; it can happen when there's an invalid
                % definition in user code. Ignore.
                logdebugf('Definition node did not populate as expected: %s', id);
                return;
            end
            parent = defnNode.getParent;
            this.expandNode(parent);
            this.setSelectedNode(defnNode);
            this.scrollToNode(defnNode);
        end
        
        function fileChanged(this, file)
            % File-changed callback
            if this.fileToNodeMap.containsKey(file)
                node = this.fileToNodeMap.get(file);
                this.markDirty(node);
                this.refreshNode(node);
            end
        end
        
        function out = locatePrivateDirsForPackage(this, packageName) %#ok<INUSL>
            % Locate private/ source directories for class
            % Matlab's metaclasses don't provide this, so we need to scan the
            % path
            pkgPathEls = strcat('+', strsplit(packageName, '.'));
            pkgRelPath = fullfile(pkgPathEls{:});
            roots = strsplit(path, pathsep);
            out = {};
            for i = 1:numel(roots)
                pkgPrivatePath = fullfile(roots{i}, pkgRelPath, 'private');
                if isFolder(pkgPrivatePath)
                    out{end+1} = pkgPrivatePath; %#ok<AGROW>
                end
            end
        end
    end
end

function [out,i] = getChildNodeByName(node, name)
out = [];
for i = 1:node.getChildCount
    child = node.getChildAt(i-1);
    if isequal(char(child.getName), name)
        out = child;
        return
    end
end
end

function [out,i] = getChildNodeByValue(node, value)
out = [];
for i = 1:node.getChildCount
    child = node.getChildAt(i-1);
    if isequal(char(child.getValue), value)
        out = child;
        return
    end
end
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

function editNode(~, nodeData)
switch nodeData.type
    case 'class'
        edit(nodeData.name);
    case 'function'
        edit(nodeData.name);
    case 'method'
        className = nodeData.definingClass;
        if isempty(className)
            if isempty(nodeData.package)
                qualifiedName = nodeData.basename;
            else
                qualifiedName = [nodeData.package '.' nodeData.basename];
            end
        else
            qualifiedName = [className '.' nodeData.basename];
        end
        edit(qualifiedName);
    case {'property','event','enumeration'}
        className = nodeData.definingClass;
        qualifiedName = [className '.' nodeData.basename];
        edit(qualifiedName);
    otherwise
        if nodeData.isFile
            edit(nodeData.path);
        else
            % Shouldn't get here
            logerrorf('Editing is not supported for node type %s', nodeData.type);
        end
end
end

function ctxEditCallback(src, evd, this, nodeData) %#ok<INUSL>
editNode(this, nodeData);
end

function ctxViewDocCallback(src, evd, this, nodeData) %#ok<INUSL>
switch nodeData.type
    case 'class'
        doc(nodeData.name);
    case 'function'
        doc(nodeData.functionName);
    case {'method', 'property', 'event', 'enumeration'}
        pkg = nodeData.package;
        className = nodeData.definingClass;
        if isempty(className)
            pName = nodeData.basename;
        else
            pName = [className '.' nodeData.basename];
        end
        if isempty(pkg)
            qualifiedName = pName;
        else
            qualifiedName = [pkg '.' pName];
        end
        doc(qualifiedName);
    otherwise
        % Shouldn't get here
        logerrorf('Doc viewing is not supported for node type %s', nodeData.type);
end
end

function ctxRevealInDesktopCallback(src, evd, this, nodeData) %#ok<INUSL>
if isequal(nodeData.type, 'class')
    w = which(nodeData.name);
    if strfind(w, 'is a built-in')
        uiwait(errordlg({sprintf('Cannot reveal %s because it is a built-in', ...
            nodeData.name); ''; 'Sorry.'}, 'Error'));
    else
        mprojectnavigator.internal.Utils.guiRevealFileInDesktopFileBrowser(w);
    end
elseif (nodeData.isFile)
    mprojectnavigator.internal.Utils.guiRevealFileInDesktopFileBrowser(nodeData.path);
else
    % NOP
end
end

function ctxFullyExpandNodeCallback(src, evd, this, node, nodeData) %#ok<INUSD,INUSL>
this.expandNode(node, 'recurse');
end

function ctxRefreshCallback(src, evd, this) %#ok<INUSL>
this.gentleRecursiveRefresh(this.treePeer.getRoot);
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

function out = idForDefn(defn)
out = sprintf('%s:%s', defn.type, defn.name);
end

function out = matchesRegexp(strs, pattern)
out = ~cellfun(@isempty, regexp(strs, pattern, 'once'));
end

function out = selectRegexp(strs, pattern)
out = strs(matchesRegexp(strs, pattern));
end

function out = metaObjNames(defns)
if isempty(defns)
    out = {};
else
    out = {defns.Name};
end
end

function out = getMetaDefnByName(defnList, name)
for i = 1:numel(defnList)
    if isequal(defnList(i).Name, name)
        out = defnList(i);
        return;
    end
end
error('Could not find thing named ''%s'' in metadata definition list', name);
end
