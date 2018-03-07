classdef FileWidgetBase < mprojectnavigator.internal.TreeWidget
    %FILEWIDGETBASE Common behavior for File and CodeRoots Navigator Widgets
    %
    % A FileWidgetBase is a widget that displays file hierarchies as part of its
    % tree view. It may have one or more nodes that are the "roots" of these
    % file hierarchies.
    
    properties
        navigator
    end
    
    methods
        function this = FileWidgetBase(parentNavigator)
            this.navigator = parentNavigator;
        end
        
        function out = getFileRootNodes(this) %#ok<MANU>
            %GETFILEROOTNODES Get nodes that are roots of file hierarchies
            %
            % Subclasses must override this.
            %
            % Returns an array of UITreeNode or compatible objects.
            out = [];
        end
        
        function revealFile(this, file)
            fileRootNodes = this.getFileRootNodes();
            fileRootNode = [];
            rootNodePath = [];
            for i = 1:numel(fileRootNodes)
                node = fileRootNodes(i);
                nodeData = get(node, 'userdata');
                if strncmpi(file, nodeData.path, numel(nodeData.path))
                    fileRootNode = node;
                    rootNodePath = nodeData.path;
                    break;
                end
            end
            if isempty(fileRootNode)
                logdebug('revealFile(): Ignoring file outside of file navigator roots: %s', ...
                    file);
                return;
            end
            relPath = file(numel(rootNodePath)+2:end);
            relPathParts = strsplit(relPath, filesep);
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
                            this.refreshNode(child, 'force');
                        end
                        foundChild = child;
                        found = true;
                        break;
                    end
                end
            end
            node = fileRootNode;
            this.refreshNode(node, 'populate');
            for iPathPart = 1:numel(relPathParts)
                part = relPathParts{iPathPart};
                [found,foundChild] = findPathComponentInChildren(node, part, ...
                    iPathPart, numel(relPathParts));
                if ~found
                    logwarnf('Could not find file path in tree: %s', file);
                    return;
                end
                node = foundChild;
                this.refreshNode(node, 'populate');
            end
            this.setSelectedNode(node);
            this.scrollToNode(node);            
        end
        
        function treeMousePressed(this, hTree, eventData) %#ok<INUSL>
            % Mouse click callback
            import javax.swing.*
            
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
                    % Let default "expand node" behavior handle it
                elseif nodeData.isFile
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
            menuOptions = JMenu('Options');
            menuItemSyncToEditor = JCheckBoxMenuItem('Sync to Editor');
            menuItemSyncToEditor.setSelected(this.navigator.syncToEditor);
            
            % Only enable edit if there is a selection or click target
            isTargetFile = (~isempty(nodeData) && nodeData.isFile);
            isTargetDir = (~isempty(nodeData) && nodeData.isDir);
            isTargetFileOrDir = (~isempty(nodeData) && (nodeData.isFile || nodeData.isDir));
            isTargetEditable =  isTargetFile;
            isTargetMfile = isTargetFile && endsWith(nodeData.path, '.m', 'IgnoreCase',true);
            isDocable = isTargetMfile || (isTargetDir && isDirDocable(nodeData.path));
            isMlintable = isDocable;
            menuItemEdit.setEnabled(isTargetEditable);
            menuItemViewDoc.setEnabled(isTargetDir || isTargetMfile);
            menuItemMlintReport.setEnabled(isTargetDir || isTargetMfile);
            menuItemRevealInDesktop.setEnabled(isTargetFileOrDir);
            menuItemCopyPath.setEnabled(isTargetFileOrDir);
            menuItemCopyRelativePath.setEnabled(isTargetFileOrDir);
            
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
            this.addSubclassContextMenuItems(jmenu, node, nodeData);
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
RAII.dbstop = withNoDbstopIfAllError; %#ok<STRNU>
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

function ctxSyncToEditorCallback(src, evd, this) %#ok<INUSL>
this.navigator.setSyncToEditor(src.isSelected);
end

function out = isDirDocable(path)
d = dir([path '/*.m']);
if ~isempty(d)
    out = true;
    return
end
d = dir([path '/+*']);
if ~isempty(d)
    out = true;
    return
end
out = false;
end
