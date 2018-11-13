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

import logging

from htest.utils import retries

class ScenarioTask:
    """
    Base class for individual tasks that are executed in a scenario.
    """

    def __init__(self, name):
        """
        Set @name to the task name (call from subclass).
        """

        self.name = name
        self.machine = None
        self.fail_message = ''
        self.logger = logging.getLogger(name)

    def check_required_argument(self, args, name):
        """
        To be used by subclasses to check that arguments
        were specified.
        """
        if not name in args:
            raise Exception("Required argument {} missing.".format(name))

    def is_vm_launcher(self):
        """
        Whether this task starts a new VM.
        """
        return False

    def get_name(self):
        return self.name

    def set_machine(self, machine):
        """
        Set machine responsible for executing this task.
        """
        self.machine = machine

    def run(self):
        """
        Actually execute this task.
        """
        pass

class ScenarioTaskBoot(ScenarioTask):
    """
    Brings the machine up.
    """
    def __init__(self, args):
        ScenarioTask.__init__(self, 'boot')
        self.args = args

    def is_vm_launcher(self):
        return True

    def run(self):
        self.machine.boot()

class ScenarioTaskCommand(ScenarioTask):
    """
    Run a command in vterm.
    """

    def __init__(self, args):
        ScenarioTask.__init__(self, 'command')
        if type(args) is str:
            args = { 'args': args}
        self.check_required_argument(args, 'args')
        self.command = args['args']
        self.ignore_abort = False
        if 'ignoreabort' in args:
            self.ignore_abort = args['ignoreabort']
        self.args = args

    def _grep(self, text, lines):
        for l in lines:
            if l.find(text) != -1:
                return True
        return False

    def run(self):
        self.logger.info("Typing '{}' into {}.".format(self.command, self.machine.name))

        # Capture the screen before typing the command.
        self.machine.capture_vterm()

        self.machine.type(self.command)

        # Wait until the command is fully displayed on the screen.
        # That is needed to properly detect the newly displayed lines.
        # FIXME: this will not work for long commands spanning multiple lines
        for xxx in retries(timeout=60, interval=2, name="vterm-type", message="Failed to type command"):
            self.machine.vterm = []
            self.machine.capture_vterm()
            lines = self.machine.vterm

            if len(lines) > 0:
                line = lines[0].strip()
                if line.endswith("_"):
                    line = line[0:-1]
                if line.endswith(self.command.strip()):
                    break

        self.machine.vterm = []
        self.machine.type('\n')

        # Read output of the command.
        # We wait until prompt reappears or we find some text that is not
        # supposed to be there.
        for xxx in retries(timeout=60, interval=2, name="vterm-run", message="Failed to run command"):
            self.logger.debug("self.vterm = {}".format(self.machine.vterm))
            self.machine.capture_vterm()
            lines = self.machine.vterm
            self.logger.debug("Read lines {}".format(lines))
            self.machine.vterm = []
            if not self.ignore_abort:
                if self._grep('Cannot spawn', lines) or self._grep('Command failed', lines):
                    raise Exception('Failed to run command')
            if 'negassert' in self.args:
                if self._grep(self.args['negassert'], lines):
                    raise Exception('Found forbidden text {} ...'.format(self.args['negassert']))
            if self._grep('# _', lines):
                if 'assert' in self.args:
                    if not self._grep(self.args['assert'], lines):
                        raise Exception('Missing expected text {} ...'.format(self.args['assert']))
                break
        self.logger.info("Command '{}' done.".format(self.command))

class ScenarioTaskCls(ScenarioTask):
    """
    Clear vterm screen.
    """

    def __init__(self, args):
        ScenarioTask.__init__(self, 'vterm-cls')

    def run(self):
        self.logger.info("Clearing the screen.")

        for i in range(30):
            self.machine.type('\n')
