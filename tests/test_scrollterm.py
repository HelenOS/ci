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

from nose.tools import eq_
from htest.scrollterm import ScrollingTerminal

class TermCaptureGallery:
    def __init__(self, captures):
        self.captures = [ x.split('\n') for x in captures ]

    def capture(self):
        if len(self.captures) == 0:
            raise StopIteration("Run out of captures.")
        return self.captures.pop(0)

def make_terminal(captures):
    gallery = TermCaptureGallery(captures)
    return ScrollingTerminal(gallery.capture, "_")



def test_capture():
    term = make_terminal([
        "a\nb\nc\nd",
        "b\nc\nd\ne",
    ])
    eq_(term.capture(), [ "a", "b", "c", "d" ])
    eq_(term.capture(), [ "b", "c", "d", "e" ])


def check_intr_same_lines(expected, prev, curr):
    term = make_terminal([])
    msg = "_same_lines({}, {}) == {}".format(prev, curr, expected)
    assert term._same_lines(prev, curr) == expected, msg

def test_intr_same_lines():
    test_cases = [
        ( ( True, False ), ["a", "b"], ["a", "b"] ),
        ( ( False, False ), ["a", "b"], ["a", "bb"] ),
        ( ( True, True), ["a", "b_"], ["a", "bb"] ),
        ( ( True, True), ["a", "bb_"], ["a", "bb"] ),
        ( ( True, True), ["a", "bb_"], ["a", "bbbbb"] ),
    ]
    for expected, prev, curr in test_cases:
        yield check_intr_same_lines, expected, prev, curr


def test_get_lines_once_simple():
    term = make_terminal([
        "a\nb\nc\nd",
        "a\nb\nc\nd",
        "b\nc\nd\ne",
        "d\ne\nf\ng",
    ])
    eq_(term.get_lines_once(), [ "a", "b", "c", "d" ])
    eq_(term.get_lines_once(), [])
    eq_(term.get_lines_once(), [ "e" ])
    eq_(term.get_lines_once(), [ "f", "g" ])

def test_get_lines_once_slow_line():
    term = make_terminal([
        "a\nb_\n\n",
        "a\nbbb\n\n",
        "a\nbbb\nc\n",
    ])
    eq_(term.get_lines_once(), [ "a", "b_" ])
    eq_(term.get_lines_once(), [ "bbb" ])
    eq_(term.get_lines_once(), [ "c" ])

