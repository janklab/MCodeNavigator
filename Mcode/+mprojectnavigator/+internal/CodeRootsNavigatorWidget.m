classdef CodeRootsNavigatorWidget < mprojectnavigator.internal.TreeWidget
    
    properties
        navigator
    end
    
    methods
        function this = CodeRootsNavigatorWidget(parentNavigator)
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
            this.jTree.setRootVisible(false);
            
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
        
        function out = buildDummyNode(this)
            nodeData = CodeRootsNodeData('<dummy>');
            nodeData.isPopulated = true;
            nodeData.isFile = false;
            icon = myIconPath('none');
            out = this.oldUitreenode('<dummy>', 'Loading...', icon, true);
            set(out, 'userdata', nodeData);
        end
        
        function out = buildRootNode(this)
            nodeData = CodeRootsNodeData('root', 'root');
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
            nodeData = CodeRootsNodeData('codepaths', label);
            nodeData.pathsType = pathsType;
            icon = myIconPath('topfolder');
            out = this.createNode('codepaths', label, nodeData, [], icon);
        end
        
        function out = buildCodePathNode(this, codePath)
            [parentDir,baseName] = fileparts(codePath);
            dirParts = strsplit(parentDir, filesep);
            parentDirReverse = strjoin(flip(dirParts), '/');
            label = sprintf('%s - (%s)', baseName, parentDirReverse);
            nodeData = CodeRootsNodeData('codepath', label);
            nodeData.path = codePath;
            nodeData.isDir = true;
            nodeData.isFile = false;
            icon = myIconPath('folder');
            out = this.createNode('codepath', label, nodeData, [], icon);
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
            out = this.oldUitreenode(path, basename, icon, true);
            nodeData = CodeRootsNodeData('file', path);
            nodeData.path = path;
            nodeData.basename = basename;
            nodeData.isDir = isDir;
            nodeData.isFile = ~isDir;
            nodeData.isPopulated = ~isDir;
            set(out, 'userdata', nodeData);
            out.setLeafNode(false);
            out.setAllowsChildren(isDir);
            if isDir
                out.add(this.buildDummyNode());
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
            childNodeValues = getChildNodeValues(node);
            nodesToAdd = {};
            tf = ismember(childNodeValues, paths);
            ixToRemove = find(~tf);
            tf = ismember(paths, childNodeValues);
            ixToAdd = find(~tf);
            for i = 1:numel(ixToAdd)
                newCodePathNode = this.buildCodePathNode(paths{ixToAdd(i)});
                nodesToAdd{end+1} = newCodePathNode; %#ok<*AGROW>
            end
            this.treePeer.remove(node, ixToRemove-1);
            this.treePeer.add(node, [nodesToAdd{:}]);
        end
        
        function refreshCodePathNode(this, node)
            nodeData = get(node, 'userdata');
            file = nodeData.path;
            nodesToAdd = {};
            childNodeValues = getChildNodeValues(node);
            if isFolder(file)
                d = dir2(file);
                fileNames = {d.name};
                filePaths = fullfile(file, fileNames);
                filesToAdd = sortCaseInsensitive(setdiff(filePaths, childNodeValues));
                filesToRemove = setdiff(childNodeValues, filePaths);
                [~,ixToRemove] = ismember(filesToRemove, childNodeValues);
                for i = 1:numel(filesToAdd)
                    nodesToAdd{end+1} = this.buildFileNode(filesToAdd{i});
                end
            else
                ixToRemove = 1:numel(childNodeValues);
            end
            this.treePeer.remove(node, ixToRemove-1);
            this.treePeer.add(node, [nodesToAdd{:}]);
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
                    nodesToAdd{end+1} = this.buildFileNode(filesToAdd{i});
                end
                this.treePeer.remove(node, ixToRemove-1);
                this.treePeer.add(node, [nodesToAdd{:}]);
            else
                % Plain file: nothing to do
            end
        end
        
        function refreshNodeSingle(this, node)
            nodeData = get(node, 'userdata');
            switch nodeData.type
                case 'root'             % NOP: its contents are static
                case 'codepaths';       this.refreshCodePathsNode(node);
                case 'codepath';        this.refreshCodePathNode(node);
                case 'file';            this.refreshFileNode(node);
                otherwise
                    refreshNodeSingle@mprojectnavigator.internal.TreeWidget(this, node);
            end
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
                else
                    % File node was double-clicked
                    edit(nodeData.path);
                end
            else
                % Ignore
            end
        end
        
        function out = setupTreeContextMenu(this, node, nodeData)
            import javax.swing.*
            
            fileShellName = mprojectnavigator.internal.Utils.osFileBrowserName;
            
            if ~isempty(node) && ~this.isInSelection(node)
                this.setSelectedNode(node);
            end
            
            jmenu = JPopupMenu;
            menuItemBogus = JMenuItem('Bogus');
            
            jmenu.add(menuItemBogus);
            
            out = jmenu;
        end
    end
end
