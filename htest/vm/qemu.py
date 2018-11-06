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

from PIL import Image

from htest.utils import retries, format_command, format_command_pipe
from htest.vm.controller import VMController

class QemuVMController(VMController):
    """
    QEMU VM controller.
    """

    config = {
        'amd64': [
            'qemu-system-x86_64',
            '-cdrom', '{BOOT}',
            '-m', '{MEMORY}',
            '-usb',
            '-device', 'intel-hda', '-device', 'hda-duplex',
        ],
        'arm32/integratorcp': [
            'qemu-system-arm',
            '-M', 'integratorcp',
            '-usb',
            '-kernel', '{BOOT}',
            '-m', '{MEMORY}',
        ],
        'ia32': [
            'qemu-system-i386',
            '-cdrom', '{BOOT}',
            '-m', '{MEMORY}',
            '-usb',
            '-device', 'intel-hda', '-device', 'hda-duplex',
        ],
        'ppc32': [
            'qemu-system-ppc',
            '-usb',
            '-boot', 'd',
            '-cdrom', '{BOOT}',
            '-m', '{MEMORY}',
        ],
    }

    ocr_sed = os.path.join(
        os.path.dirname(os.path.realpath(sys.argv[0])),
        'ocr.sed'
    )

    def __init__(self, arch, name, boot_image):
        VMController.__init__(self, 'QEMU-' + arch)
        self.arch = arch
        self.booted = False
        self.name = name
        self.boot_image = boot_image

    def is_supported(arch):
        return arch in QemuVMController.config

    def _get_image_dimensions(self, filename):
        im = Image.open(filename)
        width, height = im.size
        im.close()
        return ( width, height )

    def _check_is_up(self):
        if not self.booted:
            raise Exception("Machine not launched")

    def _send_command(self, command):
        self._check_is_up()
        self.logger.debug("Sending command '{}'".format(command))
        command = command + '\n'
        self.monitor.sendall(command.encode('utf-8'))

    def _run_command(self, command):
        proc = subprocess.Popen(command)
        proc.wait()
        if proc.returncode != 0:
            raise Exception("Command {} failed.".format(command))

    def _run_pipe(self, commands):
        self.logger.debug("Running pipe {}".format(format_command_pipe(commands)))
        procs = []
        for command in commands:
            inp = None
            if len(procs) > 0:
                inp = procs[-1].stdout
            proc = subprocess.Popen(command, stdout=subprocess.PIPE, stdin=inp)
            procs.append(proc)
        procs[-1].communicate()


    def boot(self, **kwargs):
        self.monitor_file = self.get_temp('monitor')
        cmd = []
        for opt in QemuVMController.config[self.arch]:
            if opt == '{BOOT}':
                opt = self.boot_image
            elif opt == '{MEMORY}':
                opt = '{}'.format(self.memory)
            cmd.append(opt)
        if self.is_headless:
            cmd.append('-display')
            cmd.append('none')
        cmd.append('-monitor')
        cmd.append('unix:{},server,nowait'.format(self.monitor_file))
        for opt in self.extra_options:
            cmd.append(opt)
        self.logger.debug("Starting QEMU: {}".format(format_command(cmd)))

        self.proc = subprocess.Popen(cmd)
        self.monitor = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        for xxx in retries(timeout=30, interval=2, name="ctl-socket", message="Failed to connect to QEMU control socket."):
            try:
                self.monitor.connect(self.monitor_file)
                break
            except FileNotFoundError:
                pass
            except ConnectionRefusedError:
                pass
            if self.proc.poll():
                raise Exception("QEMU not started, aborting.")

        self.booted = True
        self.logger.info("Machine started.")

        # Skip past GRUB
        self.type('\n')

        uspace_booted = False
        for xxx in retries(timeout=3*60, interval=5, name="vterm", message="Failed to boot into userspace"):
            self.vterm = []
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

    def capture_vterm_impl(self):
        screenshot_full = self.get_temp('screen-full.ppm')
        screenshot_term = self.get_temp('screen-term.png')
        screenshot_text = self.get_temp('screen-term.txt')

        self._send_command('screendump ' + screenshot_full)

        for xxx in retries(timeout=5, interval=1, name="scrdump", message="Failed to capture screen"):
            try:
                self._run_command([
                    'convert',
                    screenshot_full,
                    '-crop', '640x480+4+24',
                    '+repage',
                    '-colors', '2',
                    '-monochrome',
                    screenshot_term
                ])
                break
            except:
                pass

        width, height = self._get_image_dimensions(screenshot_term)
        cols = width // 8
        rows = height // 16
        self._run_pipe([
            [
                'convert',
                screenshot_term,
                '-crop', '{}x{}'.format(cols * 8, rows * 16),
                '+repage',
                '-crop', '8x16',
                '+repage',
                '+adjoin',
                'txt:-',
            ],
            [
                'sed',
                '-e', 's|[0-9]*,[0-9]*: ([^)]*)[ ]*#\\([0-9A-Fa-f]\\{6\\}\\).*|\\1|',
                '-e', 's:^#.*:@:',
                '-e', 's#000000#0#g',
                '-e', 's#FFFFFF#F#',
            ],
            [ 'tee', self.get_temp('1.txt') ],
            [
                'sed',
                '-e', ':a',
                '-e', 'N;s#\\n##;s#^@##;/@$/{s#@$##p;d}',
                '-e', 't a',
            ],
            [ 'tee', self.get_temp('2.txt') ],
            [
                'sed',
                '-f', QemuVMController.ocr_sed,
            ],
            [
                'sed',
                '/../s#.*#?#',
            ],
            [ 'tee', self.get_temp('3.txt') ],
            [
                'paste',
                '-sd', '',
            ],
            [
                'fold',
                '-w', '{}'.format(cols),
            ],
            [ 'tee', self.get_temp('4.txt') ],
            [
                'head',
                '-n', '{}'.format(rows),
            ],
            [
                'tee',
                screenshot_text,
            ]
        ])

        self.screenshot_filename = screenshot_full

        with open(screenshot_text, 'r') as f:
            lines = [ l.strip('\n') for l in f.readlines() ]
            self.logger.debug("Captured text:")
            for l in lines:
                self.logger.debug("| " + l)
            return lines

    def terminate(self):
        if not self.booted:
            return
        self._send_command('quit')
        VMController.terminate(self)

    def type(self, what):
        translations = {
            ' ': 'spc',
            '.': 'dot',
            '-': 'minus',
            '/': 'slash',
            '\n': 'ret',
            '_': 'shift-minus',
            '|': 'shift-backslash',
            '=': 'equal',
        }
        for letter in what:
            if letter.isupper():
                letter = 'shift-' + letter.lower()
            if letter in translations:
                letter = translations[letter]
            self._send_command('sendkey ' + letter)
        pass
