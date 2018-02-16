function instrumentEditorsWithLogging

%desktop = com.mathworks.mde.desk.MLDesktop.getInstance;
editorApp = com.mathworks.mde.editor.MatlabEditorApplication.getInstance();
editorAppListener = net.apjanke.mprojectnavigator.swing.LoggingEditorApplicationListener;
editorAppListener.instrumentNewlyOpenedEditors = true;
editorApp.addEditorApplicationListener(editorAppListener);

editorList = editorApp.getOpenEditors;
for i = 1:editorList.size()
    editor = editorList.get(i-1);
    editor.addEventListener(...
        net.apjanke.mprojectnavigator.swing.LoggingEditorEventListener(editor));
end

%fprintf('Editors instrumented with logging listeners\n');