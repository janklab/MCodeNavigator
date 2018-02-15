function MProjectNavigator(varargin)
%MProjectNavigator Viewer for a Matlab project structure
%
% Usage:
%
% MProjectNavigator
% MProjectNavigator -pin <path>
%

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

%% Initialize the navigator GUI
    function initializeGui()
    import java.awt.*
    import javax.swing.*
    
    if isempty(pPinnedPath)
        pPinnedPath = pwd;
    end
    rootPath = pPinnedPath;
    
    frameIcon = ImageIcon([iconPath '/tool_legend.gif']);
    frame = JFrame('Project Navigator');
    frame.setSize(250, 600);
    frame.setVisible(true); % for debugging
    
    tree_h = com.mathworks.hg.peer.UITreePeer;
    try tree_h = javaObjectEDT(tree_h); catch, end
    pTreePeer = tree_h;
    tree_hh = handle(tree_h,'CallbackProperties');
    treeScrollPane = tree_h.getScrollPane;
    jTreeObj = treeScrollPane.getViewport.getComponent(0);
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
    jTreeObj = getJTreeFromUiPeer(tree_h);
    jTreeObj.setShowsRootHandles(true);
    jTreeObj.getSelectionModel.setSelectionMode(javax.swing.tree.TreeSelectionModel.DISCONTIGUOUS_TREE_SELECTION);
    treePanel = JPanel(BorderLayout);
    treePanel.add(treePane, BorderLayout.CENTER);
    frame.getContentPane.add(treePanel, BorderLayout.CENTER);
    
    % Expand the root node one level
    expandNode(root, jTreeObj, false);
    
    pFrame = frame;
    frame.setVisible(true);
    
    end

    function out = getJTreeFromUiPeer(tree_h)
    mustBeA(tree_h, 'com.mathworks.hg.peer.UITreePeer');
    treePane = tree_h.getScrollPane;
    out = treePane.getViewport.getComponent(0);
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
    x = 42; % DEBUG
    nodeData = get(node, 'userdata');
    fprintf('Expanding %s\n', nodeData.path);
    tree = jTreeObj;
    nodePath = treePathForNode(node, tree);
    tree.expandPath(nodePath);
    if recurse
        pause(0.0005); % Pause to allow lazy-loaded children to be filled in
        fprintf('Expanding %s: recursing (%d children)\n', ...
            nodeData.path, node.getChildCount);
        for i = 1:node.getChildCount
            fprintf('Expanding %s: expanding child %d\n', nodeData.path, i);
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

    function nodeExpanded(src, evd, tree)
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

    function nodeWillExpand(src, evd, tree)
    end

    function treeMousePressed(hTree, eventData, tree_h)
    % Mouse click callback
    
    %fprintf('mousePressed()\n');
    % Get the clicked node
    clickX = eventData.getX;
    clickY = eventData.getY;
    jtree = eventData.getSource;
    treePath = jtree.getPathForLocation(clickX, clickY);
    if eventData.isMetaDown  
        % Right-click
        fprintf('mousePressed(): right-click\n');
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
        fprintf('mousePressed(): double-click\n');
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

    function treeMouseMoved(hTree, eventData, tree)
    % Handle tree mouse movement callback - used to set the tooltip & context-menu
    end

    function out = buildChildNodes(node, tree)
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

    function nodeSelected(src, evd, tree)
    %fprintf('nodeSelected()\n');
    evdnode = evd.getCurrentNode;
    node = evdnode;
    end

    function out = oldUitreenode(x, text, icon, hasChildren)
    % Use the old style uitreenode because it plays well with plain JFrames
    try
        out = uitreenode('v0', x, text, icon, hasChildren);
    catch  % old matlab version don't have the 'v0' option
        out = uitreenode(x, text, icon, hasChildren);
    end
    end

    function out = setupTreeContextMenu(node, nodeData, tree_h)
    import javax.swing.*
    
    % EDIT: Edit click target or selected nodes
    % CHANGEPIN: Change the pinned root directory
    % REFRESH: Force a refresh
    % EXPAND_ALL: Recursively expand all tree nodes
    
    jmenu = JPopupMenu;
    menuItemEdit = JMenuItem('Edit');
    menuItemViewDoc = JMenuItem('View Doc');
    menuItemExpandAll = JMenuItem('Expand All');
    
    % Only enable edit if there is a selection or click target
    isTargetEditable = (~isempty(nodeData) && nodeData.isFile) ...
        || ~isempty(tree_h.getSelectedNodes);
    menuItemEdit.setEnabled(isTargetEditable);
    isTargetDocable = (~isempty(nodeData) && (nodeData.isFile || nodeData.isDir));
    menuItemViewDoc.setEnabled(isTargetDocable);
    
    set(handle(menuItemEdit,'CallbackProperties'), 'ActionPerformedCallback', ...
        {@ctxEditCallback, nodeData, tree_h});
    set(handle(menuItemViewDoc,'CallbackProperties'), 'ActionPerformedCallback', ...
        {@ctxViewDocCallback, nodeData, tree_h});
    set(handle(menuItemExpandAll,'CallbackProperties'), 'ActionPerformedCallback', ...
        {@ctxExpandAllCallback, tree_h});
    
    jmenu.add(menuItemEdit);
    jmenu.add(menuItemViewDoc);
    jmenu.addSeparator;
    jmenu.add(menuItemExpandAll);
    
    out = jmenu;
    end

    function ctxEditCallback(src, evd, nodeData, tree_h)    
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

    function ctxViewDocCallback(src, evd, nodeData, tree_h)
    doc(nodeData.path);
    end

    function ctxExpandAllCallback(src, evd, tree_h)
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

    function out = isReallyDir(path)
    jFile = java.io.File(path);
    out = jFile.isDirectory();
    end

    function out = dir2(path)
    out = dir(path);
    %ignoredFiles = {'.DS_Store'};
    %out(ismember({out.name}, [{'.','..'} ignoredFiles])) = [];
    % Actually, ignore all hidden files
    out(~cellfun(@isempty, regexp({out.name}, '^\.', 'once'))) = [];
    end
end

function mustBeA(value, type)
assert(isa(value, type), 'Input must be a %s, but got a %s', type, class(value));
end