#!/bin/sh

#
# Copyright (c) 2017 Vojtech Horky
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

CI_HOME=`which -- "$0" 2>/dev/null`
# Maybe, we are running Bash
[ -z "$CI_HOME" ] && CI_HOME=`which -- "$BASH_SOURCE" 2>/dev/null`
CI_HOME=`dirname -- "$CI_HOME"`




list_build_numbers() {
    (
        cd "$1"
        find -maxdepth 1 -mindepth 1 -type d -name 'build-*'
    ) \
    | cut '-d-' -f 2 \
    | sort -nr
}






#
# Defaults
#

CI_WEB_ROOT="$PWD/web-ci"
CI_HISTORY_LENGTH=10
CI_BUILD_DIR="$PWD/tmp-ci"
CI_EXTRA_OPTS=""

# Load user configuration
if [ -e "ci.rc" ]; then
    . ./ci.rc
fi


#
# Start the build
#

mkdir -p "$CI_BUILD_DIR"
( cd "$CI_BUILD_DIR"; rm -rf * )


# Ensure we are the only ones running
LOCK_DIR="$CI_BUILD_DIR/lock-dir"

if ! mkdir "$LOCK_DIR"; then
    echo "Error: another build in progress, aborting." >&2
    echo "Note: if no other build process is running, try removing $LOCK_DIR." >&2
    exit 2
fi


# Run the rest of the script in subshell (shall ensure that we remove the
# lock directory upon termination).
(


mkdir -p "$CI_WEB_ROOT"

# Get build number
BUILD_NUMBER=`list_build_numbers "$CI_WEB_ROOT" | head -n 1`
if [ -z "$BUILD_NUMBER" ]; then
    BUILD_NUMBER=1
else
    BUILD_NUMBER=$(( $BUILD_NUMBER + 1 ))
fi

# Our directory with HTML report
WEB_DIR="$CI_WEB_ROOT/build-$BUILD_NUMBER"
WEB_DIR_HIDDEN="$CI_WEB_ROOT/.build-$BUILD_NUMBER"

$CI_HOME/build.py \
    "--build-id=$BUILD_NUMBER" \
    "--build-directory=$CI_BUILD_DIR" \
    "--artefact-directory=$WEB_DIR_HIDDEN" \
    "--rss-url=../rss.xml" \
    "--resource-path=../" \
    $CI_EXTRA_OPTS

if ! [ -e "$WEB_DIR_HIDDEN/report.xml" ]; then
    echo "$WEB_DIR_HIDDEN/report.xml not found, aborting!" >&2
    exit 1
fi

# Switch the new pages
mv "$WEB_DIR_HIDDEN" "$WEB_DIR"

# Ensure stylesheet and scripts are available
for i in main.css jquery-2.1.4.min.js; do
    cp -n "$CI_HOME/hbuild/web/$i" "$CI_WEB_ROOT/$i"
done

# New-enough builds
KEPT_BUILDS=`list_build_numbers "$CI_WEB_ROOT" | head -n $CI_HISTORY_LENGTH | grep -v "^$BUILD_NUMBER\$" | paste '-sd '`

# Recreate the index page
xsltproc \
    --stringparam LAST_BUILD $BUILD_NUMBER \
    --stringparam PREVIOUS_BUILDS "$KEPT_BUILDS" \
    "$CI_HOME/hbuild/web/index.xsl" "$WEB_DIR/report.xml" \
    >"$CI_WEB_ROOT/index.html"

# Recreate RSS
xsltproc \
    --stringparam WEB_ROOT_ABSOLUTE_FILE_PATH "$CI_WEB_ROOT" \
    --stringparam PREVIOUS_BUILDS "$KEPT_BUILDS" \
    "$CI_HOME/hbuild/web/rss.xsl" "$WEB_DIR/report.xml" \
    >"$CI_WEB_ROOT/rss.xml"

# Remove older builds
for i in `list_build_numbers "$CI_WEB_ROOT" | tail -n +$(( $CI_HISTORY_LENGTH + 1 ))`; do
    rm -rf "$CI_WEB_ROOT/build-$i"
done

# Keep latest/ pointing to the latest build
(
    cd "$CI_WEB_ROOT"
    ln -sTf "build-$BUILD_NUMBER" latest
)


)

rmdir "$LOCK_DIR"
