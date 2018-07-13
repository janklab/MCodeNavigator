Developing MCodeNavigator
============================

## Setup

If you want to hack on MCodeNavigator, generally all you need is a compatible version of Matlab.

To build the MCodeNavigator distribution, you'll need `make`. That comes preinstalled on macOS.

### Java Setup

If you want to hack on MCodeNavigator's custom Java components, you'll need:

* A Mac
* Matlab R2016b
* JetBrains IntelliJ

This is because the Java project is set up to reference Matlab R2016b as it's installed on macOS, to get access to its Java internals.

Once you build `MCodeNavigator.jar` from IntelliJ, run `installProjectJars` from `dev-tools/Mcode` in Matlab to install it into `lib/java` where Matlab can see it. The JAR should be checked in to the repo at that location (so the tool can be run directly from the distribution without having to do the Java build step).

## Goals

* M-lint-clean (warning-free) code
 * It's not feasible to be M-lint-clean on all Matlab versions simultaneously, since the warning set changes over time. Right now I'm targeting R2017b to be clean on.
