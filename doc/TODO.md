TODO
=============

* BUG: Scroll-to-node is not working in classes view when there are a lot of nodes in the tree, such as when you have the MATLAB globals expanded.
* BUG: Might have a memory leak. I sometimes get an out of Java heap space OOM error when hacking on this for a while. Or things will get real slow after doing multiple `methodsview2` calls.
* BUG: `*.bak` and other files with odd extensions might confuse the class view.
* Add context menu to methodsview2 with Edit and View Doc options
* Column resize weights/autosize in `methodsview2`
* Better sample classes, with human-understandable types, and various property/method attributes
* File Navigator file actions
 * "New..." with various options
 * Delete
 * Open file in external program...
 * These should be supported in Code view, too, as appropriate
* Transparent icons/greyed text for Hidden items
 * Requires a custom variant of the Silk icon set
* Matlab file icon for ".m" files
 * Probably requires a custom variant of the Silk icon set, too
 * Requires displaying icons per file type/extension logic
* Switch to using what() for class/function metadata discovery

# To Maybe Do

* On-node "loading" indicator, so you can see when things are auto-loading without being expanded yet
* "About" box
* Better error reporting for the `FevalAction`. Right now errors are silently swallowed.
* Multi-column tree view using JIDE's widgets
 * Licensing situation is unclear here
* Auto-detect new versions and notify user
* Text search/filtering on the class/file navigators?
* Persist the tree expansion state across Matlab restarts
* External file change detection (once I'm on Java 8)

# TO NOT DO

* Packaging as a Matlab Toolbox
* Adding things to Matlab path/javaclasspath from navigator
 * The "Copy Path" mechanism is sufficient to handle this, and I don't want to encourage people to change their paths from the GUI (i.e. like Matlab's graphical path editor, which alters the Matlab installation itself).
