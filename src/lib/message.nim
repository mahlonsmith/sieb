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
    std/re,
    std/streams,
    std/strformat,
    std/strutils,
    std/tables,
    std/times

import
    config,
    util


#############################################################
# C O N S T A N T S
#############################################################

const
    OWNERDIRPERMS  = { fpUserExec, fpUserWrite, fpUserRead }
    OWNERFILEPERMS = { fpUserWrite, fpUserRead }
    FILTERPROCOPTS = { poUsePath }
    # FILTERPROCOPTS = { poUsePath, poEvalCommand }
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
    headers*: Table[ string, seq[string] ]
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
        "Creating new maildir at $#".debug( path )
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

    try:
        "Opening new message at:\n  $#".debug( result.path )
        result.stream = openFileStream( result.path, fmWrite )
        result.path.setFilePermissions( OWNERFILEPERMS )
    except CatchableError as err:
        deferral "Unable to write file {result.path} {err.msg}".fmt


proc open*( msg: Message ) =
    ## Open (or re-open) a Message file stream for reading.
    msg.stream = msg.path.openFileStream


proc save*( msg: Message, dir=msg.dir ) =
    ## Move the message from tmp to new.  Defaults to its current
    ## maildir, but can be provided a different one.
    msg.stream.close
    let newpath = joinPath( dir.new, msg.basename )
    msg.path.moveFile( newpath )
    "Delivered message to:\n  $#".debug( newpath )
    msg.dir = dir
    msg.path = newpath


proc delete*( msg: Message ) =
    ## Remove a message from disk.
    msg.stream.close
    msg.path.removeFile
    "Removed message at:\n  $#".debug( msg.path )
    msg.path = ""


proc writeStdin*( msg: Message ): Message =
    ## Streams stdin to the message file, returning the Message
    ## object for chaining.
    let input = stdin.newFileStream
    var total = 0
    result    = msg

    while not input.atEnd:
        let buf = input.readStr( BUFSIZE )
        total = total + buf.len
        msg.stream.write( buf )
    msg.stream.flush
    msg.stream.close
    "Wrote $# bytes".debug( total )


proc filter*( orig_msg: Message, cmd: seq[string] ): Message =
    ## Filter message content through an external program,
    ## returning a new Message if successful.
    result = orig_msg
    try:
        var buf: string

        let process = cmd[0].startProcess(
            args    = cmd[1..(cmd.len-1)],
            options = FILTERPROCOPTS
        )

        "Running filter: $#".debug( cmd )
        # let process = cmd.startProcess( options = FILTERPROCOPTS )

        # Read from the original message, write to the filter 
        # process in chunks.
        #
        orig_msg.open
        while not orig_msg.stream.atEnd:
            buf = orig_msg.stream.readStr( BUFSIZE )
            process.inputStream.write( buf )
            process.inputStream.flush

        # Read from the filter process until EOF, send to the
        # new message in chunks.
        #
        process.inputStream.close
        let new_msg = newMessage( orig_msg.dir )
        while not process.outputStream.atEnd:
            buf = process.outputStream.readStr( BUFSIZE )
            new_msg.stream.write( buf )
            new_msg.stream.flush

        let exitcode = process.waitForExit
        "Filter exited: $#".debug( exitcode )
        process.close
        if exitcode == 0:
            new_msg.stream.close
            orig_msg.delete
            result = new_msg
        else:
            "Unable to filter message: non-zero exit code".debug

    except OSError as err:
        "Unable to filter message: $#".debug( err.msg )



proc parseHeaders*( msg: Message ) =
    ## Walk the RFC2822 headers, placing them into memory.
    ## This 'unwraps' multiline headers, and allows for duplicate headers.
    let preparsed = not msg.headers.isNil
    msg.headers = initTable[ string, seq[string] ]()
    msg.open

    var
        line   = ""
        header = ""
        value  = ""

    while msg.stream.readLine( line ):
        if line == "": # Stop when headers are done.
            if header != "":
                if msg.headers.hasKey( header ):
                    msg.headers[ header ].add( value )
                else:
                    msg.headers[ header ] = @[ value ]
            break

        # Fold continuation line
        #
        if line.startsWith( ' ' ) or line.startsWith( '\t' ):
            line = line.replace( re"^\s+" )
            value = value & ' ' & line

        # Header start
        #
        else:
            var matches: array[ 2, string ]
            if line.match( re"^([\w\-]+):\s*(.*)", matches ):
                if header != "":
                    if msg.headers.hasKey( header ):
                        msg.headers[ header ].add( value )
                    else:
                        msg.headers[ header ] = @[ value ]
                ( header, value ) = ( matches[0].toLower, matches[1] )

    "Parsed message headers.".debug
    if msg.headers.hasKey( "message-id" ):
        "Message-ID is \"$#\"".debug( msg.headers[ "message-id" ] )


proc evalRules*( msg: var Message, rules: seq[Rule], default: Maildir ): bool =
    ## Evaluate each rule against the Message, returning true
    ## if there was a valid match found.
    result = false
    msg.parseHeaders

    for rule in rules:
        var match = false

        if rule.headers.len > 0: "Evaluating rule...".debug
        block thisRule:
            for header, regexp in rule.headers:
                let header_chk = header.toLower
                var
                    hmatch = false
                    headerlbl = header_chk
                    recipients: seq[ string ]
                    values: seq[ string ]

                # TO checks both To: and Cc: simultaneously.
                #
                if header == "TO":
                    headerlbl = "to|cc"
                    recipients = msg.headers.getOrDefault( "to", @[] ) &
                        msg.headers.getOrDefault( "cc", @[] )

                " checking header \"$#\"".debug( headerlbl )
                if recipients.len > 0:
                    values = recipients
                elif msg.headers.hasKey( header_chk ):
                    values = msg.headers[ header_chk ]
                else:
                    "    nonexistent header, skipping others".debug
                    break thisRule

                for val in values:
                    try:
                        hmatch = val.match( regexp.re({reStudy,reIgnoreCase}) )
                        if hmatch:
                            "    match on \"$#\"".debug( regexp )
                            break # a single multi-header is sufficient
                    except RegexError as err:
                        let errmsg = err.msg.replace( "\n", " " )
                        "    invalid regexp \"$#\" ($#), skipping".debug( regexp, errmsg ) 
                        break thisRule

                # Did any of the (possibly) multi-header values match?
                if hmatch:
                    match = true
                else:
                    "    no match for \"$#\", skipping others".debug( regexp )
                    break thisRule

            result = match


        if result:
            "Rule match!".debug
            for filter in rule.filter: msg = msg.filter( filter )

            var deliver: Maildir
            if rule.deliver != "":
                deliver = default.subDir( rule.deliver )
            else:
                deliver = default

            msg.save( deliver )
   
