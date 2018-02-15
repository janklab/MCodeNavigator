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
            
            this.panel = JPanel(BorderLayout);
            this.panel.add(peer.getScrollPane);
        end
        
        function out = getJTreeFromUiPeer(this, peer)
            mustBeA(peer, 'com.mathworks.hg.peer.UITreePeer');
            treeScrollPane = peer.getScrollPane;
            out = treeScrollPane.getViewport.getComponent(0);
        end
        
        function expandNode(this, node, jTreeObj, recurse)
            mustBeA(jTreeObj, 'javax.swing.JTree');
            tree = jTreeObj;
            nodePath = this.treePathForNode(node, tree);
            tree.expandPath(nodePath);
            if recurse
                pause(0.0005); % Pause to allow lazy-loaded children to be filled in
                for i = 1:node.getChildCount
                    expandNode(node.getChildAt(i-1), jTreeObj, recurse);
                end
            end
        end
        
        function out = treePathForNode(this, node, tree)
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
        
        function out = oldUitreenode(this, x, text, icon, hasChildren)
            % Use the old style uitreenode because it plays well with plain JFrames
            try
                out = uitreenode('v0', x, text, icon, hasChildren);
            catch  % old matlab version don't have the 'v0' option
                out = uitreenode(x, text, icon, hasChildren);
            end
        end
        
    end
end