classdef Navigator < handle
    % The whole Navigator UI, corresponding to a frame with multiple panels
    %
    % This is intended to be a singleton, with only one active at a time in a
    % Matlab session.
    
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
            this.fileNavigator.revealFile(file);
            % Find out what that file defines, and update the code navigator
            defn = this.codebase.defnForMfile(file);
            this.codeNavigator.revealDefn(defn, file);
        end

        function setUpEditorTracking(this)
            tracker = javaObjectEDT('net.apjanke.mprojectnavigator.swing.EditorFileTracker');
            tracker.setMatlabCallback('mprojectnavigator.internal.editorFileTrackerCallback');
            EDT('attachToMatlab', tracker);
            this.editorTracker = tracker;
            fprintf('setUpEditorTracking(): done\n');
        end
        
        function tearDownEditorTracking(this)
            if isempty(this.editorTracker)
                return;
            end
            EDT('detachFromMatlab', this.editorTracker);
            this.editorTracker = [];
            fprintf('tearDownEditorTracking(): done\n');
        end
        
    end
end

function framePositionCallback(frame, evd) %#ok<INUSD>
loc = frame.getLocation;
siz = frame.getSize;
framePosn = [loc.x loc.y siz.width siz.height];
setpref(PREFGROUP, 'nav_Position', framePosn);
end

