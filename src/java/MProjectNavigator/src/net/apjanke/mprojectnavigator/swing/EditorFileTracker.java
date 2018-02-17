package net.apjanke.mprojectnavigator.swing;

import com.mathworks.matlab.api.editor.*;
import com.mathworks.mde.desk.MLDesktop;
import com.mathworks.mde.editor.MatlabEditorApplication;
import com.mathworks.jmi.Matlab;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static java.util.Objects.requireNonNull;

/**
 * Tracks which file is frontmost in the Matlab editor, and notifies a Matlab clients upon changes.
 */
public class EditorFileTracker implements EditorApplicationListener {

    private EditorApplication editorApplication;
    private Map<Editor,EditorListener> editors = new HashMap<>();

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
        System.out.format("newFrontFile(): %s\n", path);
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
            switch (editorEvent.name()) {
                case "ACTIVATED":
                    System.out.format("ACTIVATED: %s\n", editor.getLongName());
                    String path = editor.getLongName();
                    newFrontFile(path);
                    break;
                case "CLOSED":
                    System.out.format("CLOSED: %s\n", editor.getLongName());
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
                    System.out.println("Unhandled event from editor "+editor
                    +", event="+editorEvent+", name="+editorEvent.name());
            }
        }
    }

}
