function turnOnDebugLogging(onOrOff)

if nargin < 1 || isempty(onOrOff);  onOrOff = true;  end

if onOrOff
    newLevel = 'DEBUG';
else
    newLevel = 'INFO';
end

mcodenavigator.internal.Log4jConfigurator.setLevels({
    'mcodenavigator'                 newLevel
    'net.apjanke.mcodenavigator'     newLevel
    });