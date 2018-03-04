classdef FileNavigatorWidget < mprojectnavigator.internal.TreeWidget
    
    properties
        rootPath = getpref(PREFGROUP, 'files_pinnedDir', pwd);
        navigator
    end
    
    methods
        function this = FileNavigatorWidget(parentNavigator)
            this.navigator = parentNavigator;
            this.initializeGui;
        end
        
        function initializeGui(this)
            import java.awt.*
            import javax.swing.*
            
            initializeGui@mprojectnavigator.internal.TreeWidget(this);
            
            tree = this.treePeer;
            treePane = tree.getScrollPane;
            treePane.setMinimumSize(Dimension(50, 50));
            
            this.jTree.setShowsRootHandles(true);
            this.jTree.getSelectionModel.setSelectionMode(javax.swing.tree.TreeSelectionModel.DISCONTIGUOUS_TREE_SELECTION);
            
            this.completeRefreshGui;
        end
        
        function setRootPath(this, newPath)
            if isequal(newPath, this.rootPath)
                return;
            end
            this.rootPath = newPath;
            setpref(PREFGROUP, 'files_pinnedDir', newPath);
            this.refreshGuiForNewPath();
        end
        
        function completeRefreshGui(this)
            root = this.buildFileNode(this.rootPath);
            this.treePeer.setRoot(root);
            pause(0.005); % Allow widgets to catch up
            % Expand the root node one level
            this.expandNode(root);
        end
        
        function refreshGuiForNewPath(this)
            this.completeRefreshGui;
        end
        
        function revealFile(this, file)
            if ~strncmpi(file, this.rootPath, numel(this.rootPath))
                logdebugf('revealFile(): Ignoring file outside of file navigator root: %s', file);
                return;
            end
            relPath = file(numel(this.rootPath)+2:end);
            relPathParts = strsplit(relPath, filesep);
            % Expand to that file
            function [found,foundChild] = findPathComponentInChildren(parentNode, part, iPathPart, nPathParts)
                found = false;
                foundChild = [];
                for iChild = 1:parentNode.getChildCount
                    child = parentNode.getChildAt(iChild-1);
                    childData = get(child, 'userdata');
                    if isequal(part, childData.basename)
                        % Found the next step in the path. Expand it so its
                        % children are loaded.
                        if iPathPart < nPathParts
                            this.expandNode(child);
                        end
                        foundChild = child;
                        found = true;
                        break;
                    end
                end
            end
            node = this.treePeer.getRoot();
            this.refreshNode(node);
            for iPathPart = 1:numel(relPathParts)
                part = relPathParts{iPathPart};
                [found,foundChild] = findPathComponentInChildren(node, part, ...
                    iPathPart, numel(relPathParts));
                if ~found
                    logwarnf('Could not find file path in tree: %s', path);
                    return;
                end
                node = foundChild;
                this.refreshNode(node);
            end
            this.setSelectedNode(node);
            this.scrollToNode(node);
        end
        
        function out = buildFileNode(this, path)
            [~,basename,ext] = fileparts(path);
            basename = [basename ext];
            isDir = isFolder(path);
            if isDir
                icon = myIconPath('folder');
            else
                icon = myIconPath('file');
            end
            nodeData = mprojectnavigator.internal.FileNodeData(path, isDir);
            nodeData.isDummy = false;
            nodeData.path = path;
            nodeData.basename = basename;
            nodeData.isDir = isDir;
            nodeData.isFile = ~isDir;
            nodeData.isPopulated = ~isDir;
            out = this.oldUitreenode(path, basename, icon, true);
            set(out, 'userdata', nodeData);
            out.setLeafNode(false);
            out.setAllowsChildren(isDir);
            if isDir
                out.add(this.buildDummyNode());
            end
        end
        
        function out = buildDummyNode(this)
            nodeData = mprojectnavigator.internal.FileNodeData('<dummy>', false);
            nodeData.isDummy = true;
            nodeData.isPopulated = true;
            nodeData.isFile = false;
            icon = myIconPath('none');
            out = this.oldUitreenode('<dummy>', 'Loading...', icon, true);
            set(out, 'userdata', nodeData);
        end
        
        function repopulateNode(this, node)
            tree.removeAllChildren(node);
            this.refreshNode(node);
        end
        
        function populateNode(this, node)
            this.refreshNode(node);
        end
        
        function refreshNode(this, node)
            this.refreshFileNode(node);
        end
        
        function refreshFileNode(this, node)
            nodeData = get(node, 'userdata');
            file = nodeData.path;
            nodesToAdd = {};
            if nodeData.isDir
                childNodeValues = getChildNodeValues(node);
                d = dir2(file);
                fileNames = {d.name};
                filePaths = fullfile(file, fileNames);
                %TODO: Technically, this is a bug, because it won't display
                %files that are named '<dummy>'. But who would make one of
                %those?
                filesToAdd = sortCaseInsensitive(setdiff(filePaths, childNodeValues));
                filesToRemove = setdiff(childNodeValues, filePaths);
                [~,ixToRemove] = ismember(filesToRemove, childNodeValues);
                for i = 1:numel(filesToAdd)
                    nodesToAdd{end+1} = this.buildFileNode(filesToAdd{i}); %#ok<AGROW>
                end
                this.treePeer.remove(node, ixToRemove-1);
                this.treePeer.add(node, [nodesToAdd{:}]);
            else
                % Plain file: nothing to do
            end
        end
        
        function nodeExpanded(this, src, evd) %#ok<INUSL>
            this.refreshNode(evd.getCurrentNode);
        end
        
        function treeMousePressed(this, hTree, eventData) %#ok<INUSL>
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
                if nodeData.isDir
                    % Toggle expansion
                    % Actually, that's the default behavior for JTree, so do
                    % nothing.
                    % this.setRootPath(nodeData.path);
                else
                    % File node was double-clicked
                    edit(nodeData.path);
                end
            end
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
            menuItemMlintReport = JMenuItem('M-Lint Report');
            menuItemCdToHere = JMenuItem('CD to Here');
            menuItemTerminalHere = JMenuItem('Terminal Here');
            menuItemPowerShellHere = JMenuItem('PowerShell Here');
            menuItemRevealInDesktop = JMenuItem(sprintf('Reveal in %s', fileShellName));
            menuItemCopyPath = JMenuItem('Copy Path');
            menuItemCopyRelativePath = JMenuItem('Copy Relative Path');
            menuItemExpandAll = JMenuItem('Expand All');
            menuItemDirUp = JMenuItem('Go Up a Directory');
            menuItemPinThis = JMenuItem('Pin This Directory');
            menuOptions = JMenu('Options');
            menuItemSyncToEditor = JCheckBoxMenuItem('Sync to Editor');
            menuItemSyncToEditor.setSelected(this.navigator.syncToEditor);
            menuPath = JMenu('Path');
            
            % Only enable edit if there is a selection or click target
            isTargetFile = (~isempty(nodeData) && nodeData.isFile);
            isTargetDir = (~isempty(nodeData) && nodeData.isDir);
            isTargetFileOrDir = (~isempty(nodeData) && (nodeData.isFile || nodeData.isDir));
            isTargetEditable =  isTargetFile || ~isempty(this.treePeer.getSelectedNodes);
            isTargetMfile = isTargetFile && endsWith(nodeData.path, '.m', 'IgnoreCase',true);
            isDocable = isTargetDir || isTargetMfile;
            isMlintable = isTargetDir || isTargetMfile;
            menuItemEdit.setEnabled(isTargetEditable);
            menuItemViewDoc.setEnabled(isTargetDir || isTargetMfile);
            menuItemMlintReport.setEnabled(isTargetDir || isTargetMfile);
            menuItemRevealInDesktop.setEnabled(isTargetFileOrDir);
            menuItemCopyPath.setEnabled(isTargetFileOrDir);
            menuItemCopyRelativePath.setEnabled(isTargetFileOrDir);
            
            pathParts = strsplit(this.rootPath, filesep);
            if isempty(pathParts{1})
                pathParts{1} = '/';
            end
            for i = 1:numel(pathParts)
                label = pathParts{i};
                menuItem = JMenuItem(label);
                partialPath = fullfile(pathParts{1:i});
                setCallback(menuItem, {@ctxPathElementCallback, this, partialPath});
                menuPath.add(menuItem);
            end
            
            hasUsableTerminal = mprojectnavigator.internal.Utils.isSupportedTerminalInstalled;
            
            function setCallback(item, callback)
                set(handle(item,'CallbackProperties'), 'ActionPerformedCallback', callback);
            end
            setCallback(menuItemEdit, {@ctxEditCallback, this, nodeData});
            setCallback(menuItemViewDoc, {@ctxViewDocCallback, this, nodeData});
            setCallback(menuItemMlintReport, {@ctxMlintReportCallback, this, nodeData});
            setCallback(menuItemCdToHere, {@ctxCdToHereCallback, this, nodeData});
            setCallback(menuItemTerminalHere, {@ctxTerminalHereCallback, this, nodeData});
            setCallback(menuItemPowerShellHere, {@ctxPowerShellHereCallback, this, nodeData});
            setCallback(menuItemRevealInDesktop, {@ctxRevealInDesktopCallback, this, nodeData});
            setCallback(menuItemCopyPath, {@ctxCopyPathCallback, this, nodeData, 'absolute'});
            setCallback(menuItemCopyRelativePath, {@ctxCopyPathCallback, this, nodeData, 'relative'});
            setCallback(menuItemExpandAll, {@ctxExpandAllCallback, this});
            setCallback(menuItemDirUp, {@ctxDirUpCallback, this});
            setCallback(menuItemPinThis, {@ctxPinThisCallback, this, nodeData});
            setCallback(menuItemSyncToEditor, {@ctxSyncToEditorCallback, this});
            
            if isTargetEditable
                jmenu.add(menuItemEdit);
            end
            if isDocable
                jmenu.add(menuItemViewDoc);
            end
            if isMlintable
                jmenu.add(menuItemMlintReport);
            end
            if isTargetEditable || isDocable || isMlintable
                jmenu.addSeparator;
            end
            if isTargetFileOrDir
                jmenu.add(menuItemRevealInDesktop);
                jmenu.add(menuItemCopyPath);
                jmenu.add(menuItemCopyRelativePath);
                jmenu.addSeparator;
            end
            if isTargetFileOrDir
                jmenu.add(menuItemCdToHere);
                if hasUsableTerminal
                    jmenu.add(menuItemTerminalHere);
                end
                if mprojectnavigator.internal.Utils.isPowerShellInstalled
                    jmenu.add(menuItemPowerShellHere);
                end
                jmenu.addSeparator;
            end
            jmenu.add(menuItemDirUp);
            jmenu.add(menuPath);
            if isTargetDir
                jmenu.add(menuItemPinThis);
            end
            jmenu.addSeparator;
            jmenu.add(menuItemExpandAll);
            jmenu.addSeparator;
            menuOptions.add(menuItemSyncToEditor);
            jmenu.add(menuOptions);
            
            out = jmenu;
        end
    end
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
fprintf('Changed directory to %s\n', path);
end

function ctxRevealInDesktopCallback(src, evd, this, nodeData) %#ok<INUSL>
mprojectnavigator.internal.Utils.guiRevealFileInDesktopFileBrowser(nodeData.path);
end

function ctxTerminalHereCallback(src, evd, this, nodeData) %#ok<INUSL>
dir = ifthen(nodeData.isDir, nodeData.path, fileparts(nodeData.path));
mprojectnavigator.internal.Utils.openTerminalSessionAtDir(dir);
end

function ctxPowerShellHereCallback(src, evd, this, nodeData) %#ok<INUSL>
dir = ifthen(nodeData.isDir, nodeData.path, fileparts(nodeData.path));
mprojectnavigator.internal.Utils.openPowerShellAtDir(dir);
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
this.expandNode(this.treePeer.getRoot, 'recurse');
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

function ctxSyncToEditorCallback(src, evd, this) %#ok<INUSL>
this.navigator.setSyncToEditor(src.isSelected);
end

function ctxPathElementCallback(src, evd, this, path) %#ok<INUSL>
this.setRootPath(path);
end


