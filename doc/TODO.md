TODO
=============

* BUG: Scroll-to--node is not working in classes view when there are a lot of nodes in the tree, such as when you have the MATLAB globals expanded
* Multiple pinned roots in file navigator
 * Or new "code roots" navigator
* Smart refreshing upon file changes
* "New..." action in file navigator
* Delete files from file navigator
* Open files in external programs from file navigator
* Transparent icons/greyed text for Hidden items
 * Requires a custom variant of the Silk icon set
* An inheritance hierarchy browser for classes
* Switch to using what() for class/function metadata discovery
* Persist files/classes tab selection across restarts
* On-node "loading" indicator, so you can see when things are auto-loading without being expanded yet

# To Maybe Do

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
