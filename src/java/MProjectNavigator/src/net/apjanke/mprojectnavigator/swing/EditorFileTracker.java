package net.apjanke.mprojectnavigator.swing;

import com.mathworks.matlab.api.editor.*;
import com.mathworks.mde.desk.MLDesktop;
import com.mathworks.mde.editor.MatlabEditorApplication;
import com.mathworks.jmi.Matlab;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static java.util.Objects.requireNonNull;

/**
 * Tracks which file is frontmost in the Matlab editor, and notifies a Matlab clients upon changes.
 */
public class EditorFileTracker implements EditorApplicationListener {

    private static final Logger log = LoggerFactory.getLogger(EditorFileTracker.class);

    private EditorApplication editorApplication;
    private Map<Editor,EditorListener> editors = new HashMap<>();
    private String lastFrontFile = "";

    private String fevalFunction;

    public void attachToMatlab() {
        editorApplication = MatlabEditorApplication.getInstance();
        editorApplication.addEditorApplicationListener(this);
        List<Editor> allEditors = editorApplication.getOpenEditors();
        for (Editor editor : allEditors) {
            listenToEditor(editor);
        }
    }

    public void detachFromMatlab() {
        editorApplication.removeEditorApplicationListener(this);
        for (Editor editor : editors.keySet()) {
            EditorListener listener = editors.get(editor);
            listener.dispose();
            //editors.remove(editor);
        }
        editors = new HashMap<>();
        editorApplication = null;
    }

    public void setMatlabCallback(String functionName) {
        requireNonNull(functionName);
        this.fevalFunction = functionName;
    }

    @Override
    public void editorOpened(Editor editor) {
        listenToEditor(editor);
    }

    private void listenToEditor(Editor editor) {
        EditorListener listener = new EditorListener(editor);
        editors.put(editor, listener);
    }

    @Override
    public void editorClosed(Editor editor) {
        EditorListener listener = editors.get(editor);
        listener.dispose();
        editors.remove(editor);
    }

    public void newFrontFile(String path) {
        if (path.equals(lastFrontFile)) {
            // No change; no need to raise event
            return;
        }
        if (path.startsWith("untitled")) {
            //System.out.println("Ignoring untitled file brought to front.");
            return;
        }
        fireFrontFileChanged(path);
    }

    public void fireFrontFileChanged(String path) {
        if (fevalFunction != null) {
            Matlab ml = new Matlab();
            Object[] fevalArgs = new Object[1];
            fevalArgs[0] = path;
            ml.fevalConsoleOutput(fevalFunction, fevalArgs);
        }
    }

    public class EditorListener implements EditorEventListener {
        private Editor editor;

        public EditorListener(Editor editor) {
            this.editor = editor;
            editor.addEventListener(this);
        }

        public void dispose() {
            if (editor != null) {
                editor.removeEventListener(this);
            }
            editor = null;
        }

        @Override
        public void eventOccurred(EditorEvent editorEvent) {
            log.debug("Editor {}: {}", editorEvent.name(), editor);
            switch (editorEvent.name()) {
                case "ACTIVATED":
                    String path = editor.getLongName();
                    newFrontFile(path);
                    break;
                case "CLOSED":
                    log.debug("Editor CLOSED: {}", editor);
                    dispose();
                    break;
                case "AUTOSAVE_OPTIONS_CHANGED":
                    // ignore
                    break;
                case "DIRTY_STATE_CHANGED":
                    // ignore
                    break;
                case "DEBUG_MODE_CHANGED":
                    // ignore
                    break;
                case "AUTOSAVED":
                    // ignore
                    break;
                default:
                    log.warn("Unrecognized editor event: {}: {}", editorEvent.name(), editor);
            }
        }
    }

}
