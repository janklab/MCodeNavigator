TODO
=============

* I think view syncing might be broken
 * Needs to be added to Code navigator, too, anyway
* BUG: Scroll-to--node is not working in classes view when there are a lot of nodes in the tree, such as when you have the MATLAB globals expanded
* Better sample classes, with human-understandable types, and various property/method attributes
* Figure out how to get File and CodeRoots navigators to share right-click menu code.
 * CodeRoots is a file browser, really, so it should support all the same actions. And I don't want to just copy-and-paste the menu.
* Option to hide inherited properties/methods in Classes view
* Disable/Hide "Edit", "View Doc" context menu items when clicking on folders in file navigator
* File Navigator file actions
 * "New..." action in file navigator
 * Delete files from file navigator
 * Open file in external program...
 * These should all be supported in Code view, too
* Transparent icons/greyed text for Hidden items
 * Requires a custom variant of the Silk icon set
* Matlab file icon for ".m" files
 * Probably requires a custom variant of the Silk icon set, too
 * Requires displaying icons per file type/extension logic
* An inheritance hierarchy browser for classes
* Switch to using what() for class/function metadata discovery
* Get FileNavigator tree idiom back in line with TreeWidget's overridable methods and expand/refresh/refreshSingleNode idiom
* "View Doc" in file browser may need to guard against "dbstop if all error" triggering inside doc()
* Auto-detect whether a given dir has relevant doco before enabling "View Doc" on it

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
