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
        codeNavigator
        % Whether to keep node selections in sync with Matlab's editor
        syncToEditor = getpref(PREFGROUP, 'files_syncToEditor', false);
        editorTracker;
        codebase;
    end
    properties (Dependent)
        Visible
    end
    
    methods
        function this = Navigator()
            this.fileNavigator = mprojectnavigator.internal.FileNavigatorWidget(this);
            this.codeNavigator = mprojectnavigator.internal.CodeNavigatorWidget(this);
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
            myFrame = JFrame('Project Navigator');
            myFrame.setSize(framePosn(3), framePosn(4));
            if ~isnan(framePosn(1))
                myFrame.setLocation(framePosn(1), framePosn(2));
            end
            
            tabbedPane = JTabbedPane;
            
            tabbedPane.add('Files', this.fileNavigator.panel);
            tabbedPane.add('Classes', this.codeNavigator.panel);
            
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
            EDT('setVisible', this.frame, newValue);
        end
        
        function out = get.Visible(this)
            out = this.frame.isVisible;
        end
        
        function dispose(this)
            this.fileNavigator.dispose;
            this.codeNavigator.dispose;
            this.tearDownEditorTracking;
            EDT('dispose', this.frame);
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
            logdebugf('editorFrontFileChanged: %s', [basename ext]);
            % Avoid doing expensive tree expansion for Matlab files that tend to
            % pop up in the debugger due to Matlab's self-hosting nature and
            % their internal use of try/catch
            % TODO: Allow navigation to them if they're already visible
            if ismember(file, this.NoAutoloadFiles)
                logdebugf('editorFrontFileChanged: skipping autoload of known-funny file %s', ...
                    file);
                return;
            end
            this.fileNavigator.revealFile(file);
            % Find out what that file defines, and update the code navigator
            defn = this.codebase.defnForMfile(file);
            this.codeNavigator.revealDefn(defn, file);
        end

        function setUpEditorTracking(this)
            tracker = javaObjectEDT('net.apjanke.mprojectnavigator.swing.EditorFileTracker');
            tracker.setMatlabCallback('mprojectnavigator.internal.editorFileTrackerCallback');
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

