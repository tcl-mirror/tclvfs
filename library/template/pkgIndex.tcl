# Tcl package index file, version 1.1
# This file is generated by the "pkg_mkIndex -lazy" command
# and sourced either when an application starts up or
# by a "package unknown" script.  It invokes the
# "package ifneeded" command to set up package-related
# information so that packages will be loaded automatically
# in response to "package require" commands.  When this
# script is sourced, the variable $dir must contain the
# full path name of this file's directory.

package ifneeded vfs::template 1.5.1 [list source [file join $dir templatevfs.tcl]]

set ::auto_index(::vfs::template::mount) [list package require vfs::template 1.5.1]
set ::auto_index(::vfs::template::collate::mount) [list source [file join $dir collatevfs.tcl]]
set ::auto_index(::vfs::template::quota::mount) [list source [file join $dir quotavfs.tcl]]
set ::auto_index(::vfs::template::version::mount) [list source [file join $dir versionvfs.tcl]]
set ::auto_index(::vfs::template::version::delta::mount) [list source [file join $dir deltavfs.tcl]]
set ::auto_index(::vfs::template::chroot::mount) [list source [file join $dir chrootvfs.tcl]]
set ::auto_index(::vfs::template::fish::mount) [list source [file join $dir fishvfs.tcl]]

package ifneeded fileutil::globfind 1.5 [list source [file join $dir globfind.tcl]]
package ifneeded trsync 1.0 [list source [file join $dir tdelta.tcl]]

