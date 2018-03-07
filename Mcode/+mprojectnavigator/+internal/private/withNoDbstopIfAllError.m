function out = withNoDbstopIfAllError
%WITHNODBSTOPIFALLERROR Dynamically-scoped suppression of "dbstop if all error"
%
% To use it:
%
% RAII.dbstop = withNoDbstopIfAllError
%
% When the RAII variable is cleared, this will trigger cleanup that restores the
% original debugger state.
origDebuggerState = dbstatus('-completenames');
out = onCleanup(@() dbstop(origDebuggerState));
dbclear if all error
