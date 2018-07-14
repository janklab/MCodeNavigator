function MCodeNavClient(varargin)
%MCODENAVCLIENT Viewer GUI tool for a Matlab code base in a Desktop client
%
% This is an experimental version of MCodeNavigator that displays the navigator
% in a dockable Matlab Desktop Client, instead of a standalone Java frame.
%
% Usage:
%
% MCodeNavClient
% MCodeNavClient -dispose
%
% For this to work, MCodeNavigator must be loaded and initialized. You can
% do this up by running loadMCodeNavigator(), found in this project's
% "bootstrap/" directory.
%
% Alternately, instead of calling the MCodeNavClient() function, you can invoke 
% MCodeNavClient with its hotkey, Ctrl-Shift-N.

error(javachk('awt'));

    function [out,out2] = myNavigator(newNavigator, newDtClient)
    s = getappdata(0, 'MCodeNavigator');
    if isempty(s)
        s = struct;
        s.NavigatorInstance = [];
        s.NavigatorDtClient = [];
    end
    out = s.NavigatorInstance;
    out2 = s.NavigatorDtClient;
    if nargin > 0
        s.NavigatorInstance = newNavigator;
        s.NavigatorDtClient = newDtClient;
        setappdata(0, 'MCodeNavigator', s);
    end
    end

[navigator,navigatorDtClient] = myNavigator;

if nargin == 0
    varargin = { '-initialize' };
end

switch varargin{1}
    case '-initialize'
        maybeInitializeGui();
    otherwise
        if isequal(varargin{1}(1), '-')
            warning('MCodeNavClient: Unrecognized option: %s', varargin{1});
        else
            warning('MCodeNavClient: Invalid arguments');
        end
end

    function maybeInitializeGui()
    if isempty(navigator)
        navigator = mcodenavigator.internal.Navigator;
        navigatorDtClient = %TODO;
        myNavigator(navigator, navigatorDtClient);
    end
    end

end