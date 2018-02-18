classdef Utils
    methods (Static)
        function out = osFileBrowserName()
            if ismac
                out = 'Finder';
            elseif ispc
                out = 'Windows Explorer';
            else
                out = 'File Manager';
            end
        end
        
        function out = isSupportedTerminalInstalled()
            persistent answer
            if ~isempty(answer)
                out = answer;
                return;
            end
            if ispc
                % We can always fall back to Command Prompt
                answer = true;
            elseif ismac
                % I can only get automation working for iTerm, not for Terminal.app
                answer = exist('/Applications/iTerm.app', 'file');
            else
                % On Linux, of course there's a usable terminal, but I haven't
                % gotten around to coding it up yet.
                answer = false;
            end
            out = answer;
        end
        
        function out = isPowerShellInstalled()
            persistent answer
            if ~isempty(answer)
                out = answer;
                return;
            end
            answer = exist('C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe', 'file');
            out = answer;
        end
        
        function guiRevealFileInDesktopFileBrowser(file)
            % Reveals the given file in the OS desktop file browser
            %
            % guiRevealFileInDesktopFileBrowser(file)
            %
            % Reveals the given file in Finder, Windows Explorer, or a Linux
            % file browser, as appropriate for the current system.
            %
            % Linux support is currently unimplemented.
            %
            % File (char) is the path to the file.
            browserName = mprojectnavigator.internal.Utils.osFileBrowserName;
            if ismac
                cmd = sprintf('%s %s "%s"', 'open', '-R', file);
            elseif ispc
                cmd = sprintf('explorer.exe /n /root,"%s", /select,"%s"', ...
                    file, file);
            else
                target = ifthen(isFolder(file), file, fileparts(file));
                cmd = sprintf('xdg-open "%s"', target);
            end
            [status,msg] = system(cmd);
            isOk = ifthen(ispc, isempty(msg), status == 0);
            if ~isOk
                if numel(msg) > 256
                    msg = [msg(1:256) '...'];
                end
                uiwait(errordlg({sprintf('Could not open file in %s.', browserName) msg}, 'Error'));
            end
        end
        
        function openTerminalSessionAtDir(dir)
            if ismac
                % Assume that if user bothered to install iTerm, they'd prefer
                % using it over Terminal.app.
                useIterm = exist('/Applications/iTerm.app', 'file');
                resourceDir = [fileparts(mfilename('fullpath')) '/resources'];
                if useIterm
                    launcher = [resourceDir '/open_iterm_to_dir.applescript'];
                else
                    launcher = [resourceDir '/open_terminal_to_dir.applescript'];
                end
                cmd = sprintf('osascript "%s" "%s"', launcher, dir);
                [~,~] = system(cmd);
            elseif ispc
                % Prefer cygwin, since this is a tool for developers and if they have
                % it installed, they probably want to use it
                cygBin = 'C:\cygwin64\bin';
                cygwinIsInstalled = exist([cygBin '\mintty.exe'], 'file');
                if cygwinIsInstalled
                    [~,cygPath] = system(sprintf('%s\\cygpath.exe --unix "%s"', cygBin, dir));
                    cygPath = regexprep(cygPath, '[\r\n]', '');
                    % This is a hack that can only run bash. Really it should run the
                    % user's default login shell.
                    cmd = sprintf('start %s\\mintty.exe %s\\bash.exe -l -c "cd ''%s''; exec bash"', ...
                        cygBin, cygBin, cygPath);
                    [~,~] = system(cmd);
                else
                    % Fall back to Command Prompt
                    launchWindowsCommandPromptAt(dir);
                end
            else
                % Linux: try a couple popular terminals
                if isUnixCommandOnPath('gnome-terminal')
                    cmd = sprintf('gnome-terminal --working-directory=''%s''', dir);
                elseif isUnixCommandOnPath('lxterminal')
                    cmd = sprintf('lxterminal --working-directory=''%s''', dir);
                elseif isUnixCommandOnPath('urxvt')
                    cmd = sprintf('urxvt -c ''%s''', dir);
                else
                    % They've gotta at least have xterm
                    cmd = sprintf('bash -c "cd ''%s''; xterm &"', dir);
                end
                [status,msg] = system(cmd);
                if status ~= 0
                    error('Failed to launch terminal: %s', msg);
                end
            end
        end
        
        function openPowerShellAtDir(dir)
            cmd = sprintf('start powershell.exe -noexit -command "cd ''%s''"', dir);
            system(cmd);
        end
    end
    
    methods (Access=private)
        function this = Utils()
            % Private constructor to suppress helptext
        end
    end
end

function launchWindowsCommandPromptAt(dir)
cmd = sprintf('start cmd /K "cd /d %s"', dir);
[~,~] = system(cmd);
end

function out = isUnixCommandOnPath(cmd)
[status,~] = system('which ''%s''', cmd);
out = status == 0;
end