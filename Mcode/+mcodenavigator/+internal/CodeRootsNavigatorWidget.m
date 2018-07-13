classdef CodeRootsNavigatorWidget < mcodenavigator.internal.FileWidgetBase
    
    methods
        function this = CodeRootsNavigatorWidget(parentNavigator)
            this = this@mcodenavigator.internal.FileWidgetBase(parentNavigator);
            this.initializeGui;
        end
        
        function initializeGui(this)
            import java.awt.*
            import javax.swing.*
            
            initializeGui@mcodenavigator.internal.TreeWidget(this);
            
            tree = this.treePeer;
            treePane = tree.getScrollPane;
            treePane.setMinimumSize(Dimension(50, 50));
            
            this.jTree.setShowsRootHandles(true);
            this.jTree.setRootVisible(false);
            
            this.completeRefreshGui;
        end
        
        function out = getFileRootNodes(this)
            root = this.treePeer.getRoot;
            user = root.getChildAt(0);
            matlab = root.getChildAt(1);
            out = {};
            for i = 1:user.getChildCount
                out{end+1} = user.getChildAt(i-1);
            end
            for i = 1:matlab.getChildCount
                out{end+1} = matlab.getChildAt(i-1);
            end
            out = [out{:}];
        end
        
        function completeRefreshGui(this)
            root = this.buildRootNode();
            this.treePeer.setRoot(root);
            pause(0.005); % Allow widgets to catch up
            % Expand the root node one level, and expand the USER node
            this.expandNode(root);
            this.expandNode(root.getChildAt(0));
            this.populateNode(root.getChildAt(1));
        end
        
        function out = createNode(this, value, label, nodeData, allowsChildren, icon)
            if nargin < 5 || isempty(allowsChildren); allowsChildren = true; end
            if nargin < 6 || isempty(icon);  icon = [];  end
            
            out = this.oldUitreenode(value, label, icon, true);
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
						homeDir = getenv('HOME');
						if startsWith(parentDir, homeDir)
							parentDir = ['~' parentDir(numel(homeDir)+1:end)];
						end
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
            pathInfo = mcodenavigator.internal.CodeBase.matlabPathInfo();
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
                    refreshNodeSingle@mcodenavigator.internal.TreeWidget(this, node);
            end
        end
        
        function addSubclassContextMenuItems(this, jmenu, node, nodeData) %#ok<INUSD>
            import javax.swing.*

            function setCallback(item, callback)
                set(handle(item,'CallbackProperties'), 'ActionPerformedCallback', callback);
            end
        end
    end
end
