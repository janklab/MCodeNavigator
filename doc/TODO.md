TODO
=============

* Detect global functions and classes that are not inside a package
* Multiple pinned roots in file navigator
* "New..." action in file navigator
* Refactor classes to move more common tree functionality up into TreeWidget
* Transparent icons/greyed text for Hidden items
 * Requires a custom variant of the Silk icon set
* Delete files from file navigator
* Open files in external programs from file navigator

# To Maybe Do

* Smart refreshing upon file changes
* Better error reporting for the `FevalAction`. Right now errors are silently swallowed.
* Multi-column tree view using JIDE's widgets
 * Licensing situation is unclear here
* Move all the implementation classes to an `+internal` package, to make it clear they're private?
* About screen
* Auto-detect new versions and notify user

# TO NOT DO

* Packaging as a Matlab Toolbox
* Adding things to Matlab path/javaclasspath from navigator
 * The "Copy Path" mechanism is sufficient to handle this, and I don't want to encourage people to change their paths from the GUI (i.e. like Matlab's graphical path editor, which alters the Matlab installation itself).
