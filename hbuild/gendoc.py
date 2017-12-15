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
import os

class BrowsableSourcesViaGnuGlobalTask(Task):
    def __init__(self):
        Task.__init__(self, 'browsable-sources-global')

    def run(self):
        root_dir = self.ctl.get_dependency_data('dir')
        my_dir = self.ctl.make_temp_dir('build/browsable')
        self.ctl.recursive_copy(root_dir, my_dir)
        
        # For debugging, it is much better to generate the
        # documentation in a sub-directory to speed things-up
        # Following line is a possible way how to do that:
        # my_dir = os.path.join(my_dir, 'abi')
        
        res = self.ctl.run_command([ 'gtags' ], cwd=my_dir)
        if res['failed']:
            return False
        
        res = self.ctl.run_command([
                'htags',
                '--tree-view',
                '--table-flist',
                '-tmainline'
            ], cwd=my_dir)
        if res['failed']:
            return False
        
        footer_links = [
            '<a href="http://www.helenos.org">HelenOS homepage</a>',
            '<a href="https://github.com/HelenOS/helenos">sources at GitHub</a>',
        ]
        
        res = self.ctl.run_command([
                'find',
                os.path.join(my_dir, 'HTML/'),
                '-name', '*.html',
                '-exec',
                    'sed',
                        '-e', '/<head>/a <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />',
                        '-e', '/<body>/a <h1>HelenOS sources</h1>',
                        '-e', '/<\/body>/i <address>{}</address>'.format(', '.join(footer_links)),
                        '-i', '{}',
                    ';',
            ], cwd=my_dir)
        if res['failed']:
            return False
        
        self.ctl.move_dir_to_downloadable('Browsable sources', 'sources', os.path.join(my_dir, 'HTML'))
        
        ret = {
            'dir': my_dir,
        }
        
        return ret
