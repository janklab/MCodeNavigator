package net.apjanke.mprojectnavigator.swing;

import com.mathworks.matlab.api.editor.Editor;
import com.mathworks.matlab.api.editor.EditorApplicationListener;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class LoggingEditorApplicationListener implements EditorApplicationListener {
    private static final Logger log = LoggerFactory.getLogger(LoggingEditorApplicationListener.class);

    public boolean instrumentNewlyOpenedEditors = true;

    @Override
    public void editorOpened(Editor editor) {
        log.info("Editor opened: {}", editor);
        if (instrumentNewlyOpenedEditors) {
            editor.addEventListener(new LoggingEditorEventListener(editor));
        }
    }

    @Override
    public void editorClosed(Editor editor) {
        log.info("Editor closed: {}", editor);
    }
}
