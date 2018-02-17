TODO
=============

* Multiple pinned roots in file navigator
 * Or new "code roots" navigator
* "New..." action in file navigator
* Delete files from file navigator
* Open files in external programs from file navigator
* Transparent icons/greyed text for Hidden items
 * Requires a custom variant of the Silk icon set
* An inheritance hierarchy browser for classes
* Packages with only package children should not show up in the code navigator flat view

# To Maybe Do

* "About" box
* Smart refreshing upon file changes
* Better error reporting for the `FevalAction`. Right now errors are silently swallowed.
* Multi-column tree view using JIDE's widgets
 * Licensing situation is unclear here
* Auto-detect new versions and notify user
* Text search/filtering on the class/file navigators?

# TO NOT DO

* Packaging as a Matlab Toolbox
* Adding things to Matlab path/javaclasspath from navigator
 * The "Copy Path" mechanism is sufficient to handle this, and I don't want to encourage people to change their paths from the GUI (i.e. like Matlab's graphical path editor, which alters the Matlab installation itself).
