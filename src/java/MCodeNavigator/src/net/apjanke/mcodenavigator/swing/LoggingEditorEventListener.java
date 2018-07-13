package net.apjanke.mcodenavigator.swing;

import com.mathworks.matlab.api.editor.Editor;
import com.mathworks.matlab.api.editor.EditorEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class LoggingEditorEventListener implements com.mathworks.matlab.api.editor.EditorEventListener {
    private static final Logger log = LoggerFactory.getLogger(LoggingEditorEventListener.class);

    private final Editor editor;

    public LoggingEditorEventListener(Editor editor) {
        this.editor = editor;
    }

    @Override
    public void eventOccurred(EditorEvent editorEvent) {
        log.info("EditorEvent occurred: source editor={}, event={}\n"
                +"  shortName={}, longName={}, storageLocation={}",
                editor, editorEvent,
                editor.getShortName(), editor.getLongName(), editor.getStorageLocation());
    }

}
