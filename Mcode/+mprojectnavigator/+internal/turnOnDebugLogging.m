function turnOnDebugLogging(onOrOff)

if nargin < 1 || isempty(onOrOff);  onOrOff = true;  end

if onOrOff
    newLevel = 'DEBUG';
else
    newLevel = 'INFO';
end

mprojectnavigator.internal.Log4jConfigurator.setLevels({
    'mprojectnavigator'                 newLevel
    'net.apjanke.mprojectnavigator'     newLevel
    });