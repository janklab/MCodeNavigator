classdef Navigator < handle
    % The whole Navigator UI, corresponding to a frame with multiple panels
    %
    % This is intended to be a singleton, with only one active at a time in a
    % Matlab session.
    
    properties (Constant)
        NoAutoloadFiles = {
            [matlabroot '/toolbox/matlab/codetools/mdbstatus.m']
            };
    end
    properties
        panel
        fileNavigator
        classesNavigator
        codeNavigator
        % Whether to keep node selections in sync with Matlab's editor
        syncToEditor = getpref(PREFGROUP, 'files_syncToEditor', true);
        editorTracker
        codebase
    end
    properties (Dependent)
        Visible
    end
    
    methods
        function this = Navigator()
            this.fileNavigator = mcodenavigator.internal.FileNavigatorWidget(this);
            this.classesNavigator = mcodenavigator.internal.ClassesNavigatorWidget(this);
            this.codeNavigator = mcodenavigator.internal.CodeRootsNavigatorWidget(this);
            this.codebase = mcodenavigator.internal.CodeBase;
            this.initializeGui();
        end
        
        function initializeGui(this)
            import java.awt.*
            import javax.swing.*
            
            this.panel = JPanel;
            this.panel.setLayout(BorderLayout);
            tabbedPane = JTabbedPane;
            
            this.fileNavigator.initializeGui;
            this.codeNavigator.initializeGui;
            this.classesNavigator.initializeGui;
            
            tabbedPane.add('Classes', this.classesNavigator.panel);
            tabbedPane.add('Code', this.codeNavigator.panel);
            tabbedPane.add('Files', this.fileNavigator.panel);
            tabSelection = getpref(PREFGROUP, 'nav_TabSelection', []);
            if ~isempty(tabSelection)
                try
                    tabbedPane.setSelectedIndex(tabSelection);
                catch
                    % quash
                end
            end
            hTabbedPane = handle(tabbedPane, 'CallbackProperties');
            hTabbedPane.StateChangedCallback = @tabbedPaneStateCallback;
            
            this.panel.add(tabbedPane, BorderLayout.CENTER);
            
            if this.syncToEditor
                this.setUpEditorTracking();
            end
        end
        
        function dispose(this)
            this.fileNavigator.dispose;
            this.classesNavigator.dispose;
            this.tearDownEditorTracking;
        end
        
        function setSyncToEditor(this, newState)
            if newState == this.syncToEditor
                return
            end
            this.syncToEditor = newState;
            if this.syncToEditor
                this.setUpEditorTracking();
            else
                this.tearDownEditorTracking();
            end
            setpref(PREFGROUP, 'files_syncToEditor', true);
        end
        
        function editorFrontFileChanged(this, file)
            if ~this.syncToEditor
                return;
            end
            [~,basename,ext] = fileparts(file);
            logdebug('editorFrontFileChanged: %s', [basename ext]);
            % Avoid doing expensive tree expansion for Matlab files that tend to
            % pop up in the debugger due to Matlab's self-hosting nature and
            % their internal use of try/catch
            % TODO: Allow navigation to them if they're already visible
            if ismember(file, this.NoAutoloadFiles)
                logdebug('editorFrontFileChanged: skipping autoload of known-funny file %s', ...
                    file);
                return;
            end
            try
                this.fileNavigator.revealFile(file);
            catch err
                % Ignore all errors. These can happen if the user is working on
                % a file that's in flux and has an invalid definition, which is
                % a common case when developing code
                logdebug('editorFrontFileChanged(): caught error while revealing filein File Navigator; ignoring. Error: %s', ...
                    err.message);
            end
            try
                % Find out what that file defines, and update the code navigator
                defn = this.codebase.defnForMfile(file);
                this.classesNavigator.revealDefn(defn, file);
            catch err
                logdebug('editorFrontFileChanged(): caught error while revealing file in Classes Navigator; ignoring. Error: %s', ...
                    err.message);
            end
            try
                this.codeNavigator.revealFile(file);
            catch err
                logdebug('editorFrontFileChanged(): caught error while revealing file in Code Navigator; ignoring. Error: %s', ...
                    err.message);
            end
        end
        
        function editorFileSaved(this, file)
            [~,basename,ext] = fileparts(file);
            logdebug('editorFileSaved: %s', [basename ext]);
            this.classesNavigator.fileChanged(file);
        end

        function setUpEditorTracking(this)
            tracker = javaObjectEDT('net.apjanke.mcodenavigator.swing.EditorFileTracker');
            tracker.setFrontFileChangedMatlabCallback('mcodenavigator.internal.editorFileChangedCallback');
            tracker.setFileSavedMatlabCallback('mcodenavigator.internal.editorFileSavedCallback');
            tracker.attachToMatlab;
            this.editorTracker = tracker;
            logdebug('setUpEditorTracking(): done');
        end
        
        function tearDownEditorTracking(this)
            if isempty(this.editorTracker)
                return;
            end
            this.editorTracker.detachFromMatlab;
            this.editorTracker = [];
            logdebug('tearDownEditorTracking(): done');
        end
        
    end
end

function tabbedPaneStateCallback(tabbedPane, evd) %#ok<INUSD>
tabIndex = tabbedPane.getSelectedIndex;
setpref(PREFGROUP, 'nav_TabSelection', tabIndex);
end

