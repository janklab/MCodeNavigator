classdef ClassStructureWidget
%CLASSSTRUCTUREWIDGET Views class members, methodsview style
%
% This is a detailed informative view, not a navigator control.

    properties
        % The definition for the class this is displaying
        classDefn
        % The main Swing panel this widget displays in
        panel
        % The main GroupTable showing the class structure
        groupTable
    end
    
    methods
        function this = ClassStructureWidget
            import javax.swing.*
            import java.awt.*
            this.groupTable = javaObjectEDT('com.jidesoft.grid.GroupTable');
            this.groupTable.setShowVerticalLines(false);
            p = JPanel;
            p.setLayout(BorderLayout);
            scrollPane = javaObjectEDT('javax.swing.JScrollPane', this.groupTable);
            p.add(scrollPane, BorderLayout.CENTER);
            this.panel = p;
        end
        
        function this = set.classDefn(this, newClassDefn)
            this.classDefn = newClassDefn;
            this.completeRefreshGui;
        end
        
        function completeRefreshGui(this)
            if isempty(this.classDefn)
                tableModel = javaObjectEDT('javax.swing.DefaultTableModel');
                groupTableModel = javaObjectEDT('com.jidesoft.grid.DefaultGroupTableModel', tableModel);
                this.groupTable.setModel(groupTableModel);
            else
                [tableModel,groupTableModel] = this.buildTableModelsForClassDefn(); %#ok<ASGLU>
                this.groupTable.setModel(groupTableModel);
                sortableTableModel = this.groupTable.getModel;
                sortableTableModel.sortColumn(3);
            end
        end
        
        function [tableModel,groupTableModel] = buildTableModelsForClassDefn(this)
            %BUILDTABLEMODELSFORCLASSDEFN
            
            % Columns:
            % Type  (Property/Method/Event/Enumeration)
            % Source ('Defined'/'Inherited')
            % Qualifiers
            % Access
            % Hidden
            % Name
            % Arguments
            % Argouts
            % DefiningClass (''/name of class)
            
            klass = this.classDefn;
            nMembers = numel(klass.PropertyList) + numel(klass.MethodList) ...
                + numel(klass.EventList) + numel(klass.EnumerationMemberList);
            c = cell(nMembers, 8);
            iRow = 0;
            % Properties
            for i = 1:numel(klass.PropertyList)
                iRow = iRow + 1;
                prop = klass.PropertyList(i);
                c{iRow,1} = 'Property';
                c{iRow,2} = ifthen(isequal(klass, prop.DefiningClass), 'Defined', 'Inherited');
                c{iRow,3} = listPropertyQualsAsString(prop);
                c{iRow,4} = mcodenavigator.internal.Utils.propertyAccessLabel(...
                    prop.GetAccess, prop.SetAccess);
                c{iRow,5} = ifthen(prop.Hidden, 'Hidden', '');
                c{iRow,6} = prop.Name;
                c{iRow,7} = '';
                c{iRow,8} = '';
                c{iRow,9} = ifthen(isequal(klass, prop.DefiningClass), '', ...
                    prop.DefiningClass.Name);
            end
            clear prop
            for i = 1:numel(klass.MethodList)
                iRow = iRow + 1;
                meth = klass.MethodList(i);
                c{iRow,1} = 'Method';
                c{iRow,2} = ifthen(isequal(klass, meth.DefiningClass), 'Defined', 'Inherited');
                c{iRow,3} = listMethodQualsAsString(meth);
                c{iRow,4} = mcodenavigator.internal.Utils.methodAccessLabel(...
                    meth.Access);
                c{iRow,5} = ifthen(meth.Hidden, 'Hidden', '');
                c{iRow,6} = meth.Name;
                c{iRow,7} = ['(' strjoin(meth.InputNames, ', ') ')'];
                argoutStr = strjoin(meth.OutputNames, ', ');
                if numel(meth.OutputNames) > 1
                    argoutStr = ['[' argoutStr ']']; %#ok<AGROW>
                end
                c{iRow,8} = argoutStr;
                c{iRow,9} = ifthen(isequal(klass, meth.DefiningClass), '', ...
                    meth.DefiningClass.Name);
            end
            clear meth
            for i = 1:numel(klass.EventList)
                iRow = iRow + 1;
                event = klass.EventList(i);
                c{iRow,1} = 'Event';
                c{iRow,2} = ifthen(isequal(klass, event.DefiningClass), 'Defined', 'Inherited');
                c{iRow,3} = '';
                c{iRow,4} = mcodenavigator.internal.Utils.eventAccessLabel(...
                    event.NotifyAccess, event.ListenAccess);
                c{iRow,5} = ifthen(event.Hidden, 'Hidden', '');
                c{iRow,6} = event.Name;
                c{iRow,7} = '';
                c{iRow,8} = '';
                c{iRow,9} = ifthen(isequal(klass, event.DefiningClass), '', ...
                    event.DefiningClass.Name);
            end
            clear event
            for i = 1:numel(klass.EnumerationMemberList)
                iRow = iRow + 1;
                enum = klass.EnumerationMemberList(i);
                c{iRow,1} = 'EnumMember';
                c{iRow,2} = 'Defined';
                c{iRow,3} = '';
                c{iRow,4} = '';
                c{iRow,5} = '';
                c{iRow,6} = enum.Name;
                c{iRow,7} = '';
                c{iRow,8} = '';
                c{iRow,9} = '';
            end
            clear enum
            dataVector = javaArray('java.lang.String', size(c));
            for i = 1:size(c, 1)
                jStrs = javaArray('java.lang.String', 9);
                for j = 1:size(c, 2)
                    jStrs(j) = java.lang.String(c{i,j});
                end
                dataVector(i) = jStrs;
            end
            colNames = {'Type', 'Source', 'Qualifiers', 'Access', 'Hidden', ...
                'Name', 'Arguments', 'Argouts', 'DefiningClass'};
            tableModel = javaObjectEDT('javax.swing.table.DefaultTableModel', ...
                dataVector, colNames);
            groupTableModel = javaObjectEDT('com.jidesoft.grid.DefaultGroupTableModel', ...
                tableModel);
            groupTableModel.addGroupColumn(1);
            groupTableModel.addGroupColumn(0);
            groupTableModel.groupAndRefresh;
        end
        
        function out = showInDialog(this)
            import javax.swing.*
            import java.awt.*
            dialog = javaObjectEDT('javax.swing.JDialog');
            dialog.setTitle([this.classDefn.Name ' Class Structure']);
            dialog.setSize(800, 600);
            dialog.getContentPane.add(this.panel, BorderLayout.CENTER);
            dialog.setVisible(true);
            out = dialog;
        end
        
    end
    
end

function out = listPropertyQualsAsString(prop)
quals = {};
if prop.Dependent
    quals{end+1} = 'Dependent';
end
if prop.Constant
    quals{end+1} = 'Constant';
end
if prop.Transient
    quals{end+1} = 'Transient';
end
out = strjoin(quals, ' ');
end

function out = listMethodQualsAsString(meth)
quals = {};
if meth.Static
    quals{end+1} = 'Static';
end
if meth.Abstract
    quals{end+1} = 'Abstract';
end
if meth.Sealed
    quals{end+1} = 'Sealed';
end
out = strjoin(quals, ' ');
end