classdef TreeWidget < handle
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
            
            peer = com.mathworks.hg.peer.UITreePeer;
            try peer = javaObjectEDT(peer); catch; end
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
        
        function nodeExpanded(this, src, evd) %#ok<INUSD>
        end
        
        function nodeSelected(this, src, evd) %#ok<INUSD>
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

