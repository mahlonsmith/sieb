# vim: set et nosta sw=4 ts=4 :
#
# A class that represents an individual Maildir, and a Nessage class to nanage
# files underneath them.
#

#############################################################
# I M P O R T S
#############################################################

import
    std/os,
    std/osproc,
    std/posix,
    std/streams,
    std/strformat,
    std/times

import
    util


#############################################################
# C O N S T A N T S
#############################################################

const
    OWNERDIRPERMS  = { fpUserExec, fpUserWrite, fpUserRead }
    OWNERFILEPERMS = { fpUserWrite, fpUserRead }
    # FILTERPROCOPTS = { poUsePath }
    FILTERPROCOPTS = { poUsePath, poEvalCommand }
    BUFSIZE        = 8192 # reading and writing buffer size


#############################################################
# T Y P E S
#############################################################

# A Maildir object.
#
type Maildir* = ref object
    path*: string # Absolute path to the encapsualting dir
    cur:  string
    new:  string
    tmp:  string

# An email message, under a specific Maildir.
#
type Message* = ref object
    basename: string
    dir:      Maildir
    headers:  seq[ tuple[ header: string, value: seq[string] ] ]
    path:     string
    stream:   FileStream


# Count messages generated during a run.
var msgcount = 0


#############################################################
# M E T H O D S
#############################################################

#------------------------------------------------------------
# Maildir
#------------------------------------------------------------

proc newMaildir*( path: string ): Maildir =
    ## Create and return a new Maildir object, making it on-disk if necessary.
    result = new Maildir
    result.path = path
    result.cur  = joinPath( path, "cur" )
    result.new  = joinPath( path, "new" )
    result.tmp  = joinPath( path, "tmp" )

    if not dirExists( path ):
        debug "Creating new maildir at {path}".fmt
        try:
            for p in [ result.path, result.cur, result.new, result.tmp ]:
                p.createDir
                p.setFilePermissions( OWNERDIRPERMS )

        except CatchableError as err:
            deferral "Unable to create Maildir: ({err.msg}), deferring delivery.".fmt


proc subDir*( dir: Maildir, path: string ): Maildir =
    ## Creates a new Maildir relative to an existing one.
    result = newMaildir( dir.path & "/" & path )


#------------------------------------------------------------
# Message
#------------------------------------------------------------

proc newMessage*( dir: Maildir ): Message =
    ## Create and return a Message - an open FileStream under a specific Maildir
    ## (in tmp)
    result = new Message

    let now = getTime()
    var hostname = newString(256)
    discard getHostname( cstring(hostname), cint(256) )

    msgcount = msgcount + 1
    result.dir = dir
    result.basename = $now.toUnixFloat & '.' & $getCurrentProcessID() & '.' & $msgcount & '.' & $hostname
    result.path = joinPath( result.dir.tmp, result.basename )
    result.headers = @[]

    try:
        debug "Opening new message at {result.path}".fmt
        result.stream = openFileStream( result.path, fmWrite )
        result.path.setFilePermissions( OWNERFILEPERMS )
    except CatchableError as err:
        deferral "Unable to write file {result.path} {err.msg}".fmt


proc open*( msg: Message ) =
    ## Open (or re-open) a Message file stream.
    msg.stream = msg.path.openFileStream


proc save*( msg: Message, dir=msg.dir ) =
    ## Move the message from tmp to new.  Defaults to its current
    ## maildir, but can be provided a different one.
    msg.stream.close
    let newpath = joinPath( dir.new, msg.basename )
    debug "Delivering message to {newpath}".fmt
    msg.path.moveFile( newpath )
    msg.dir = dir
    msg.path = newpath


proc delete*( msg: Message ) =
    ## Remove a message from disk.
    msg.stream.close
    debug "Removing message at {msg.path}".fmt
    msg.path.removeFile
    msg.path = ""


proc writeStdin*( msg: Message ) =
    ## Streams stdin to the message file, returning how
    ## many bytes were written.
    let input = stdin.newFileStream
    var buf   = input.readStr( BUFSIZE )
    var total = buf.len
    msg.stream.write( buf )

    while buf != "" and buf.len == BUFSIZE:
        buf   = input.readStr( BUFSIZE )
        total = total + buf.len
        msg.stream.write( buf )
    msg.stream.flush
    msg.stream.close
    debug "Wrote {total} bytes from stdin".fmt


proc filter*( orig_msg: Message, cmd: string ): Message =
    ## Filter message content through an external program,
    ## returning a new Message if successful.
    try:
        var buf: string

        # let command = cmd.split
        # let process = command[0].startProcess(
        #     args    = command[1..(command.len-1)],
        #     options = FILTERPROCOPTS
        # )

        let process = cmd.startProcess( options = FILTERPROCOPTS )

        # Read from the original message, write to the filter 
        # process in chunks.
        #
        orig_msg.open
        buf = orig_msg.stream.readStr( BUFSIZE )
        process.inputStream.write( buf )
        process.inputStream.flush
        while buf != "" and buf.len == BUFSIZE:
            buf = orig_msg.stream.readStr( BUFSIZE )
            process.inputStream.write( buf )
            process.inputStream.flush

        # Read from the filter process until EOF, send to the
        # new message in chunks.
        process.inputStream.close
        let new_msg = newMessage( orig_msg.dir )
        buf = process.outputStream.readStr( BUFSIZE )
        new_msg.stream.write( buf )
        new_msg.stream.flush
        while buf != "" and buf.len == BUFSIZE:
            buf = process.outputStream.readStr( BUFSIZE )
            new_msg.stream.write( buf )
            new_msg.stream.flush

        let exitcode = process.waitForExit
        debug "Filter exited: {exitcode}".fmt
        process.close
        orig_msg.delete
        result = new_msg

    except OSError as err:
        debug "Unable to filter message: {err.msg}".fmt
        result = orig_msg



# FIXME: header parsing to tuples
#  - open file
#  - skip lines that don't match headers
#  - unwrap multiline headers
#  - store header, add value to seq of strings


