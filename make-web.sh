#!/bin/sh

#
# Copyright (c) 2016 Vojtech Horky
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# - Redistributions of source code must retain the above copyright
#   notice, this list of conditions and the following disclaimer.
# - Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the distribution.
# - The name of the author may not be used to endorse or promote products
#   derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

SCRIPT_HOME=`which -- "$0" 2>/dev/null`
# Maybe, we are running Bash
[ -z "$SCRIPT_HOME" ] && SCRIPT_HOME=`which -- "$BASH_SOURCE" 2>/dev/null`
SCRIPT_HOME=`dirname -- "$SCRIPT_HOME"`

run_echo() {
	echo -n "[make-web]: "
	for ___i in "$@"; do
		echo -n "$___i" | sed -e 's#"#\\"#g' -e 's#.*#"&" #'
	done
	echo
	"$@"
}

INPUT_XML="$1"
TARGET_DIR="$2"

if ! [ -r "$INPUT_XML" ]; then
    echo "Cannot read input XML from '$INPUT_XML'."
    exit 1
fi

if [ -z "$TARGET_DIR" ]; then
    echo "Specify output directory as second argument."
    exit 2
fi

run_echo mkdir -p "$TARGET_DIR"
if ! [ -d "$TARGET_DIR" ]; then
    echo "Cannot create directory $TARGET_DIR."
    exit 3
fi

run_echo cp "$SCRIPT_HOME/web/main.css" "$TARGET_DIR"
run_echo cp "$SCRIPT_HOME/web/jquery-2.1.4.min.js" "$TARGET_DIR"

run_echo xsltproc \
    --stringparam OUTPUT_DIRECTORY "$TARGET_DIR" \
    "$SCRIPT_HOME/web/web.xsl" \
    "$INPUT_XML"
