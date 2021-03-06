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

import os
import subprocess
import logging

class VMManager:
    """
    Keeps track of running virtual machines.
    """

    def __init__(self, controller, architecture, vm_config, boot_image, disk_image, memory_amount, headless, extra_opts):
        self.controller_class = controller
        self.architecture = architecture
        self.vm_config = vm_config
        self.boot_image = boot_image
        self.disk_image = disk_image
        self.memory_amount = memory_amount
        self.headless = headless
        self.extra_options = extra_opts
        self.instances = {}
        self.last = None

    def create(self, name):
        if name in self.instances:
            raise Exception("Duplicate machine name {}.".format(name))
        self.instances[name] = self.controller_class(self.architecture, name, self.vm_config, self.boot_image, self.disk_image)
        self.instances[name].memory = self.memory_amount
        self.instances[name].is_headless = self.headless
        self.instances[name].extra_options = self.extra_options
        self.last = name
        return self.instances[name]

    def get(self, name=None):
        if name is None:
            name = self.last
        if name is None:
            return None
        if name in self.instances:
            self.last = name
            return self.instances[name]
        else:
            return None

    def terminate(self, vterm_dump_filename, last_screenshot_filename):
        for i in self.instances:
            self.instances[i].terminate()
        if vterm_dump_filename is not None:
            with open(vterm_dump_filename, 'w') as f:
                for i in self.instances:
                    lines = '\n'.join(self.instances[i].full_vterm)
                    print(lines, file=f)
        if last_screenshot_filename is not None:
            for i in self.instances:
                filename = self.instances[i].screenshot_filename
                if filename is not None:
                    proc = subprocess.Popen(['convert', filename, last_screenshot_filename])
                    proc.wait()
                    if proc.returncode != 0:
                        raise Exception("Saving screenshot failed.")

class VMController:
    """
    Base class for controllers of specific virtual machine emulators.
    """

    def __init__(self, provider):
        self.provider_name = provider
        self.logger = logging.getLogger(provider)
        # Patched by VMManager
        self.name = 'XXX'
        self.screenshot_filename = None
        # All lines seen in the terminal
        # (do not reset unless you know what you are doing).
        self.full_vterm = []
        # Used to keep track of new-lines
        self.vterm = []
        # Amount of memory (MB) (patched by VMM manager)
        self.memory = 0
        # Extra command-line options (patched by VMM manager)
        self.extra_options = []
        # Are we headless (patched by VMM manager)
        self.is_headless = False
        pass

    def is_supported(self, arch):
        """
        Tells whether this controller supports given architecture.
        """
        return False

    def boot(self, **kwargs):
        """
        Bring the machine up.
        """
        pass

    def terminate(self):
        """
        Shutdown the VM.
        """
        pass

    def type(self, what):
        """
        Type given text into vterm.
        """
        print("type('{}') @ {}".format(what, self.provider_name))
        pass

    def same_vterm_tail(self, lines):
        lines_count = len(lines)
        for i in range(-1, -lines_count - 1, -1):
            try:
                if i != -1:
                    if lines[i] != self.full_vterm[i]:
                        return False
                else:
                    a = lines[-1].replace("_", " ").strip()
                    b = self.full_vterm[-1].replace("_", " ").strip()
                    if not a.startswith(b):
                        return False
            except IndexError as e:
                # FIXME: should not happen but maybe we need to
                # be more defensive here about what can appear
                # in self.full_vterm...
                raise Exception("INTERNAL ERROR: same_vterm_tail(i={}, lines={}, full_vterm={})".format(i, lines, self.full_vterm))
        return True

    def capture_vterm(self):
        """
        Capture contents of current terminal window and updates self.vterm
        """

        # Read everything from the terminal and get rid of completely empty
        # lines (for first commands when the screen is empty).
        lines = self.capture_vterm_impl()
        lines = [l.strip() for l in lines]
        self.logger.debug("Captured lines: {}".format(lines))
        while (len(lines) > 0) and (lines[-1].strip() == ""):
            lines = lines[0:-1]
        if (len(lines) == 0):
            return

        # When this is the very first screen, we simply copy it.
        if len(self.full_vterm) == 0:
            for l in lines:
                self.full_vterm.append(l)
                self.vterm.append(l)
        else:
            # Otherwise, we find whether there is some overlap, i.e. whether
            # we are capturing a rolling screen.
            lines_count = len(lines)
            same_lines = 0
            for i in range(lines_count, 0, -1):
                if self.same_vterm_tail(lines[0:i]):
                    same_lines = i
                    break
            # If there is no overlap, we might have missed some lines.
            if same_lines == 0:
                self.full_vterm.append("!!!!!! WARNING: probably missed some lines here !!!!!")
            else:
                # Otherwise, update the last line (last capture might have
                # missed some characters).
                if len(self.full_vterm) > 0:
                    self.full_vterm = self.full_vterm[0:-1]
                if len(self.vterm) > 0:
                    self.vterm = self.vterm[0:-1]
                same_lines = same_lines - 1
            # Add the new lines.
            for i in range(same_lines, lines_count):
                self.full_vterm.append(lines[i])
                self.vterm.append(lines[i])

    def capture_vterm_impl(self):
        """
        Do not call but reimplement in subclass.
        """
        return []

    def get_vterm_cursor_symbol(self):
        """
        Reimplement if your controller represents cursor in vterm
        differently than with underscore symbol '_'.
        """
        return '_'

    def get_temp(self, id):
        """
        Get temporary file name.
        """
        os.makedirs('tmp-vm-python', exist_ok=True)
        return 'tmp-vm-python/tmp-' + self.name + '-' + id

