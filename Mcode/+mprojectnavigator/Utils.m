classdef Utils
    methods (Static)
        function guiRevealFileInDesktopFileBrowser(file)
            if ismac
                % Have to use single-argument form of system to avoid
                % "Unrecognized option: -R" error
                [status,msg] = system(sprintf('%s %s "%s"', 'open', '-R', file));
                if status ~= 0
                    if numel(msg) > 256
                        msg = [msg(1:256) '...'];
                    end
                    uiwait(errordlg({'Could not open file in Finder.' msg}, 'Error'));
                end
            elseif ispc
                parentDir = fileparts(file);
                system('explorer.exe', '/n', sprintf('/root,"%s"', parentDir), ...
                    sprintf('/select,"%s"', file));
            else
                %TODO: I don't know how to do this on Linux
                uiwait(errordlg({
                    'Revealing files in file browser is not implemented on Linux (yet).'
                    'I''m sorry for the inconvenience.'
                    }, 'Error: Not Supported'));
            end
        end
    end
end