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

import subprocess
import socket
import logging
import os
import sys
import time

from PIL import Image

from htest.utils import retries, format_command, format_command_pipe
from htest.vm.controller import VMController

class MsimVMController(VMController):
    """
    MSIM VM controller.
    """

    def __init__(self, arch, name, config, boot_image, disk_image):
        VMController.__init__(self, 'xterm-' + arch)
        self.arch = arch
        self.booted = False
        self.name = name
        self.config = config if config is not None else 'msim.conf'
        self.boot_image = boot_image
        self.disk_image = disk_image
        self.x11_display = None

    def is_supported(arch):
        return arch in 'mips32/msim'

    def _get_xserver_command(self, display_no):
        if self.is_headless:
            return [
                'Xvfb',
                display_no,
                '-screen', '0', '600x400x8'
            ]
        else:
            return [
                'Xephyr',
                display_no,
                '-screen', '600x400',
            ]

    def _get_tried_x11_display_numbers(self, max_num):
        for i in range(max_num):
            yield ':{}'.format(i)

    def _start_xserver(self):
        for x11_display in self._get_tried_x11_display_numbers(100):
            command = self._get_xserver_command(x11_display)
            # FIXME: there should be a better way to ensure
            # we have started a new X11 server
            proc = subprocess.Popen(command)
            time.sleep(5)
            if proc.poll() is None:
                # Looks that we have hit the right display number :-)
                self.xserver = proc
                self.x11_display = x11_display
                return
            proc.kill()
            proc.wait()
        raise Exception("Failed to start X server (no free display number?)")

    def _list_matches(self, actual, expected):
        size = len(actual)
        if size != len(expected):
            return False
        for i in range(size):
            if expected[i] is not None:
                if actual[i] != expected[i]:
                    return False
        return True

    def _rewrite_configuration(self):
        out_lines = []
        with open(self.config, 'r') as inp:
            bootmem = None
            disk = None
            for line in inp.readlines():
                tok = line.split()

                if self._list_matches(tok, ['add', 'rom', None, '0x1fc00000']):
                    bootmem = tok[2]
                if (bootmem is not None) and self._list_matches(tok, [bootmem, 'load', None]):
                    tok[2] = '"{}"'.format(self.boot_image)
                if self._list_matches(tok, ['add', 'ddisk', None, '0x10000200', None]):
                    disk = tok[2]
                if (disk is not None) and self._list_matches(tok, [disk, 'fmap', None]):
                    if self.disk_image is None:
                        tok = []
                    else:
                        tok[2] = '"{}"'.format(self.disk_image)
                out_lines.append(' '.join(tok))
        return out_lines

    def boot(self, **kwargs):
        self.screenshot_filename = self.get_temp('screenshot.png')
        self.screendump_file = self.get_temp('xterm.screendump')
        config_file = self.get_temp('rewr.msim.conf')
        with open(config_file, 'w') as f:
            config_lines = self._rewrite_configuration()
            for l in config_lines:
                print(l, file=f)

        self._start_xserver()

        self.booted = True

        xterm_env = os.environ.copy()
        xterm_env['DISPLAY'] = self.x11_display
        self.xterm = subprocess.Popen([
            'xterm',
            '-xrm', 'XTerm*printAttributes: 0',
            '-xrm', 'XTerm*printerCommand: cat - > "{}"'.format(self.screendump_file),
            '-xrm', 'XTerm.VT100.translations: #override Meta <KeyPress> S: print() \n',
            '-e',
            'msim -c ' + config_file
        ], env=xterm_env)

        time.sleep(2)

        if self.xterm.poll() is not None:
            raise Exception("Failed to start MSIM")

        self.logger.info("Machine started.")

        uspace_booted = False
        for xxx in retries(timeout=10*60, interval=5, name="vterm", message="Failed to boot into userspace"):
            self.vterm = []
            self.full_vterm = []
            self.capture_vterm()
            for l in self.vterm:
                if l.find('to see a few survival tips') != -1:
                    uspace_booted = True
                    break
            if uspace_booted:
                break

        assert uspace_booted
        self.full_vterm = self.vterm

        self.logger.info("Machine booted into userspace.")

        return

    def _xdotool_key(self, key):
        my_env = os.environ.copy()
        my_env['DISPLAY'] = self.x11_display

        self.logger.debug("xdotool key {}".format(key))

        screenshooter = subprocess.Popen([
            'xdotool',
            'key',
            key
        ], env=my_env)
        screenshooter.wait()

    def get_vterm_cursor_symbol(self):
        return ''

    def capture_vterm_impl(self):
        try:
            os.remove(self.screendump_file)
        except IOError as e:
            pass
        try:
            os.remove(self.screenshot_filename)
        except IOError as e:
            pass
        self._xdotool_key('alt+s')
        screenshooter = subprocess.Popen([
            'import',
            '-display', self.x11_display,
            '-window', 'root',
            self.screenshot_filename
        ])
        screenshooter.wait()

        for xxx in retries(timeout=5, interval=1, name="xterm-dump", message="Failed to read XTerm screendump"):
            try:
                with open(self.screendump_file, 'r') as f:
                    lines = [ l.strip('\n') for l in f.readlines() ]
                    if len(lines) != 24:
                        continue
                    self.logger.debug("Captured text:")
                    for l in lines:
                        self.logger.debug("| " + l)
                    return lines
            except IOError as e:
                pass

    def terminate(self):
        if not self.booted:
            return
        if self.xterm is not None:
            self.xterm.kill()
            self.xterm.wait()

        self.xserver.kill()
        self.xserver.wait()

        VMController.terminate(self)

    def type(self, what):

        translations = {
            '.': 'period',
            '-': 'minus',
            '*': 'asterisk',
            '/': 'slash',
            '\\': 'backslash',
            '_': 'underscore',
            ' ': 'space',
            '\n': 'Return',
        }
        for letter in what:
            if letter.isupper():
                letter = 'shift+' + letter.lower()
            if letter in translations:
                letter = translations[letter]
            self._xdotool_key(letter)
        pass
