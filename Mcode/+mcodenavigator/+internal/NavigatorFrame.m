classdef NavigatorFrame < handle
    %NAVIGATORFRAME A Navigator displayed in a JFrame
    
    properties
        frame
        navigator
    end
    properties (Dependent)
        Visible
    end
    
    methods
        function this = NavigatorFrame(navigator)
            if nargin < 1;  navigator = [];  end
            if isempty(navigator)
                navigator = mcodenavigator.internal.Navigator;
            end
            this.navigator = navigator;
            this.initializeGui();
        end
        
        function initializeGui(this)
            import java.awt.*
            import javax.swing.*
            
            framePosn = getpref(PREFGROUP, 'nav_Position', []);
            if isempty(framePosn)
                framePosn = [NaN NaN 350 600];
            end
            myFrame = javaObjectEDT('javax.swing.JFrame', 'Code Navigator');
            myFrame.setSize(framePosn(3), framePosn(4));
            if ~isnan(framePosn(1))
                myFrame.setLocation(framePosn(1), framePosn(2));
            end
            % Use the Matlab or custom icon to blend in with the rest of the
            % application.
            mainFrame = com.mathworks.mde.desk.MLDesktop.getInstance.getMainFrame;
            myFrame.setIconImages(mainFrame.getIconImages);
            
            myFrame.getContentPane.add(this.navigator.panel, BorderLayout.CENTER);
            
            hFrame = handle(myFrame, 'CallbackProperties');
            hFrame.ComponentMovedCallback = @framePositionCallback;
            hFrame.ComponentResizedCallback = @framePositionCallback;
            
            this.frame = myFrame;
        end
        
        function set.Visible(this, newValue)
            this.frame.setVisible(newValue);
        end
        
        function out = get.Visible(this)
            out = this.frame.isVisible;
        end
        
        function dispose(this)
            this.navigator.dispose;
            this.frame.dispose;
            this.frame = [];
        end
    end
end

function framePositionCallback(frame, evd) %#ok<INUSD>
loc = frame.getLocation;
siz = frame.getSize;
framePosn = [loc.x loc.y siz.width siz.height];
setpref(PREFGROUP, 'nav_Position', framePosn);
end

