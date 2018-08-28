#!/usr/bin/env python3

#
# Copyright (c) 2018 Vojtech Horky
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

import time
import logging
import shlex

def retries(n=None, interval=2, timeout=None, message="Operation timed-out (too many retries)", name=""):
    """
    To be used in for-loops to try action multiple times.
    Throws exception on time-out.
    """

    if (n is None) and (timeout is None):
        raise Exception("Specify either n or timeout for retries")

    if name != "":
        name = "-" + name
    logger = logging.getLogger("rtr" + name)

    if timeout is None:
        timeout = n * interval
    remaining = timeout
    n = 0
    while remaining > 0:
        logger.debug("remaining={}, n={}, interval={}, \"{}\"".format(
            remaining, n, interval, message))
        remaining = remaining - interval
        n = n + 1
        yield n
        time.sleep(interval)
    logger.debug("timed-out, n={}, \"{}\"".format(n, message))
    raise Exception(message)

def format_command(cmd):
    """
    Escape shell command given as list of arguments.
    """
    escaped = [shlex.quote(i) for i in cmd]
    return ' '.join(escaped)

def format_command_pipe(pipe):
    """
    Escape shell pipe given as list of list of arguments.
    """
    escaped = [format_command(i) for i in pipe]
    return ' | '.join(escaped)

