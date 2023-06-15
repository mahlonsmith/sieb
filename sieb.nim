# vim: set et nosta sw=4 ts=4 :
#
# Copyright (c) 2023, Mahlon E. Smith <mahlon@martini.nu>
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#
#     * Neither the name of Mahlon E. Smith nor the names of his
#       contributors may be used to endorse or promote products derived
#       from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE REGENTS AND CONTRIBUTORS BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


import
    std/streams,
    yaml/serialization

const
    VERSION = "v0.1.0"

type
    rule = object
        headers: seq[ tuple[ header: string, regexp: string ] ]
        deliver {.defaultVal: "Maildir"}: string
        filter {.defaultVal: ""}: string

    # Typed configuration file layout for YAML loading.
    Config = object
        logfile {.defaultVal: "".}: string
        pre_filter {.defaultVal: @[]}: seq[string]
        post_filter {.defaultVal: @[]}: seq[string]
        rules {.defaultVal: @[]}: seq[rule]


var conf: Config

let s = newFileStream( "config.yml" )
load( s, conf )
s.close

echo conf
