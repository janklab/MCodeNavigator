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
            browserName = mprojectnavigator.Utils.osFileBrowserName;
			if ismac
				cmd = sprintf('%s %s "%s"', 'open', '-R', file);
			elseif ispc
				cmd = sprintf('explorer.exe /n /root,"%s", /select,"%s"', ...
					file, file);
			else
				target = ifthen(isReallyDir(file), file, fileparts(file));
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
	end
	
	methods (Access=private)
		function this = Utils()
			% Private constructor to suppress helptext
		end
	end
end