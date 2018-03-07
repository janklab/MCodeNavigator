classdef ClassInheritanceWidget < mprojectnavigator.internal.TreeWidget
    
    properties
        rootClassDefn
    end
    
    methods
        function this = ClassInheritanceWidget(classDefn)
            this = this@mprojectnavigator.internal.TreeWidget();
            if nargin == 0
                return;
            end
            mustBeA(classDefn, 'meta.class');
            this.rootClassDefn = classDefn;
        end
        
        function initializeGui(this)
            import java.awt.*
            import javax.swing.*
            
            initializeGui@mprojectnavigator.internal.TreeWidget(this);
            
            tree = this.treePeer;
            treePane = tree.getScrollPane;
            treePane.setMinimumSize(Dimension(50, 50));
            
            this.jTree.setShowsRootHandles(true);
            this.jTree.setRootVisible(true);
            
            this.completeRefreshGui;
        end
        
        function completeRefreshGui(this)
            root = this.buildClassNode(this.rootClassDefn);
            this.treePeer.setRoot(root);
            this.expandNode(root, 'recurse');
        end
        
        function out = createNode(this, tag, label, nodeData, allowsChildren, icon)
            if nargin < 5 || isempty(allowsChildren); allowsChildren = true; end
            if nargin < 6 || isempty(icon);  icon = [];  end
            
            out = this.oldUitreenode(tag, label, icon, true);
            out.setAllowsChildren(allowsChildren);
            set(out, 'userdata', nodeData);
        end
        
        
        function out = buildClassNode(this, classDefn)
            nodeData = mprojectnavigator.internal.ClassInheritanceNodeData;
            nodeData.type = 'class';
            nodeData.name = classDefn.Name;
            nodeData.isPopulated = true;
            label = classDefn.Name;
            out = this.createNode(label, label, nodeData, ~isempty(classDefn.SuperclassList));
            for i = 1:numel(classDefn.SuperclassList)
                superclassNode = this.buildClassNode(classDefn.SuperclassList(i));
                out.add(superclassNode);
            end
        end
        
        function refreshNodeSingle(this, node)
            nodeData = get(node, 'userdata');
            switch nodeData.type
                case 'class'        % NOP; its contents are static
                otherwise
                    refreshNodeSingle@mprojectnavigator.internal.TreeWidget(this, node);
            end
        end
        
        function treeMousePressed(this, hTree, eventData) %#ok<INUSL>
            % Mouse click callback
            
            % Get the clicked node
            clickX = eventData.getX;
            clickY = eventData.getY;
            jtree = eventData.getSource;
            treePath = jtree.getPathForLocation(clickX, clickY);
            if ~isempty(treePath)
                node = treePath.getLastPathComponent;
                nodeData = get(node, 'userdata');
            else
                node = [];
                nodeData = [];
            end
            % This method of detecting right-clicks avoids confusion with Cmd-clicks on Mac
            isRightClick = eventData.getButton == java.awt.event.MouseEvent.BUTTON3;
            if isRightClick
                % Right-click
                jmenu = this.setupTreeContextMenu(node, nodeData);
                jmenu.show(jtree, clickX, clickY);
                jmenu.repaint;
                %TODO: Do I need to explicitly dispose of that JMenu?
            end
        end
        
        function out = setupTreeContextMenu(this, node, nodeData)
            import javax.swing.*

            if ~isempty(node) && ~this.isInSelection(node)
                this.setSelectedNode(node);
            end
            
            jmenu = JPopupMenu;
            menuItemEdit = JMenuItem('Edit');
            menuItemViewDoc = JMenuItem('View Doc');
            menuItemMethodsView = JMenuItem('Methods View');
            
            isTargetNode = ~isempty(node);
            menuItemEdit.setEnabled(isTargetNode);
            menuItemViewDoc.setEnabled(isTargetNode);
            menuItemMethodsView.setEnabled(isTargetNode);
            
            function setCallback(item, callback)
                set(handle(item,'CallbackProperties'), 'ActionPerformedCallback', callback);
            end
            setCallback(menuItemEdit, {@ctxEditCallback, this, nodeData});
            setCallback(menuItemViewDoc, {@ctxViewDocCallback, this, nodeData});
            setCallback(menuItemMethodsView, {@ctxMethodsViewCallback, this, nodeData});
            
            jmenu.add(menuItemEdit);
            jmenu.add(menuItemViewDoc);
            jmenu.add(menuItemMethodsView);
            out = jmenu;
        end
        
        function out = showInDialog(this)
            import javax.swing.*
            import java.awt.*
            dialog = javaObjectEDT('javax.swing.JDialog');
            dialog.setTitle([this.rootClassDefn.Name ' Inheritance']);
            dialog.setSize(500, 600);
            dialog.getContentPane.add(this.panel, BorderLayout.CENTER);
            dialog.setVisible(true);
            out = dialog;
        end
        
        function editNode(this, nodeData) %#ok<INUSL>
            switch nodeData.type
                case 'class'
                    edit(nodeData.name);
                otherwise
                    logdebug('Unrecognized node type for editNode(): %s', nodeData.type);
            end
        end
    end
end

function ctxEditCallback(src, evd, this, nodeData) %#ok<INUSL>
editNode(this, nodeData);
end

function ctxViewDocCallback(src, evd, this, nodeData) %#ok<INUSL>
switch nodeData.type
    case 'class'
        doc(nodeData.name);
    otherwise
        % Shouldn't get here
        logdebug('Doc viewing is not supported for node type %s', nodeData.type);
end
end

function ctxMethodsViewCallback(src, evd, this, nodeData) %#ok<INUSL>
methodsview(nodeData.name);
end
