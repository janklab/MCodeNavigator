classdef (Abstract) TreeWidget < handle
    % A widget based on UITreePeer
    
    properties
        % The main JPanel containing this widget
        panel
        % The Matlab UITreePeer
        treePeer
        % The Matlab UITreePeer, wrapped in a handle
        treePeerHandle
        % The underlying raw JTree
        jTree
        % The underlying raw JTree, wrapped in a handle
        jTreeHandle
    end
    
    methods
        function this = TreeWidget()
            this.initializeGui();
        end
        
        function initializeGui(this)
            % Initialize GUI, constructing components
            import javax.swing.*
            import java.awt.*
            
            peer = javaObjectEDT('net.apjanke.mprojectnavigator.swing.UITreePeer2');
            %try peer = javaObjectEDT(peer); catch; end
            this.treePeer = peer;
            peer_h = handle(peer, 'CallbackProperties');
            this.treePeerHandle = peer_h;
            jTreeObj = this.getJTreeFromUiPeer(peer);
            this.jTree = jTreeObj;
            this.jTreeHandle = handle(jTreeObj, 'CallbackProperties');
            
            % Set callback functions
            set(this.treePeerHandle, 'NodeExpandedCallback', {@nodeExpandedCallback, this});
            set(this.treePeerHandle, 'NodeSelectedCallback', {@nodeSelectedCallback, this});
            set(this.jTreeHandle, 'MousePressedCallback', {@treeMousePressedCallback, this});
            set(this.jTreeHandle, 'MouseMovedCallback', {@treeMouseMovedCallback, this});
            
            this.panel = JPanel(BorderLayout);
            this.panel.add(peer.getScrollPane);
        end
        
        function dispose(this)
            set(this.treePeerHandle, 'NodeExpandedCallback', []);
            set(this.treePeerHandle, 'NodeSelectedCallback', []);
            set(this.jTreeHandle, 'MousePressedCallback', []);
            set(this.jTreeHandle, 'MouseMovedCallback', []);
        end
        
        function out = getJTreeFromUiPeer(this, peer) %#ok<INUSL>
            mustBeA(peer, 'com.mathworks.hg.peer.UITreePeer');
            treeScrollPane = peer.getScrollPane;
            out = treeScrollPane.getViewport.getComponent(0);
        end
        
        function expandNode(this, node, mode)
            if nargin < 3 || isempty(mode);  mode = 'single';  end
            if ~ismember(mode, {'single','recurse'})
                error('Invalid mode: %s', mode);
            end
            nodePath = this.treePathForNode(node);
            EDT('expandPath', this.jTree, nodePath);
            pause(0.0005); % Pause to allow lazy-loaded children to be filled in
            if isequal(mode, 'recurse')
                for i = 1:node.getChildCount
                    this.expandNode(node.getChildAt(i-1), recurse);
                end
            end
        end
        
        function refreshNodeSingleWrapper(this, node)
            try
                logdebugf('refreshNodeWrapper(): refreshing %s', char(node.toString));
                nodeData = get(node, 'userdata');
                % Avoid redundant refreshes
                if nodeData.isRefreshing
                   logdebugf('refreshNodeWrapper(): node is already refreshing; skipping redundant refresh');
                   return;
                end
                nodeData.isRefreshing = true;
                this.refreshNodeSingle(node);
                nodeData.isPopulated = true;
                nodeData.isDirty = false;
                nodeData.isRefreshing = false;
            catch err
                nodeData.isRefreshing = false;
                % Display errors in the GUI
                warning('Error while refreshing node ''%s'': %s', nodeData.name, ...
                    err.message);
                this.treePeer.removeAllChildren(node);
                this.treePeer.add(node, this.buildErrorMessageNode(['ERROR: ' err.message]));
            end
        end
        
        function repopulateNode(this, node)
            this.treePeer.removeAllChildren(node);
            this.populateNode(node);
        end
        
        function populateNode(this, node)
            this.refreshNodeSingle(node);
            nodeData = get(node, 'userdata');
            nodeData.isPopulated = true;
        end
        
        function refreshNode(this, node, doPopulate)
            if nargin < 3 || isempty(doPopulate);  doPopulate = false; end
            nodeData = get(node, 'userdata');
            if ~nodeData.isPopulated && ~doPopulate
                return;
            end
            if ~nodeData.isDirty
                return;
            end
            this.refreshNodeSingleWrapper(node);
            for i = 1:node.getChildCount
                this.refreshNode(node.getChildAt(i-1));
            end
        end
        
        function markDirty(this, node) %#ok<INUSL>
            nodeData = get(node, 'userdata');
            nodeData.isDirty = true;
        end
        
        function refreshNodeSingle(this, node) %#ok<INUSL>
            nodeData = get(node, 'userdata');
            switch nodeData.type
                case 'error_message'        % NOP
                otherwise
                    error('Unrecognized nodeData.type: ''%s''', nodeData.type);
            end
        end
        
        function nodeExpanded(this, src, evd) %#ok<INUSL>
            node = evd.getCurrentNode;
            % Mark the node dirty so it always picks up fresh data in response
            % to user input
            this.markDirty(node);
            this.refreshNode(node, true);
        end
        
        function gentleRecursiveRefresh(this, node)
            % Refresh all nodes that are already populated
            %logdebug('gentleRecursiveRefresh(): {}', node);
            nodeData = get(node, 'userdata');
            if ~nodeData.isPopulated
                logdebug('gentleRecursiveRefresh(): not populated. skipping: {}', node);
                return;
            else
                this.refreshNodeWrapper(node);
                for i = 1:node.getChildCount
                    this.gentleRecursiveRefresh(node.getChildAt(i-1));
                end
            end
        end
        
        function removeNodesByIndex(this, node, ix)
        % Remove nodes, properly updating the tree
        %
        % BUG: This is not currently working! The attempted removal has no
        % effect.
        %
        % This is a hack needed because the Matlab UITreePeer class does not
        % seem to fire nodesWereRemoved() events when calling its remove()
        % method instead of removeAll.
        %
        % nodesWereRemoved(node, indexes) takes the parent node the nodes were
        % removed from, and an array of child indexes under it
        ix = ix - 1; % Switch to zero-indexing for Java
        for i = 1:numel(ix)
            EDT('remove', node, ix(i));
        end
        EDT('nodesWereRemoved', this.treePeer, node, ix);
        end
        
        function setNodeName(this, node, name)
            node.setName(name);
            this.fireNodeChanged(node);
        end
        
        function out = treePathForNode(this, node)
            % Get the TreePath to a node in this tree
            
            % This is a hack needed because the straight TreePath(rawNodePath)
            % constructor doesn't work, probably due to Matlab/Java autoboxing issues
            rawNodePath = node.getPath;
            nodePath = this.jTree.getPathForRow(0);
            for i = 2:numel(rawNodePath)
                nodePath = nodePath.pathByAddingChild(rawNodePath(i));
            end
            out = nodePath;
        end
        
        function out = isInSelection(this, node)
            selection = this.treePeer.getSelectedNodes;
            for i = 1:numel(selection)
                if isequal(node, selection(i))
                    out = true;
                    return;
                end
            end
            out = false;
        end
        
        function setSelectedNode(this, node)
            this.treePeer.setSelectedNode(node);
        end
        
        function scrollToNode(this, node)
            EDT('scrollPathToVisible', this.jTree, this.treePathForNode(node));
        end
        
        function out = oldUitreenode(this, x, text, icon, hasChildren) %#ok<INUSL>
            % Use the old style uitreenode because it plays well with plain JFrames
            try
                out = uitreenode('v0', x, text, icon, hasChildren);
            catch  % old Matlab versions don't have the 'v0' option
                out = uitreenode(x, text, icon, hasChildren);
            end
        end
        
        function treeMousePressed(this, src, evd) %#ok<INUSD>
        end
        
        function treeMouseMoved(this, src, evd) %#ok<INUSD>
        end
        
        function nodeSelected(this, src, evd, bogus) %#ok<INUSD>
        end
        
        function fireNodeChanged(this, node)
            this.treePeer.nodeChanged(node);
            %treeModel = getJavaPrivateFieldViaReflection(this.treePeer, 'fuitreemodel');
            %EDT('nodeChanged', treeModel, node);
        end
    end
end

function treeMousePressedCallback(src, evd, this)
this.treeMousePressed(src, evd)
end

function treeMouseMovedCallback(src, evd, this)
% Handle tree mouse movement callback - used to set the tooltip & context-menu
this.treeMouseMoved(src, evd);
end

function nodeExpandedCallback(src, evd, this)
this.nodeExpanded(src, evd);
end

function nodeSelectedCallback(src, evd, this)
this.nodeSelected(src, evd);
end

