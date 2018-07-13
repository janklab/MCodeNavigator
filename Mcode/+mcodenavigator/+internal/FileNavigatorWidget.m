classdef FileNavigatorWidget < mcodenavigator.internal.FileWidgetBase
    
    properties
        rootPath = getpref(PREFGROUP, 'files_pinnedDir', pwd);
    end
    
    methods
        function this = FileNavigatorWidget(parentNavigator)
            this = this@mcodenavigator.internal.FileWidgetBase(parentNavigator);
        end
        
        function initializeGui(this)
            import java.awt.*
            import javax.swing.*
            
            initializeGui@mcodenavigator.internal.TreeWidget(this);
            
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
        
        function out = getFileRootNodes(this)
        out = this.treePeer.getRoot();
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
            nodeData = mcodenavigator.internal.FileNodeData(path, isDir);
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
            nodeData = mcodenavigator.internal.FileNodeData('<dummy>', false);
            nodeData.isDummy = true;
            nodeData.isPopulated = true;
            nodeData.isFile = false;
            icon = myIconPath('none');
            out = this.oldUitreenode('<dummy>', 'Loading...', icon, true);
            set(out, 'userdata', nodeData);
        end
        
        function refreshNodeSingle(this, node)
            nodeData = get(node, 'userdata');
            switch nodeData.type
                case 'root'             % NOP: its contents are static
                case 'file';            this.refreshFileNode(node);
                otherwise
                    refreshNodeSingle@mcodenavigator.internal.TreeWidget(this, node);
            end
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
        
        function addSubclassContextMenuItems(this, jmenu, node, nodeData) %#ok<INUSL>
            import javax.swing.*

            function setCallback(item, callback)
                set(handle(item,'CallbackProperties'), 'ActionPerformedCallback', callback);
            end
            menuItemDirUp = JMenuItem('Go Up a Directory');
            menuItemPinThis = JMenuItem('Pin This Directory');
            menuPath = JMenu('Path');

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
            
            setCallback(menuItemDirUp, {@ctxDirUpCallback, this});
            setCallback(menuItemPinThis, {@ctxPinThisCallback, this, nodeData});
            isTargetDir = (~isempty(nodeData) && nodeData.isDir);
            jmenu.add(menuPath);
            jmenu.add(menuItemDirUp);
            if isTargetDir
                jmenu.add(menuItemPinThis);
            end
            jmenu.addSeparator;
        end
        
    end
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

function ctxPathElementCallback(src, evd, this, path) %#ok<INUSL>
this.setRootPath(path);
end




