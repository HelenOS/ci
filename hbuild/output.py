#!/usr/bin/env python3

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

from threading import Lock
import sys

class ConsolePrinter:
    DEFAULT = 0
    RED = 1
    GREEN = 2
    CYAN = 3
    YELLOW = 4

    def __init__(self, disable_colors):
        use_colors = not disable_colors
        if use_colors:
            try:
                import colorama
                colorama.init()
            except ImportError:
                use_colors = False

        if use_colors:
            import colorama
            self.color_reset = colorama.Style.RESET_ALL
            self.colors = {
                ConsolePrinter.DEFAULT: "",
                ConsolePrinter.RED: colorama.Fore.RED,
                ConsolePrinter.GREEN: colorama.Fore.GREEN,
                ConsolePrinter.CYAN: colorama.Fore.CYAN,
                ConsolePrinter.YELLOW: colorama.Fore.YELLOW,
            }
        else:
            self.color_reset = ""
            self.colors = {
                ConsolePrinter.DEFAULT: "",
                ConsolePrinter.RED: "",
                ConsolePrinter.GREEN: "",
                ConsolePrinter.CYAN: "",
                ConsolePrinter.YELLOW: "",
            }

        # Lock guarding output synchronization
        self.output_lock = Lock()

    def print_(self, message):
        with self.output_lock:
            print(self.color_reset + message)
            sys.stdout.flush()

    def print_starting(self, message):
        self.print_("       " + message)

    def print_finished(self, color, prefix, message):
        if not color in self.colors:
            color = ConsolePrinter.DEFAULT

        self.print_("[" + self.colors[color] + prefix + self.color_reset + "] " + message)

    def print_debug(self, context, message):
        self.print_finished(self.YELLOW, "debug " + context, message)

    def print_warning(self, message):
        self.print_finished(self.RED, "warn", message)

    def print_fail(self, message):
        self.print_finished(self.RED, "fail", message)

    def print_ok(self, message):
        self.print_finished(self.GREEN, " ok ", message)
