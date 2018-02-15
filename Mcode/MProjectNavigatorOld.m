function MProjectNavigator(varargin)
    %MProjectNavigator Viewer for a Matlab project structure
    %
    % MProjectNavigator(varargin)
    %
    % Usage:
    %
    % MProjectNavigator
    % MProjectNavigator -pin <path>
    % MProjectNavigator -registerhotkey
    %
    % For this to work, its JAR dependencies must be on the Java classpath. You can
    % set this up by running loadMProjectNavigator(), found in this project's
    % "bootstrap/" directory.
    
    error(javachk('awt'));
    
    persistent pFrame pPinnedPath pTreePeer
    
    iconPath = [matlabroot '/toolbox/matlab/icons'];
    
    % Process inputs
    
    if nargin == 0
        maybeInitializeGui();
        pFrame.setVisible(true);
    else
        if isequal(varargin{1}, '-pin')
            if nargin < 2
                warning('MProjectNavigator: Invalid arguments: -pin requires an argument');
                return;
            end
            newPinnedPath = varargin{2};
            maybeInitializeGui();
            updatePinnedPath(newPinnedPath);
        elseif isequal(varargin{1}, '-dispose')
            if ~isempty(pFrame)
                pFrame.dispose();
                pFrame = [];
                pTreePeer = [];
            end
        elseif isequal(varargin{1}, '-fresh')
            if ~isempty(pFrame)
                pFrame.dispose();
                pFrame = [];
                pTreePeer = [];
            end
            maybeInitializeGui();
            pFrame.setVisible(true);
        elseif isequal(varargin{1}, '-registerhotkey')
            registerHotkey();
        elseif isequal(varargin{1}, '-hotkeyinvoked')
            hotkeyInvoked();
        elseif isequal(varargin{1}(1), '-')
            warning('MProjectNavigator: Unrecognized option: %s', varargin{1});
        else
            warning('MProjectNavigator: Invalid arguments');
        end
    end
    
    function maybeInitializeGui()
        if isempty(pFrame)
            initializeGui();
        end
    end
    
    function initializeGui()
        % Initialize the navigator GUI
        import java.awt.*
        import javax.swing.*
        
        if isempty(pPinnedPath)
            pPinnedPath = pwd;
        end
        rootPath = pPinnedPath;
        
        frame = JFrame('Project Navigator');
        frame.setSize(250, 600);
        if ~ismac
            % Only on non-Mac; I don't like how it displays in the doc for Mac
            frameIcon = ImageIcon([iconPath '/tool_legend.gif']);
            frame.setIconImage(frameIcon.getImage);
        end
        
        tree_h = com.mathworks.hg.peer.UITreePeer;
        try tree_h = javaObjectEDT(tree_h); catch, end
        pTreePeer = tree_h;
        tree_hh = handle(tree_h,'CallbackProperties');
        jTreeObj = getJTreeFromUiPeer(tree_h);
        jTreeObjh = handle(jTreeObj,'CallbackProperties');
        
        % Set the callback functions
        set(tree_hh, 'NodeExpandedCallback', {@nodeExpanded, tree_h});
        set(tree_hh, 'NodeWillExpandCallback', {@nodeWillExpand, tree_h});
        set(tree_hh, 'NodeSelectedCallback', {@nodeSelected, tree_h});
        % Mouse-click callback
        set(jTreeObjh, 'MousePressedCallback', {@treeMousePressed, tree_h})
        set(jTreeObjh, 'MouseMovedCallback', {@treeMouseMoved, tree_h});
        
        %root = oldUitreenode('Some Text', 'This is the root node', [], true);
        root = fileTreenode(rootPath);
        tree_h.setRoot(root);
        treePane = tree_h.getScrollPane;
        treePane.setMinimumSize(Dimension(50,50));
        jTreeObj.setShowsRootHandles(true);
        jTreeObj.getSelectionModel.setSelectionMode(javax.swing.tree.TreeSelectionModel.DISCONTIGUOUS_TREE_SELECTION);
        treePanel = JPanel(BorderLayout);
        treePanel.add(treePane, BorderLayout.CENTER);
        frame.getContentPane.add(treePanel, BorderLayout.CENTER);
        
        % Expand the root node one level
        expandNode(root, jTreeObj, false);
        
        registerHotkeyOnComponent(frame.getContentPane);
        registerHotkeyOnComponent(jTreeObj);
        pFrame = frame;
        frame.setVisible(true);
    end
    
    function out = getJTreeFromUiPeer(tree_h)
        mustBeA(tree_h, 'com.mathworks.hg.peer.UITreePeer');
        treeScrollPane = tree_h.getScrollPane;
        out = treeScrollPane.getViewport.getComponent(0);
    end
    
    function out = fileTreenode(path)
        [~,basename,ext] = fileparts(path);
        basename = [basename ext];
        isDir = isReallyDir(path);
        if isDir
            icon = [iconPath '/foldericon.gif'];
        else
            icon = [iconPath '/pageicon.gif'];
        end
        out = oldUitreenode('Some Dummy Text', basename, icon, true);
        nodeData.isDummy = false;
        nodeData.path = path;
        nodeData.isDir = isDir;
        nodeData.isFile = ~isDir;
        nodeData.isPopulated = ~isDir;
        set(out, 'userdata', nodeData);
        out.setLeafNode(false);
        out.setAllowsChildren(isDir);
        if isDir
            out.add(dummyTreenode());
        end
    end
    
    function out = dummyTreenode()
        nodeData.path = '<dummy>';
        nodeData.isDummy = true;
        nodeData.isDir = false;
        nodeData.isPopulated = true;
        nodeData.isFile = false;
        out = oldUitreenode('Some Dummy Text', 'Loading...', [], true);
        set(out, 'userdata', nodeData);
    end
    
    function expandNode(node, jTreeObj, recurse)
        mustBeA(jTreeObj, 'javax.swing.JTree');
        tree = jTreeObj;
        nodePath = treePathForNode(node, tree);
        tree.expandPath(nodePath);
        if recurse
            pause(0.0005); % Pause to allow lazy-loaded children to be filled in
            for i = 1:node.getChildCount
                expandNode(node.getChildAt(i-1), jTreeObj, recurse);
            end
        end
    end
    
    function out = treePathForNode(node, tree)
        % Get the TreePath to a node
        
        % This is a hack needed because the straight TreePath(rawNodePath)
        % constructor doesn't work, probably due to Matlab/Java autoboxing issues
        rawNodePath = node.getPath;
        nodePath = tree.getPathForRow(0);
        for i = 2:numel(rawNodePath)
            nodePath = nodePath.pathByAddingChild(rawNodePath(i));
        end
        out = nodePath;
    end
    
    function nodeExpanded(src, evd, tree) %#ok<INUSL>
        %fprintf('nodeExpanded()\n');
        node = evd.getCurrentNode;
        if ~tree.isLoaded(node)
            newChildNodes = buildChildNodes(node, tree);
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
    
    function nodeWillExpand(src, evd, tree) %#ok<INUSD>
    end
    
    function treeMousePressed(hTree, eventData, tree_h) %#ok<INUSL>
        % Mouse click callback
        
        %fprintf('mousePressed()\n');
        % Get the clicked node
        clickX = eventData.getX;
        clickY = eventData.getY;
        jtree = eventData.getSource;
        treePath = jtree.getPathForLocation(clickX, clickY);
        if eventData.isMetaDown
            % Right-click
            if ~isempty(treePath)
                node = treePath.getLastPathComponent;
                nodeData = get(node, 'userdata');
            else
                node = [];
                nodeData = [];
            end
            jmenu = setupTreeContextMenu(node, nodeData, tree_h);
            jmenu.show(jtree, clickX, clickY);
            jmenu.repaint;
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
    
    function treeMouseMoved(hTree, eventData, tree) %#ok<INUSD>
        % Handle tree mouse movement callback - used to set the tooltip & context-menu
    end
    
    function out = buildChildNodes(node, tree) %#ok<INUSD>
        nodeData = get(node, 'userdata');
        file = nodeData.path;
        childNodes = {};
        if nodeData.isDir
            d = dir2(file);
            childNodes = cell(1, numel(d));
            for i = 1:numel(d)
                childPath = fullfile(file, d(i).name);
                childNode = fileTreenode(childPath);
                childNodes{i} = childNode;
            end
        end
        out = childNodes;
    end
    
    function nodeSelected(src, evd, tree) %#ok<INUSL,INUSD>
        %fprintf('nodeSelected()\n');
        evdnode = evd.getCurrentNode;
        node = evdnode; %#ok<NASGU>  DEBUG
    end
    
    function out = oldUitreenode(x, text, icon, hasChildren)
        % Use the old style uitreenode because it plays well with plain JFrames
        try
            out = uitreenode('v0', x, text, icon, hasChildren);
        catch  % old matlab version don't have the 'v0' option
            out = uitreenode(x, text, icon, hasChildren);
        end
    end
    
    function out = setupTreeContextMenu(node, nodeData, tree_h) %#ok<INUSL>
        import javax.swing.*
        
        % EDIT: Edit click target or selected nodes
        % CHANGEPIN: Change the pinned root directory
        % REFRESH: Force a refresh
        % EXPAND_ALL: Recursively expand all tree nodes
        
        jmenu = JPopupMenu;
        menuItemEdit = JMenuItem('Edit');
        menuItemViewDoc = JMenuItem('View Doc');
        menuItemMlintReport = JMenuItem('M-Lint Report');
        menuItemCdToHere = JMenuItem('CD to Here');
        menuItemCopyPath = JMenuItem('Copy Path');
        menuItemCopyRelativePath = JMenuItem('Copy Relative Path');
        menuItemExpandAll = JMenuItem('Expand All');
        menuNew = JMenu('New');
        menuItemNewFile = JMenuItem('File...');
        menuItemNewDir = JMenuItem('Directory...');
        
        % Only enable edit if there is a selection or click target
        isTargetFile = (~isempty(nodeData) && nodeData.isFile);
        isTargetDir = (~isempty(nodeData) && nodeData.isDir);
        isTargetFileOrDir = (~isempty(nodeData) && (nodeData.isFile || nodeData.isDir));
        isTargetEditable =  isTargetFile || ~isempty(tree_h.getSelectedNodes);
        isTargetMfile = isTargetFile && endsWith(nodeData.path, '.m', 'IgnoreCase',true);
        menuItemEdit.setEnabled(isTargetEditable);
        menuItemViewDoc.setEnabled(isTargetFileOrDir);
        menuItemMlintReport.setEnabled(isTargetDir || isTargetMfile);
        menuItemCopyPath.setEnabled(isTargetFileOrDir);
        menuItemCopyRelativePath.setEnabled(isTargetFileOrDir);
        
        
        function setCallback(item, callback)
            set(handle(item,'CallbackProperties'), 'ActionPerformedCallback', callback);
        end
        setCallback(menuItemEdit, {@ctxEditCallback, nodeData, tree_h});
        setCallback(menuItemViewDoc, {@ctxViewDocCallback, nodeData, tree_h});
        setCallback(menuItemMlintReport, {@ctxMlintReportCallback, nodeData, tree_h});
        setCallback(menuItemCdToHere, {@ctxCdToHereCallback, nodeData, tree_h});
        setCallback(menuItemCopyPath, {@ctxCopyPathCallback, nodeData, tree_h, 'absolute'});
        setCallback(menuItemCopyRelativePath, {@ctxCopyPathCallback, nodeData, tree_h, 'relative'});
        setCallback(menuItemExpandAll, {@ctxExpandAllCallback, tree_h});
        
        jmenu.add(menuItemEdit);
        jmenu.add(menuItemViewDoc);
        jmenu.add(menuItemMlintReport);
        if isTargetFileOrDir
            jmenu.addSeparator;
            jmenu.add(menuItemCdToHere);
        end
        jmenu.addSeparator;
        jmenu.add(menuItemCopyPath);
        jmenu.add(menuItemCopyRelativePath);
        jmenu.addSeparator;
        jmenu.add(menuItemExpandAll);
        
        out = jmenu;
    end
    
    function ctxEditCallback(src, evd, nodeData, tree_h) %#ok<INUSL>
        selected = tree_h.getSelectedNodes;
        if isempty(selected)
            % Edit file under original click
            if isempty(nodeData) || nodeData.isDummy || nodeData.isDir
                filesToEdit = {};
            else
                filesToEdit = {nodeData.path};
            end
        else
            % Edit all selected files
            filesToEdit = {};
            for i = 1:numel(selected)
                sel = selected(i);
                data = get(sel, 'userdata');
                if data.isDummy || data.isDir
                    continue;
                end
                filesToEdit{end+1} = data.path; %#ok<AGROW>
            end
        end
        if ~isempty(filesToEdit)
            edit(filesToEdit{:});
        end
    end
    
    function ctxViewDocCallback(src, evd, nodeData, tree_h) %#ok<INUSL>
        doc(nodeData.path);
    end
    
    function ctxMlintReportCallback(src, evd, nodeData, tree_h) %#ok<INUSL>
        if nodeData.isDir
            mlintrpt(nodeData.path, 'dir');
        else
            mlintrpt(nodeData.path);
        end
    end
    
    function ctxCdToHereCallback(src, evd, nodeData, tree_h) %#ok<INUSL>
        path = nodeData.path;
        if ~isdir(path)
            path = fileparts(path);
        end
        cd(path);
        fprintf('cded to %s\n', path);
    end
    
    function ctxCopyPathCallback(src, evd, nodeData, tree_h, mode) %#ok<INUSL>
        path = nodeData.path;
        switch mode
            case 'absolute'
                % NOP
            case 'relative'
                rootNode = tree_h.getRoot;
                rootNodeData = get(rootNode, 'userdata');
                rootPath = rootNodeData.path;
                if (startsWith(path, rootPath))
                    path(1:numel(rootPath)) = [];
                    path = regexprep(path, '^[/\\]+', '');
                end
            otherwise
                error('Invalid mode: %s', mode);
        end
        clipboard('copy', path);
    end
    
    function ctxExpandAllCallback(src, evd, tree_h) %#ok<INUSL>
        expandNode(tree_h.getRoot, getJTreeFromUiPeer(tree_h), true);
    end
    
    function refreshGuiForNewPath()
        fprintf('refreshGuiForNewPath()\n');
        root = fileTreenode(pPinnedPath);
        pTreePeer.setRoot(root);
    end
    
    function updatePinnedPath(newPinnedPath)
        if ~isdir(newPinnedPath) %#ok
            warning('''%s'' is not a directory', newPinnedPath);
        end
        if isReallyDir(newPinnedPath)
            pPinnedPath = newPinnedPath;
            refreshGuiForNewPath();
        else
            mp = strsplit(path, ':');
            for i = 1:numel(mp)
                resolvedPath = fullfile(mp{i}, newPinnedPath);
                if isReallyDir(resolvedPath)
                    pPinnedPath = resolvedPath;
                    refreshGuiForNewPath();
                end
            end
            warning('Could not resolve directory ''%s''', newPinnedPath);
        end        
    end
    
    function registerHotkey()
        mainFrame = com.mathworks.mde.desk.MLDesktop.getInstance.getMainFrame;
        registerHotkeyOnComponent(mainFrame.getContentPane);
    end

    function registerHotkeyOnComponent(jComponent)
        import net.apjanke.mprojectnavigator.swing.*
        import java.awt.*
        import javax.swing.*
                
        action = FevalAction.ofStringArguments('MProjectNavigator','-hotkeyinvoked');
        %action.setDisplayConsoleOutput(true); % DEBUG
        inputMap = jComponent.getInputMap(JComponent.WHEN_IN_FOCUSED_WINDOW);
        actionMap = jComponent.getActionMap;
        controlShiftP = KeyStroke.getKeyStroke('control shift P');
        actionName = java.lang.String('MProjectNavigator-hotkey');
        inputMap.put(controlShiftP, actionName);
        actionMap.put(actionName, action); 
    end
    
    function hotkeyInvoked()
        if isempty(pFrame)
            initializeGui();
        else
            % Toggle visibility
            pFrame.setVisible(~pFrame.isVisible);
        end
    end
end

function mustBeA(value, type)
    assert(isa(value, type), 'Input must be a %s, but got a %s', type, class(value));
end

function out = isReallyDir(path)
    jFile = java.io.File(path);
    out = jFile.isDirectory();
end

function out = dir2(path)
    out = dir(path);
    % Ignore all hidden files
    out(~cellfun(@isempty, regexp({out.name}, '^\.', 'once'))) = [];
end
