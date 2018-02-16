function MProjectNavigator(varargin)
%MProjectNavigator Viewer GUI tool for a Matlab project structure
%
% MProjectNavigator(varargin)
%
% Usage:
%
% MProjectNavigator
% MProjectNavigator -pin <path>
% MProjectNavigator -deletesettings
%
% For this to work, its JAR dependencies must be on the Java classpath. You can
% set this up by running loadMProjectNavigator(), found in this project's
% "bootstrap/" directory.
%
% Alternately, you can invoke MProjectNavigator with its hotkey, Ctrl-Shift-P.

error(javachk('awt'));

persistent pFrame pFileNavigator

if nargin == 0
    maybeInitializeGui();
    pFrame.setVisible(true);
else
    if isequal(varargin{1}, '-pin')
        if nargin < 2
            warning('MProjectNavigator: Invalid arguments: -pin requires an argument');
            return;
        end
        newPinnedPath = varargin{2};
        maybeInitializeGui();
        pFileNavigator.setRootPath(newPinnedPath);
    elseif isequal(varargin{1}, '-hide')
        if isempty(pFrame)
            return;
        end
        pFrame.setVisible(false);
    elseif isequal(varargin{1}, '-fresh')
        disposeGui();
        maybeInitializeGui();
        pFrame.setVisible(true);
    elseif isequal(varargin{1}, '-registerhotkey')
        registerHotkey();
    elseif isequal(varargin{1}, '-hotkeyinvoked')
        hotkeyInvoked();
    elseif isequal(varargin{1}, '-deletesettings')
        mprojectnavigator.internal.Persistence.deleteAllSettings();
        fprintf('MProjectNavigator: All settings deleted.\n');
    elseif isequal(varargin{1}, '-editorfrontfile')
        editorFrontFile(varargin{2});
    elseif isequal(varargin{1}(1), '-')
        warning('MProjectNavigator: Unrecognized option: %s', varargin{1});
    else
        warning('MProjectNavigator: Invalid arguments');
    end
end

    function disposeGui()
        if ~isempty(pFrame)
            pFrame.dispose();
            pFrame = [];
            pFileNavigator = [];
        end
    end

    function maybeInitializeGui()
        if isempty(pFrame)
            initializeGui();
        end
    end

    function initializeGui()
        import java.awt.*
        import javax.swing.*
        
        framePosn = getpref('MProjectNavigator', 'nav_Position', []);
        if isempty(framePosn)
            framePosn = [NaN NaN 350 600];
        end
        frame = JFrame('Project Navigator');
        frame.setSize(framePosn(3), framePosn(4));
        if ~isnan(framePosn(1))
            frame.setLocation(framePosn(1), framePosn(2));
        end
        
        tabbedPane = JTabbedPane;
        
        fileNavigator = mprojectnavigator.internal.FileNavigatorWidget;
        tabbedPane.add('Files', fileNavigator.panel);
        codeNavigator = mprojectnavigator.internal.CodeNavigatorWidget;
        tabbedPane.add('Definitions', codeNavigator.panel);
        
        frame.getContentPane.add(tabbedPane, BorderLayout.CENTER);
        registerHotkeyOnComponent(frame.getContentPane);
        frame.setVisible(true);
        
        hFrame = handle(frame, 'CallbackProperties');
        hFrame.ComponentMovedCallback = @framePositionCallback;
        hFrame.ComponentResizedCallback = @framepositionCallback;

        pFrame = frame;
        pFileNavigator = fileNavigator;
    end

    function framePositionCallback(frame, evd)
        loc = frame.getLocation;
        siz = frame.getSize;
        framePosn = [loc.x loc.y siz.width siz.height];
        setpref('MProjectNavigator', 'nav_Position', framePosn);
    end

    function registerHotkey()
        mainFrame = com.mathworks.mde.desk.MLDesktop.getInstance.getMainFrame;
        registerHotkeyOnComponent(mainFrame.getContentPane);
    end

    function hotkeyInvoked()
        if isempty(pFrame)
            initializeGui();
        else
            % Toggle visibility
            pFrame.setVisible(~pFrame.isVisible);
        end
    end

    function editorFrontFile(file)
        if isempty(pFrame)
            return;
        end
        pFileNavigator.syncToFile(file);
    end

end

function registerHotkeyOnComponent(jComponent)
import net.apjanke.mprojectnavigator.swing.*
import java.awt.*
import javax.swing.*

action = FevalAction.ofStringArguments('MProjectNavigator','-hotkeyinvoked');
%action.setDisplayConsoleOutput(true); % DEBUG
inputMap = jComponent.getInputMap(JComponent.WHEN_IN_FOCUSED_WINDOW);
actionMap = jComponent.getActionMap;
controlShiftP = KeyStroke.getKeyStroke('control shift P');
actionName = java.lang.String('MProjectNavigator-hotkey');
inputMap.put(controlShiftP, actionName);
actionMap.put(actionName, action);
end
