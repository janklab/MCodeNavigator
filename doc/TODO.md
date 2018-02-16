TODO
=============

* Delete files from file navigator
* Detect global functions that are not inside a package
* Multiple pinned roots in file navigator
* Transparent icons/greyed text for Hidden items
 * Requires a custom variant of the Silk icon set
* Open files in external programs from file navigator
* Persist preferences/state across Matlab restarts
 * View options like flat package view and Show Hidden
 * Window position
* "New..." action in file navigator

# To Maybe Do

* Multi-column tree view using JIDE's widgets
 * Licensing situation is unclear here
* Smart refreshing upon file changes
* Better error reporting for the `FevalAction`. Right now errors are silently swallowed.
* Move all the implementation classes to an `+internal` package, to make it clear they're private?

# TO NOT DO

* Packaging as a Matlab Toolbox
* Adding things to Matlab path/javaclasspath from navigator
 * The "Copy Path" mechanism is sufficient to handle this, and I don't want to encourage people to change their paths from the GUI (i.e. like Matlab's graphical path editor, which alters the Matlab installation itself).
