
package require vfs 1.0
package require http
# part of tcllib
package require base64

# This works for very basic operations (cd, open, file stat, but not 'glob').
# It has been put together, so far, largely by trial and error!

namespace eval vfs::webdav {}

proc vfs::webdav::Mount {dirurl local} {
    ::vfs::log "http-vfs: attempt to mount $dirurl at $local"
    if {[string index $dirurl end] != "/"} {
	append dirurl "/"
    }
    if {[string range $dirurl 0 6] == "http://"} {
	set rest [string range $dirurl 7 end]
    } else {
	set rest $dirurl
	set dirurl "http://${dirurl}"
    }
    
    if {![regexp {(([^:]*)(:([^@]*))?@)?([^/]*)(/(.*/)?([^/]*))?$} $rest \
      junk junk user junk pass host junk path file]} {
	return -code error "Sorry I didn't understand\
	  the url address \"$dirurl\""
    }
    
    if {[string length $file]} {
	return -code error "Can only mount directories, not\
	  files (perhaps you need a trailing '/' - I understood\
	  a path '$path' and file '$file')"
    }
    
    if {![string length $user]} {
	set user anonymous
    }
    
    set dirurl "http://$host/$path"
    
    set extraHeadersList "Authorization {Basic [base64::encode ${user}:${pass}]}"

    set token [::http::geturl $dirurl -headers $extraHeadersList -validate 1]
    http::cleanup $token
    
    if {![catch {vfs::filesystem info $dirurl}]} {
	# unmount old mount
	::vfs::log "ftp-vfs: unmounted old mount point at $dirurl"
	vfs::unmount $dirurl
    }
    ::vfs::log "http $host, $path mounted at $local"
    vfs::filesystem mount $local [list vfs::webdav::handler $dirurl $extraHeadersList $path]
    # Register command to unmount
    vfs::RegisterMount $local [list ::vfs::webdav::Unmount $dirurl]
    return $dirurl
}

proc vfs::webdav::Unmount {dirurl local} {
    vfs::filesystem unmount $local
}

proc vfs::webdav::handler {dirurl extraHeadersList path cmd root relative actualpath args} {
    if {$cmd == "matchindirectory"} {
	eval [list $cmd $dirurl $extraHeadersList $relative $actualpath] $args
    } else {
	eval [list $cmd $dirurl $extraHeadersList $relative] $args
    }
}

# If we implement the commands below, we will have a perfect
# virtual file system for remote http sites.

proc vfs::webdav::stat {dirurl extraHeadersList name} {
    ::vfs::log "stat $name"
    
    # get information on the type of this file.  
    if {$name == ""} {
	set mtime 0
	lappend res type directory
	lappend res dev -1 uid -1 gid -1 nlink 1 depth 0 \
	  atime $mtime ctime $mtime mtime $mtime mode 0777
	return $res
    }
    
    # This is a bit of a hack.  We really want to do a 'PROPFIND'
    # request with depth 0, I believe.  I don't think Tcl's http
    # package supports that.
    set token [::http::geturl $dirurl$name -headers $extraHeadersList]
    upvar #0 $token state

    if {![regexp " (OK|Moved Permanently)$" $state(http)]} {
	::vfs::log "No good: $state(http)"
	::http::cleanup $token
	error "Not found"
    }
    
    if {[regexp "Moved Permanently$" $state(http)]} {
	regexp {<A HREF="([^"]+)">here</A>} $state(body) -> here
	if {[string index $here end] == "/"} {
	    set type directory
	}
    }
    if {![info exists type]} {
	set type file
    }
    
    #parray state
    set mtime 0

    lappend res type $type
    lappend res dev -1 uid -1 gid -1 nlink 1 depth 0 \
      atime $mtime ctime $mtime mtime $mtime mode 0777 \
      size $state(totalsize)

    ::http::cleanup $token
    return $res
}

proc vfs::webdav::access {dirurl extraHeadersList name mode} {
    ::vfs::log "access $name $mode"
    if {$name == ""} { return 1 }
    set token [::http::geturl $dirurl$name -headers $extraHeadersList]
    upvar #0 $token state
    if {![regexp " (OK|Moved Permanently)$" $state(http)]} {
	::vfs::log "No good: $state(http)"
	::http::cleanup $token
	error "Not found"
    } else {
	::http::cleanup $token
	return 1
    }
}

# We've chosen to implement these channels by using a memchan.
# The alternative would be to use temporary files.
proc vfs::webdav::open {dirurl extraHeadersList name mode permissions} {
    ::vfs::log "open $name $mode $permissions"
    # return a list of two elements:
    # 1. first element is the Tcl channel name which has been opened
    # 2. second element (optional) is a command to evaluate when
    #    the channel is closed.
    switch -glob -- $mode {
	"" -
	"r" {
	    set token [::http::geturl $dirurl$name -headers $extraHeadersList]
	    upvar #0 $token state

	    set filed [vfs::memchan]
	    
	    fconfigure $filed -encoding $state(charset)
	    
	    puts -nonewline $filed [::http::data $token]

	    fconfigure $filed -translation auto
	    seek $filed 0
	    ::http::cleanup $token
	    return [list $filed]
	}
	"a" -
	"w*" {
	    error "Can't open $name for writing"
	}
	default {
	    return -code error "illegal access mode \"$mode\""
	}
    }
}

proc vfs::webdav::matchindirectory {dirurl extraHeadersList path actualpath pattern type} {
    ::vfs::log "matchindirectory $path $pattern $type"
    set res [list]

    puts stderr "The 'PROPFIND' method not implemented.  Please help!"
    
    if {[string length $pattern]} {
	# need to match all files in a given remote http site.
	
    } else {
	# single file
	if {![catch {access $dirurl $path}]} {
	    lappend res $path
	}
    }
    
    return $res
}

proc vfs::webdav::createdirectory {dirurl extraHeadersList name} {
    ::vfs::log "createdirectory $name"
    error "read-only"
}

proc vfs::webdav::removedirectory {dirurl extraHeadersList name} {
    ::vfs::log "removedirectory $name"
    error "read-only"
}

proc vfs::webdav::deletefile {dirurl extraHeadersList name} {
    ::vfs::log "deletefile $name"
    error "read-only"
}

proc vfs::webdav::fileattributes {dirurl extraHeadersList path args} {
    ::vfs::log "fileattributes $args"
    switch -- [llength $args] {
	0 {
	    # list strings
	    return [list]
	}
	1 {
	    # get value
	    set index [lindex $args 0]
	}
	2 {
	    # set value
	    set index [lindex $args 0]
	    set val [lindex $args 1]
	    error "read-only"
	}
    }
}

proc vfs::webdav::utime {dirurl extraHeadersList path actime mtime} {
    error "Can't set utime"
}
