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

class ScrollingTerminal:
    """
    Keeps track of text scrolling away in the terminal.
    """

    def __init__(self, capture_callback, cursor_symbol):
        self._capture_impl = capture_callback
        self._cursor_symbol = cursor_symbol
        self._last_screen = None

    def capture(self):
        """
        Captures the current content of the terminal window.
        """

        return [
            line.rstrip()
            for line in self._capture_impl()
        ]

    def get_lines_watching(self):
        """
        Returns lines that newly appeared in the terminal window.
        """
        yield ""

    def get_lines_once(self):
        """
        Captures the content of terminal and returns lines that
        appeared newly since last call.
        """

        # Always capture the screen first
        lines_now = self._clear_empty_tail(self.capture())

        # FIXME: we should distinguish (almost) empty screen at
        # the beginning and commands that prints multiple new lines
        if len(lines_now) == 0:
            return []

        # Check if this is the first capture ever
        if self._last_screen is None:
            self._last_screen = lines_now
            return self._last_screen.copy()

        # Find overlapping lines if possible
        # We first try to compare the whole screen with previous state
        # and if there is no match, we compare head of new screen with
        # tail of last screen.
        # That is, we remove last line of the new screen and check whether
        # all these lines are the same as the last lines of the previous
        # screen (i.e. without the first line). If not, we remove 2 lines
        # from the new one and remove top 2 lines from the old one.
        # And so on until match is found or we find that there is no overlap.
        lines_now_count = len(lines_now)
        lines_old_count = len(self._last_screen)
        same_lines_len = 0
        for same_lines_it in range(lines_now_count, 0, -1):
            if same_lines_it > lines_old_count:
                continue
            lines_old_subset = self._last_screen[-same_lines_it:]
            lines_now_subset = lines_now[0:same_lines_it]
            ( same_lines, has_cursor ) = self._same_lines(lines_old_subset, lines_now_subset)
            if same_lines:
                if has_cursor:
                    same_lines_len = same_lines_it - 1
                else:
                    same_lines_len = same_lines_it
                break

        self._last_screen = lines_now

        # FIXME: what to do when we missed some lines
        # (i.e. same_lines_len is 0)?
        return lines_now[same_lines_len:]

    def _clear_empty_tail(self, lines):
        while (len(lines) > 0) and (lines[-1].strip() == ""):
            lines = lines[0:-1]
        return lines

    def _same_lines(self, prev, curr):
        prev_len = len(prev)
        assert prev_len == len(curr)
        for i in range(prev_len - 1):
            if prev[i] != curr[i]:
                return ( False, False )
        if prev[prev_len - 1].endswith(self._cursor_symbol):
            prev_last = prev[prev_len - 1][0:-len(self._cursor_symbol)]
            return ( curr[prev_len - 1].startswith(prev_last), True )
        else:
            return ( prev[prev_len - 1] == curr[prev_len - 1], False )

