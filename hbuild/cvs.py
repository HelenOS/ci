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

from hbuild.scheduler import Task

class CvsCheckoutTask(Task):
    def __init__(self, **attrs):
        Task.__init__(self, 'checkout', **attrs)

    def do_checkout(self, target_directory):
        raise Exception('CvsCheckoutTask.do_checkout() cannot be called directly.')

    def run(self):
        dname = '%s/%s' % (self.ctl.make_temp_dir('repo'), self.name)

        self.do_checkout(dname)

        return {
            'dir': dname
        }

class BzrCheckoutTask(CvsCheckoutTask):
    def __init__(self, name, url):
        self.name = name
        self.url = url
        CvsCheckoutTask.__init__(self, repository=url, alias=name)

    def do_checkout(self, target_directory):
        res = self.ctl.run_command(['bzr', 'branch', self.url, target_directory ])
        if res['failed']:
            raise Exception('Bazaar checkout of %s failed.' % self.url)

class GitCheckoutTask(CvsCheckoutTask):
    def __init__(self, name, url):
        self.name = name
        self.url = url
        CvsCheckoutTask.__init__(self, repository=url, alias=name)

    def do_checkout(self, target_directory):
        res = self.ctl.run_command(['git', 'clone', '--quiet', '--depth', '5', self.url, target_directory ])
        if res['failed']:
            raise Exception('Git clone of %s failed.' % self.url)
        hash = self.ctl.run_command(['git', 'rev-parse', 'HEAD'], cwd=target_directory, needs_output=True)
        if not hash['failed']:
            self.report['attrs']['revision'] = hash['stdout'].strip()

class RsyncCheckoutTask(CvsCheckoutTask):
    def __init__(self, name, base):
        self.name = name
        self.base = base
        CvsCheckoutTask.__init__(self, repository=base, alias=name)

    def do_checkout(self, target_directory):
        res = self.ctl.run_command(['rsync', '-a', self.base + '/', target_directory ])
        if res['failed']:
            raise Exception('Rsync of %s failed.' % self.base)

