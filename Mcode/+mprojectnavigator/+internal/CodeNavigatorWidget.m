classdef CodeNavigatorWidget < mprojectnavigator.internal.TreeWidget
    % A navigator for Mcode definitions (packages/classes/functions)
    %
    % TODO: Get this to recognize newly-added/removed classes and update the
    % display.
    properties (SetAccess = private)
        flatPackageView = getpref(PREFGROUP, 'code_flatPackageView', false);
        showHidden = getpref(PREFGROUP, 'code_showHidden', false);
        navigator;
        % A Map<String,Node> of definition IDs to nodes in tree
        defnMap = java.util.HashMap;
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
            root = this.buildRootTreenode();
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
        
        function registerNode(this, defn, node)
            this.defnMap.put(idForDefn(defn), node);
        end
        
        function deregisterNode(this, node)
            defn = get(node, 'userdata');
            this.defnMap.remove(idForDefn(defn));
        end
                
        function out = buildRootTreenode(this)
            nodeData.type = 'root';
            out = this.oldUitreenode('<dummy>', 'Definitions', [], true);
            out.setAllowsChildren(true);
            set(out, 'userdata', nodeData);
            
            pathInfo = mprojectnavigator.internal.CodeBase.matlabPathInfo();
            out.add(this.buildCodePathsNode('USER', pathInfo.user));
            out.add(this.buildCodePathsNode('MATLAB', pathInfo.system));
        end
        
        function out = buildCodePathsNode(this, label, paths)
            % A node representing a codebase with a list of paths
            nodeData.type = 'codepaths';
            nodeData.label = label;
            nodeData.paths = paths;
            icon = myIconPath('topfolder');
            out = this.createNode('codepaths', label, nodeData, [], icon);
        end
        
        function out = buildCodePathsGlobalsNode(this, paths, found)
            % A node representing global definitions under a codepath set
            nodeData.type = 'codepaths_globals';
            nodeData.paths = paths;
            nodeData.found = found;
            icon = myIconPath('folder');
            out = this.createNode('<Global>', '<Global>', nodeData, [], icon);
        end
        
        function out = buildGlobalClassesNode(this, classNames)
            nodeData.type = 'global_classes';
            nodeData.classNames = classNames;
            icon = myIconPath('folder');
            out = this.createNode('Classes', 'Classes', nodeData, [], icon);
        end
        
        function out = buildGlobalFunctionsNode(this, functionNames)
            nodeData.type = 'global_functions';
            nodeData.functionNames = functionNames;
            icon = myIconPath('folder');
            out = this.createNode('Functions', 'Functions', nodeData, [], icon);
        end
        
        function out = buildPackageNode(this, packageName)
            label = ['+' packageName];
            nodeData.type = 'package';
            nodeData.name = packageName;
            nodeData.basename = regexprep(packageName, '.*\.', '');
            icon = myIconPath('folder');
            out = this.createNode(label, label, nodeData, [], icon);
            this.registerNode(nodeData, out);
        end
        
        function out = buildClassNode(this, className)
            classBaseName = regexprep(className, '.*\.', '');
            nodeData.type = 'class';
            nodeData.name = className;
            nodeData.basename = classBaseName;
            label = ['@' classBaseName];
            out = this.createNode(label, label, nodeData);
            this.registerNode(nodeData, out);
        end
        
        function out = buildMethodGroupNode(this, parentDefinition)
            nodeData.type = 'methodGroup';
            nodeData.parentDefinition = parentDefinition;
            label = 'Methods';
            icon = myIconPath('none');
            out = this.createNode(label, label, nodeData, [], icon);
        end
        
        function out = buildMethodNode(this, defn, packageName)
            mustBeA(defn, 'meta.method');
            nodeData.type = 'method';
            nodeData.defn = defn;
            nodeData.name = ifthen(isempty(packageName), defn.Name, [packageName '.' defn.Name]);
            nodeData.basename = regexprep(defn.Name, '.*\.', '');
            nodeData.package = packageName;
            if isempty(defn.DefiningClass)
                nodeData.definingClass = [];
            else
                nodeData.definingClass = defn.DefiningClass.Name;
            end
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
            out = this.createNode(nodeData.basename, label, nodeData, false, icon);
            this.registerNode(nodeData, out);
        end
        
        function out = buildFunctionNode(this, functionName)
            % Build function node
            % Only works for global functions, not functions inside a package
            nodeData.type = 'function';
            nodeData.name = functionName;
            nodeData.basename = functionName;
            nodeData.package = [];
            icon = myIconPath('dot');
            out = this.createNode(functionName, functionName, nodeData, false, icon);
            this.registerNode(nodeData, out);
        end
        
        function out = buildPropertyGroupNode(this, parentDefinition)
            nodeData.type = 'propertyGroup';
            nodeData.parentDefinition = parentDefinition;
            label = 'Properties';
            icon = myIconPath('none');
            out = this.createNode(label, label, nodeData, [], icon);
        end
        
        function out = buildPropertyNode(this, defn, klassDefn)
            mustBeA(defn, 'meta.property');
            nodeData.type = 'property';
            nodeData.defn = defn;
            nodeData.basename = defn.Name;
            nodeData.name = [klassDefn.Name '.' defn.Name];
            label = this.propertyLabel(defn, klassDefn);
            icon = myIconPath('dot');
            out = this.createNode(nodeData.basename, label, nodeData, false, icon);
            this.registerNode(nodeData, out);
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
        
        function out = buildEventGroupNode(this, parentDefinition)
            nodeData.type = 'eventGroup';
            nodeData.parentDefinition = parentDefinition;
            label = 'Events';
            icon = myIconPath('none');
            out = this.createNode(label, label, nodeData, [], icon);
        end
        
        function out = buildEventNode(this, defn)
            mustBeA(defn, 'meta.event');
            nodeData.type = 'event';
            nodeData.defn = defn;
            nodeData.basename = defn.Name;
            nodeData.name = defn.Name; % hack
            label = defn.Name;
            icon = myIconPath('dot');
            out = this.createNode(nodeData.basename, label, nodeData, false, icon);
            this.registerNode(nodeData, out);
        end
        
        function out = buildSuperclassGroupNode(this, parentDefinition)
            nodeData.type = 'superclassGroup';
            nodeData.parentDefinition = parentDefinition;
            label = 'Superclasses';
            icon = myIconPath('none');
            out = this.createNode(label, label, nodeData, [], icon);
        end
        
        function out = buildSuperclassNode(this, defn)
            nodeData.type = 'superclass';
            nodeData.defn = defn;
            label = [ '@' defn.Name];
            out = this.createNode(label, label, nodeData, false);
        end
        
        function out = buildEnumerationGroupNode(this, parentDefinition)
            nodeData.type = 'enumerationGroup';
            nodeData.parentDefinition = parentDefinition;
            label = 'Enumerations';
            icon = myIconPath('none');
            out = this.createNode(label, label, nodeData, [], icon);
        end
        
        function out = buildEnumerationNode(this, defn)
            nodeData.type = 'enumeration';
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
            nodeData.isPopulated = false;
            set(out, 'userdata', nodeData);
            if allowsChildren
                dummyIcon = myIconPath('none');
                dummyNode = this.oldUitreenode('<dummy>', 'Loading...', dummyIcon, true);
                out.add(dummyNode);
            end
        end
        
        function nodeExpanded(this, src, evd) %#ok<INUSL>
            node = evd.getCurrentNode;
            %logdebug('nodeExpanded: {} ({})', get(node, 'Name'), get(node, 'Value'));
            nodeData = get(node, 'userdata');
            if ismember(nodeData.type, {'package','class'})
                this.refreshNode(node);
            else
                this.populateNode(node);
            end
        end
        
        function refreshNode(this, node)
            nodeData = get(node, 'userdata');            
            switch nodeData.type
                case 'root'         % NOP; its contents are static
                case 'package';     this.refreshPackageNode(node);
                case 'class';       this.refreshClassNode(node);
                otherwise
                    error('Node type %s is not supported for refreshNode() yet', ...
                        nodeData.type);
            end
        end
        
        function repopulateNode(this, node)
            nodeData = get(node, 'userdata');
            % HACK: Bypass root expansion, since it's populated with static info
            if isequal(nodeData.type, 'root')
                return;
            end
            tree = this.treePeer;
            if isequal(nodeData.type, 'package')
                % New development work. Eventually everything will be this style
                this.refreshPackageNode(node);
            else
                newChildNodes = this.buildChildNodes(node);
                % Only this array-based adding method seems to work properly
                jChildNodes = javaArray('com.mathworks.hg.peer.UITreeNode', numel(newChildNodes));
                for i = 1:numel(newChildNodes)
                    jChildNodes(i) = java(newChildNodes{i});
                end
                tree.removeAllChildren(node);
                tree.add(node, jChildNodes);
            end
                tree.setLoaded(node, true);
            nodeData.isPopulated = true;
            set(node, 'userdata', nodeData);
        end
        
        function populateNode(this, node)
            nodeData = get(node, 'userdata');
            if nodeData.isPopulated
                return
            end
            this.repopulateNode(node);
        end
        
        function out = rejectPackagesWithNoImmediateMembers(this, pkgNames) %#ok<INUSL>
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
            logdebug('buildChildNodes: {}', nodeData.type);
            switch nodeData.type
                case 'root'
                    % NOP: Shouldn't get here
                    logwarn('buildChildNodes: attempt to build nodes for root node. Shouldn''t happen');
                case 'codepaths'
                    listMode = ifthen(this.flatPackageView, 'flat', 'nested');
                    found = scanCodeRoots(nodeData.paths, listMode);
                    if ~isempty(found.mfiles) || ~isempty(found.classdirs)
                        out{end+1} = this.buildCodePathsGlobalsNode(nodeData.paths, found);
                    end
                    pkgs = sortCaseInsensitive(found.packages);
                    if this.flatPackageView
                        pkgs = this.rejectPackagesWithNoImmediateMembers(pkgs);
                    end
                    for i = 1:numel(pkgs)
                        out{end+1} = this.buildPackageNode(pkgs{i}); %#ok<AGROW>
                    end
                case 'codepaths_globals'
                    [paths, found] = deal(nodeData.paths, nodeData.found);
                    % Ugh, now we have to scan the files to see if they're
                    % classes or functions
                    probed = scanCodeRootGlobals(paths, found);
                    if ~isempty(probed.classes)
                        out{end+1} = this.buildGlobalClassesNode(probed.classes);
                    end
                    if ~isempty(probed.functions)
                        out{end+1} = this.buildGlobalFunctionsNode(probed.functions);
                    end
                case 'global_classes'
                    classNames = nodeData.classNames;
                    for i = 1:numel(classNames)
                        out{end+1} = this.buildClassNode(classNames{i}); %#ok<AGROW>
                    end
                case 'global_functions'
                    functionNames = nodeData.functionNames;
                    for i = 1:numel(functionNames)
                        out{end+1} = this.buildFunctionNode(functionNames{i}); %#ok<AGROW>
                    end
                case 'package'
                    pkg = meta.package.fromName(nodeData.name);
                    if ~this.flatPackageView
                        pkgList = sortDefnsByName(pkg.PackageList);
                        for i = 1:numel(pkgList)
                            out{end+1} = this.buildPackageNode(pkgList(i).Name); %#ok<AGROW>
                        end
                    end
                    classList = sortDefnsByName(pkg.ClassList);
                    for i = 1:numel(classList)
                        out{end+1} = this.buildClassNode(classList(i).Name); %#ok<AGROW>
                    end
                    functionList = sortDefnsByName(pkg.FunctionList);
                    for i = 1:numel(functionList)
                        % These are really methods, not functions (???)
                        out{end+1} = this.buildMethodNode(functionList(i), nodeData.name); %#ok<AGROW>
                    end
                case 'class'
                    klass = meta.class.fromName(nodeData.name);
                    if ~isempty(this.maybeRejectHidden(...
                            rejectInheritedDefinitions(klass.PropertyList, klass)))
                        out{end+1} = this.buildPropertyGroupNode(klass);
                    end
                    if ~isempty(this.maybeRejectHidden(...
                            rejectInheritedDefinitions(klass.MethodList, klass)))
                        out{end+1} = this.buildMethodGroupNode(klass);
                    end
                    if ~isempty(this.maybeRejectHidden(...
                            rejectInheritedDefinitions(klass.EventList, klass)))
                        out{end+1} = this.buildEventGroupNode(klass);
                    end
                    if ~isempty(klass.EnumerationMemberList)
                        out{end+1} = this.buildEnumerationGroupNode(klass);
                    end
                    if ~isempty(klass.SuperclassList)
                        out{end+1} = this.buildSuperclassGroupNode(klass);
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
                        out{end+1} = this.buildMethodNode(methodList(i), pkgName); %#ok<AGROW>
                    end
                case 'propertyGroup'
                    defn = nodeData.parentDefinition;
                    propList = rejectInheritedDefinitions(defn.PropertyList, defn);
                    propList = sortDefnsByName(this.maybeRejectHidden(propList));
                    for i = 1:numel(propList)
                        out{end+1} = this.buildPropertyNode(propList(i), defn); %#ok<AGROW>
                    end
                case 'eventGroup'
                    defn = nodeData.parentDefinition;
                    eventList = rejectInheritedDefinitions(defn.EventList, defn);
                    eventList = sortDefnsByName(this.maybeRejectHidden(eventList));
                    for i = 1:numel(eventList)
                        out{end+1} = this.buildEventNode(eventList(i)); %#ok<AGROW>
                    end
                case 'enumerationGroup'
                    defn = nodeData.parentDefinition;
                    enumList = sortDefnsByName(defn.EnumerationMemberList);
                    for i = 1:numel(enumList)
                        out{end+1} = this.buildEnumerationNode(enumList(i)); %#ok<AGROW>
                    end
                case 'superclassGroup'
                    defn = nodeData.parentDefinition;
                    for i = 1:numel(defn.SuperclassList)
                        out{end+1} = this.buildClassNode(defn.SuperclassList(i).Name); %#ok<AGROW>
                    end
                case {'method','event','enumeration'}
                    % NOP: No expansion
                otherwise
                    error('No expansion handler for node type %s\n', nodeData.type);
            end
        end
        
        function refreshPackageNode(this, node)
            nodeData = get(node, 'userdata');
            packageName = nodeData.name;
            childNodeNames = getChildNodeNames(node);
            childNodeValues = getChildNodeValues(node);
            nodesToAdd = {};
            nodesToAddNames = {};
            nodesToRemoveNames = cell(1, 0);
            pkg = meta.package.fromName(nodeData.name);
            % Detect subpackages to add/remove
            if ~this.flatPackageView
                pkgList = sortDefnsByName(pkg.PackageList);
                subPkgNames = metaObjNames(pkgList);
                subPkgLabels = strcat('+', subPkgNames);
                for i = 1:numel(pkgList)
                    pkgKey = ['+' pkgList(i).Name];
                    if ~ismember(pkgKey, childNodeNames)
                        nodesToAdd{end+1} = this.buildPackageNode(pkgList(i).Name); %#ok<AGROW>
                        nodesToAddNames{end+1} = pkgKey; %#ok<AGROW>
                    end
                end
                pkgChildNodeNames = selectRegexp(childNodeNames, '^+');
                pkgChildNodeNamesToRemove = setdiff(pkgChildNodeNames, subPkgLabels);
                nodesToRemoveNames = [nodesToRemoveNames pkgChildNodeNamesToRemove];
            end
            % Detect classes to add/remove
            classList = sortDefnsByName(pkg.ClassList);
            classBasenames = regexprep(metaObjNames(classList), '.*\.', '');
            classLabels = strcat('@', classBasenames);
            classChildNodeNames = selectRegexp(childNodeNames, '^@');
            ixToAdd = find(~ismember(classLabels, childNodeValues));
            for i = 1:numel(ixToAdd)
                nodesToAdd{end+1} = this.buildClassNode(classList(i).Name); %#ok<AGROW>
                nodesToAddNames{end+1} = classBasenames{i}; %#ok<AGROW>
            end
            classChildNodeNamesToRemove = setdiff(classChildNodeNames, classLabels);
            nodesToRemoveNames = [nodesToRemoveNames classChildNodeNamesToRemove];
            % Detect functions to add/remove
            functionList = sortDefnsByName(pkg.FunctionList);
            functionNames = metaObjNames(functionList);
            functionChildNodeNames = selectRegexp(childNodeValues, '^[^@+]');
            ixToAdd = find(~ismember(functionNames, functionChildNodeNames));
            for i = 1:numel(ixToAdd)
                nodesToAdd{end+1} = this.buildMethodNode(functionList(i), packageName); %#ok<AGROW>
                nodesToAddNames{end+1} = functionNames{i}; %#ok<AGROW>
            end
            functionChildNodeNamesToRemove = setdiff(functionChildNodeNames, functionNames);
            nodesToRemoveNames = [nodesToRemoveNames functionChildNodeNamesToRemove];
            % Remove dummy node
            if ismember('dummy', childNodeValues)
                nodesToRemoveNames{end+1} = 'dummy';
            end
            % Do the adding and removal
            % TODO: Figure out how to insert new nodes in the right order WRT
            % existing nodes
            logdebugf('removing %d nodes: %s', numel(nodesToRemoveNames), ...
                strjoin(nodesToRemoveNames, ', '));
            [~,ixNodesToRemove] = ismember(nodesToRemoveNames, childNodeValues);
            ixNodesToRemove = sort(ixNodesToRemove);
            this.treePeer.remove(node, ixNodesToRemove-1);
            logdebugf('adding %d nodes: %s', numel(nodesToAdd), ...
                strjoin(nodesToAddNames, ', '));
            nodesToAdd = [nodesToAdd{:}];
            if ~isempty(nodesToAdd)
                this.treePeer.add(node, nodesToAdd);
            end
            nodeData.isPopulated = true;
            set(node, 'userdata', nodeData);
            logdebugf('refreshed %s; added %d things; removed %d things', ...
                get(node, 'name'), numel(nodesToAdd), numel(ixNodesToRemove));
        end
                
        function refreshClassNode(this, node)
            nodeData = get(node, 'userdata');
            klass = meta.class.fromName(nodeData.name);
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
            % when adding to an existing list. (minor issue)
            % Properties
            child = getChildNodeByValue(node, 'Properties');
            if isempty(properties)
                if ~isempty(child)
                    this.treePeer.remove(node, child);
                end
            else
                if isempty(child)
                    this.treePeer.add(node, this.buildPropertyGroupNode(klass));
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
                    this.treePeer.add(node, this.buildMethodGroupNode(klass));
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
                % Haven't decided on an action for double-click yet. Do nothing.
            end
        end
        
        function revealDefn(this, defn, file) %#ok<INUSD>
            if isempty(defn)
                % Ignore empty definitions. That means it's a file outside of
                % our code base
                logdebugf('revealDefn: ignoring empty definition: %s', file);
                return;
            end
            id = idForDefn(defn);
            node = this.defnMap.get(id);
            if ~isempty(node)
                % Easy case: the node already exists
                logdebugf('revealDefn: fast path: %s', file);
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
                    this.populateNode(parentNode);
                else
                    parentNode = scopeNode;
                    if this.flatPackageView
                        if ~isempty(defn.package)
                            parentNode = getChildNodeByName(scopeNode, ['+' defn.package]);
                        end
                    else
                        pkgEls = strsplit(defn.package, '.');
                        for i = 1:numel(pkgEls)
                            parentNode = getChildNodeByName(parentNode, ['+' pkgEls{i}]);
                            if isempty(parentNode)
                                logwarnf('Definition not found in code base: missing parent package for %s', ...
                                    defn.name);
                                return;
                            end
                        end
                    end
                    this.populateNode(parentNode);
                end
                if isequal(defn.type, 'function')
                    groupNode = getChildNodeByName(parentNode, 'Functions');
                    this.populateNode(groupNode);
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
                    this.populateNode(groupNode);
                    defnNode = this.defnMap.get(id);
                end
            end
            if isempty(defnNode)
                logwarnf('Definition node did not populate as expected: %s', id);
                return;
            end
            parent = defnNode.getParent;
            this.expandNode(parent);
            this.setSelectedNode(defnNode);
            this.scrollToNode(defnNode);
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
            if isempty(nodeData.package)
                qualifiedName = defn.Name;
            else
                qualifiedName = [nodeData.package '.' defn.Name];
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
            if isempty(nodeData.package)
                qualifiedName = defn.Name;
            else
                qualifiedName = [nodeData.package '.' defn.Name];
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

function out = getChildNodeNames(node)
out = {};
for i = 1:node.getChildCount
    out{i} = get(node.getChildAt(i-1), 'Name'); %#ok<AGROW>
end
end

function out = getChildNodeValues(node)
out = {};
for i = 1:node.getChildCount
    out{i} = get(node.getChildAt(i-1), 'Value'); %#ok<AGROW>
end
end
