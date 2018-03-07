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
        frame
        fileNavigator
        classesNavigator
        codeNavigator
        % Whether to keep node selections in sync with Matlab's editor
        syncToEditor = getpref(PREFGROUP, 'files_syncToEditor', true);
        editorTracker;
        codebase;
    end
    properties (Dependent)
        Visible
    end
    
    methods
        function this = Navigator()
            this.fileNavigator = mprojectnavigator.internal.FileNavigatorWidget(this);
            this.classesNavigator = mprojectnavigator.internal.ClassesNavigatorWidget(this);
            this.codeNavigator = mprojectnavigator.internal.CodeRootsNavigatorWidget(this);
            this.codebase = mprojectnavigator.internal.CodeBase;
            this.initializeGui();
        end
        
        function initializeGui(this)
            import java.awt.*
            import javax.swing.*
            
            framePosn = getpref(PREFGROUP, 'nav_Position', []);
            if isempty(framePosn)
                framePosn = [NaN NaN 350 600];
            end
            myFrame = javaObjectEDT('javax.swing.JFrame', 'Project Navigator');
            myFrame.setSize(framePosn(3), framePosn(4));
            if ~isnan(framePosn(1))
                myFrame.setLocation(framePosn(1), framePosn(2));
            end
            % Use the Matlab or custom icon to blend in with the rest of the
            % application.
            mainFrame = com.mathworks.mde.desk.MLDesktop.getInstance.getMainFrame;
            myFrame.setIconImages(mainFrame.getIconImages);
            tabbedPane = JTabbedPane;
            
            this.fileNavigator.initializeGui;
            this.codeNavigator.initializeGui;
            this.classesNavigator.initializeGui;
            
            tabbedPane.add('Files', this.fileNavigator.panel);
            tabbedPane.add('Code', this.codeNavigator.panel);
            tabbedPane.add('Classes', this.classesNavigator.panel);
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
            
            myFrame.getContentPane.add(tabbedPane, BorderLayout.CENTER);
            
            hFrame = handle(myFrame, 'CallbackProperties');
            hFrame.ComponentMovedCallback = @framePositionCallback;
            hFrame.ComponentResizedCallback = @framePositionCallback;
            
            this.frame = myFrame;
            if this.syncToEditor
                this.setUpEditorTracking();
            end
        end
        
        function set.Visible(this, newValue)
            this.frame.setVisible(newValue);
        end
        
        function out = get.Visible(this)
            out = this.frame.isVisible;
        end
        
        function dispose(this)
            this.fileNavigator.dispose;
            this.classesNavigator.dispose;
            this.tearDownEditorTracking;
            this.frame.dispose;
            this.frame = [];
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
            tracker = javaObjectEDT('net.apjanke.mprojectnavigator.swing.EditorFileTracker');
            tracker.setFrontFileChangedMatlabCallback('mprojectnavigator.internal.editorFileChangedCallback');
            tracker.setFileSavedMatlabCallback('mprojectnavigator.internal.editorFileSavedCallback');
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

function framePositionCallback(frame, evd) %#ok<INUSD>
loc = frame.getLocation;
siz = frame.getSize;
framePosn = [loc.x loc.y siz.width siz.height];
setpref(PREFGROUP, 'nav_Position', framePosn);
end

function tabbedPaneStateCallback(tabbedPane, evd) %#ok<INUSD>
tabIndex = tabbedPane.getSelectedIndex;
setpref(PREFGROUP, 'nav_TabSelection', tabIndex);
end

