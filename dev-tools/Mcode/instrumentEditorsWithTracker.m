function out = instrumentEditorsWithTracker

tracker = net.apjanke.mprojectnavigator.swing.EditorFileTracker;
tracker.setMatlabCallback('mprojectnavigator.internal.editorFileTrackerCallback');
tracker.attachToMatlab();
out = tracker;