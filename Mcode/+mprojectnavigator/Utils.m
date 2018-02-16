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
				cmd = sprintf('%s %s "%s"', 'open', '-R', file);
				browserName = 'Finder';
			elseif ispc
				cmd = sprintf('explorer.exe /n /root,"%s", /select,"%s"', ...
					file, file);
				browserName = 'Windows Explorer';
			else
				target = ifthen(isReallyDir(file), file, fileparts(file));
				cmd = sprintf('xdg-open "%s"', target);
				browserName = 'File Manager';
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