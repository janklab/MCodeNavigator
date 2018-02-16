package net.apjanke.mprojectnavigator.swing;

import com.mathworks.matlab.api.editor.Editor;
import com.mathworks.matlab.api.editor.EditorApplicationListener;

public class LoggingEditorApplicationListener implements EditorApplicationListener {

    public boolean instrumentNewlyOpenedEditors = true;

    @Override
    public void editorOpened(Editor editor) {
        System.out.format("Editor opened: %s\n", editor);
        if (instrumentNewlyOpenedEditors) {
            editor.addEventListener(new LoggingEditorEventListener(editor));
        }
    }

    @Override
    public void editorClosed(Editor editor) {
        System.out.format("Editor closed: %s\n", editor);
    }
}
