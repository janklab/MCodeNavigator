classdef Utils
    methods (Static)
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
            if ismac
                [status,msg] = system(sprintf('%s %s "%s"', 'open', '-R', file));
                if status ~= 0
                    if numel(msg) > 256
                        msg = [msg(1:256) '...'];
                    end
                    uiwait(errordlg({'Could not open file in Finder.' msg}, 'Error'));
                end
            elseif ispc
				cmd = sprintf('explorer.exe /n /root,"%s", /select,"%s"', ...
					file, file);
                [~,msg] = system(cmd);
                if ~isempty(msg)
                    if numel(msg) > 256
                        msg = [msg(1:256) '...'];
                    end
                    uiwait(errordlg({'Could not open file in Windows Explorer.' msg}, 'Error'));
                end
            else
                %TODO: I don't know how to do this on Linux
                uiwait(errordlg({
                    'Revealing files in file browser is not implemented on Linux (yet).'
                    'I''m sorry for the inconvenience.'
                    }, 'Error: Not Supported'));
            end
        end
	end
	
	methods (Access=private)
		function this = Utils()
		% Private constructor to suppress helptext
		end
	end
end