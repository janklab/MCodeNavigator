classdef FileNavigatorWidget < mprojectnavigator.TreeWidget
    
    properties (Constant, Hidden)
        iconPath = [matlabroot '/toolbox/matlab/icons'];
    end
    
    properties
        rootPath = pwd;
    end
    
    methods
        function this = FileNavigatorWidget()
        end
        
        function setRootPath(this, newRootPath)
            if ~isdir(newRootPath) %#ok
                warning('''%s'' is not a directory', newRootPath);
            end
            if isReallyDir(newRootPath)
                this.rootPath = newRootPath;
                this.refreshGuiForNewPath();
            else
                mp = strsplit(path, ':');
                for i = 1:numel(mp)
                    resolvedPath = fullfile(mp{i}, newRootPath);
                    if isReallyDir(resolvedPath)
                        this.rootPath = resolvedPath;
                        this.refreshGuiForNewPath();
                    end
                end
                warning('Could not resolve directory ''%s''', newRootPath);
            end
        end
        
        function initializeGui(this)
            import java.awt.*
            import javax.swing.*
            
            initializeGui@mprojectnavigator.TreeWidget(this);
            
            tree = this.treePeer;
            treePane = tree.getScrollPane;
            treePane.setMinimumSize(Dimension(50, 50));
            
            this.jTree.setShowsRootHandles(true);
            this.jTree.getSelectionModel.setSelectionMode(javax.swing.tree.TreeSelectionModel.DISCONTIGUOUS_TREE_SELECTION);
            
            % Set callback functions
            set(this.treePeerHandle, 'NodeExpandedCallback', {@nodeExpandedCallback, this});
            set(this.treePeerHandle, 'NodeSelectedCallback', {@nodeSelectedCallback, this});
            set(this.jTreeHandle, 'MousePressedCallback', {@treeMousePressed, this});
            set(this.jTreeHandle, 'MouseMovedCallback', {@treeMouseMoved, this});
            
            this.completeRefreshGui;
        end
        
        
        function out = setupTreeContextMenu(this, node, nodeData) %#ok<INUSL>
            import javax.swing.*
            
            % EDIT: Edit click target or selected nodes
            % CHANGEPIN: Change the pinned root directory
            % REFRESH: Force a refresh
            % EXPAND_ALL: Recursively expand all tree nodes
            
            if      ismac;    fileShellName = 'Finder';
            elseif  ispc;     fileShellName = 'Windows Explorer';
            else;             fileShellName = 'File Browser';
            end
            
            jmenu = JPopupMenu;
            menuItemEdit = JMenuItem('Edit');
            menuItemViewDoc = JMenuItem('View Doc');
            menuItemMlintReport = JMenuItem('M-Lint Report');
            menuItemCdToHere = JMenuItem('CD to Here');
            menuItemRevealInDesktop = JMenuItem(sprintf('Reveal in %s', fileShellName));
            menuItemCopyPath = JMenuItem('Copy Path');
            menuItemCopyRelativePath = JMenuItem('Copy Relative Path');
            menuItemExpandAll = JMenuItem('Expand All');
            %TODO: Implement the "New" items
            menuNew = JMenu('New');
            menuItemNewFile = JMenuItem('File...');
            menuItemNewDir = JMenuItem('Directory...');
            menuItemDirUp = JMenuItem('Go Up a Directory');
            menuItemPinThis = JMenuItem('Pin This Directory');
            
            % Only enable edit if there is a selection or click target
            isTargetFile = (~isempty(nodeData) && nodeData.isFile);
            isTargetDir = (~isempty(nodeData) && nodeData.isDir);
            isTargetFileOrDir = (~isempty(nodeData) && (nodeData.isFile || nodeData.isDir));
            isTargetEditable =  isTargetFile || ~isempty(this.treePeer.getSelectedNodes);
            isTargetMfile = isTargetFile && endsWith(nodeData.path, '.m', 'IgnoreCase',true);
            menuItemEdit.setEnabled(isTargetEditable);
            menuItemViewDoc.setEnabled(isTargetFileOrDir);
            menuItemMlintReport.setEnabled(isTargetDir || isTargetMfile);
            menuItemRevealInDesktop.setEnabled(isTargetFileOrDir);
            menuItemCopyPath.setEnabled(isTargetFileOrDir);
            menuItemCopyRelativePath.setEnabled(isTargetFileOrDir);
            
            function setCallback(item, callback)
                set(handle(item,'CallbackProperties'), 'ActionPerformedCallback', callback);
            end
            setCallback(menuItemEdit, {@ctxEditCallback, this, nodeData});
            setCallback(menuItemViewDoc, {@ctxViewDocCallback, this, nodeData});
            setCallback(menuItemMlintReport, {@ctxMlintReportCallback, this, nodeData});
            setCallback(menuItemCdToHere, {@ctxCdToHereCallback, this, nodeData});
            setCallback(menuItemRevealInDesktop, {@ctxRevealInDesktopCallback, this, nodeData});
            setCallback(menuItemCopyPath, {@ctxCopyPathCallback, this, nodeData, 'absolute'});
            setCallback(menuItemCopyRelativePath, {@ctxCopyPathCallback, this, nodeData, 'relative'});
            setCallback(menuItemExpandAll, {@ctxExpandAllCallback, this});
            setCallback(menuItemDirUp, {@ctxDirUpCallback, this});
            setCallback(menuItemPinThis, {@ctxPinThisCallback, this, nodeData});
            
            jmenu.add(menuItemEdit);
            jmenu.add(menuItemViewDoc);
            jmenu.add(menuItemMlintReport);
            if isTargetFileOrDir
                jmenu.addSeparator;
                jmenu.add(menuItemCdToHere);
            end
            jmenu.addSeparator;
            jmenu.add(menuItemRevealInDesktop);
            jmenu.add(menuItemCopyPath);
            jmenu.add(menuItemCopyRelativePath);
            jmenu.addSeparator;
            jmenu.add(menuItemDirUp);
            if isTargetDir
                jmenu.add(menuItemPinThis);
            end
            jmenu.addSeparator;
            jmenu.add(menuItemExpandAll);
            
            out = jmenu;
        end
        
        function completeRefreshGui(this)
            root = this.fileTreenode(this.rootPath);
            this.treePeer.setRoot(root);
            pause(0.005); % Allow widgets to catch up
            % Expand the root node one level
            this.expandNode(root, false);
        end
        
        function refreshGuiForNewPath(this)
            this.completeRefreshGui;
        end
        
        function out = fileTreenode(this, path)
            [~,basename,ext] = fileparts(path);
            basename = [basename ext];
            isDir = isReallyDir(path);
            if isDir
                icon = myIconPath('folder');
            else
                icon = myIconPath('file');
            end
            out = this.oldUitreenode('Some Dummy Text', basename, icon, true);
            nodeData.isDummy = false;
            nodeData.path = path;
            nodeData.isDir = isDir;
            nodeData.isFile = ~isDir;
            nodeData.isPopulated = ~isDir;
            set(out, 'userdata', nodeData);
            out.setLeafNode(false);
            out.setAllowsChildren(isDir);
            if isDir
                out.add(this.dummyTreenode());
            end
        end
        
        function out = dummyTreenode(this)
            nodeData.path = '<dummy>';
            nodeData.isDummy = true;
            nodeData.isDir = false;
            nodeData.isPopulated = true;
            nodeData.isFile = false;
            out = this.oldUitreenode('Some Dummy Text', 'Loading...', [], true);
            set(out, 'userdata', nodeData);
        end
        
        function out = buildChildNodes(this, node, tree) %#ok<INUSD>
            nodeData = get(node, 'userdata');
            file = nodeData.path;
            childNodes = {};
            if nodeData.isDir
                d = dir2(file);
                childNodes = cell(1, numel(d));
                for i = 1:numel(d)
                    childPath = fullfile(file, d(i).name);
                    childNode = this.fileTreenode(childPath);
                    childNodes{i} = childNode;
                end
            end
            out = childNodes;
        end
        
        function nodeExpanded(this, src, evd) %#ok<INUSL>
            tree = this.treePeer;
            node = evd.getCurrentNode;
            if ~tree.isLoaded(node)
                newChildNodes = this.buildChildNodes(node, tree);
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
        
    end
    
end

function treeMousePressed(hTree, eventData, this) %#ok<INUSL>
% Mouse click callback
import javax.swing.*

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

function treeMouseMoved(hTree, eventData, this) %#ok<INUSD>
% Handle tree mouse movement callback - used to set the tooltip & context-menu
end

function nodeExpandedCallback(src, evd, this)
this.nodeExpanded(src, evd);
end

function nodeSelectedCallback(src, evd, tree) %#ok<INUSL,INUSD>
evdnode = evd.getCurrentNode;
node = evdnode; %#ok<NASGU>  DEBUG
end

function ctxEditCallback(src, evd, this, nodeData) %#ok<INUSL>
selected = this.treePeer.getSelectedNodes;
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

function ctxViewDocCallback(src, evd, this, nodeData) %#ok<INUSL>
doc(nodeData.path);
end

function ctxMlintReportCallback(src, evd, this, nodeData) %#ok<INUSL>
if nodeData.isDir
    mlintrpt(nodeData.path, 'dir');
else
    mlintrpt(nodeData.path);
end
end

function ctxCdToHereCallback(src, evd, this, nodeData) %#ok<INUSL>
path = nodeData.path;
if ~isdir(path)
    path = fileparts(path);
end
cd(path);
fprintf('cded to %s\n', path);
end

function ctxRevealInDesktopCallback(src, evd, this, nodeData) %#ok<INUSL>
mprojectnavigator.Utils.guiRevealFileInDesktopFileBrowser(nodeData.path);
end

function ctxCopyPathCallback(src, evd, this, nodeData, mode) %#ok<INUSL>
path = nodeData.path;
switch mode
    case 'absolute'
        % NOP
    case 'relative'
        rootNode = this.treePeer.getRoot;
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

function ctxExpandAllCallback(src, evd, this) %#ok<INUSL>
this.expandNode(this.treePeer.getRoot, true);
end

function ctxDirUpCallback(src, evd, this) %#ok<INUSL>
this.setRootPath(fileparts(this.rootPath));
end

function ctxPinThisCallback(src, evd, this, nodeData) %#ok<INUSL>
if ~nodeData.isDir
    return;
end
this.setRootPath(nodeData.path);
end


