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

class VMManager:
    """
    Keeps track of running virtual machines.
    """

    def __init__(self, controller, architecture, boot_image):
        self.controller_class = controller
        self.architecture = architecture
        self.boot_image = boot_image
        self.instances = {}
        self.last = None

    def create(self, name):
        if name in self.instances:
            raise Exception("Duplicate machine name {}.".format(name))
        self.instances[name] = self.controller_class(self.architecture, name, self.boot_image)
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

    def terminate(self):
        for i in self.instances:
            self.instances[i].terminate()


class VMController:
    """
    Base class for controllers of specific virtual machine emulators.
    """

    def __init__(self, provider):
        self.provider_name = provider
        # Patched by VMManager
        self.name = 'XXX'
        pass

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

    def capture_vterm(self):
        """
        Get contents of current terminal window.
        """
        return self.capture_vterm_impl()

    def capture_vterm_impl(self):
        """
        Do not call but reimplement in subclass.
        """
        return []

    def get_temp(self, id):
        """
        Get temporary file name.
        """
        os.makedirs('tmp-vm-python', exist_ok=True)
        return 'tmp-vm-python/tmp-' + self.name + '-' + id

