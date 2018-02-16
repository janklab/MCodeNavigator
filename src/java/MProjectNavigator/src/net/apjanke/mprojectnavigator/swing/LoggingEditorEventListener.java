package net.apjanke.mprojectnavigator.swing;

import com.mathworks.matlab.api.editor.Editor;
import com.mathworks.matlab.api.editor.EditorEvent;

public class LoggingEditorEventListener implements com.mathworks.matlab.api.editor.EditorEventListener {

    private final Editor editor;

    public LoggingEditorEventListener(Editor editor) {
        this.editor = editor;
    }

    @Override
    public void eventOccurred(EditorEvent editorEvent) {
        out("EditorEvent occurred: source editor=%s, event=%s\n",
                editor, editorEvent);
        out("  shortName=%s, longName=%s, storageLocation=%s\n",
                editor.getShortName(), editor.getLongName(), editor.getStorageLocation());
    }

    private static void out(String fmt, Object... args) {
        System.out.format(fmt, args);
    }
}
