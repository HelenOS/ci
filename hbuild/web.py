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

class MakeHtmlReportTask(Task):
    def __init__(self, root_path, rss_url, resource_path):
        Task.__init__(self, 'html-report')
        self.root = os.path.abspath(root_path)
        self.rss_url = rss_url
        self.static_resources_relative_path = resource_path

    def copy_file_to_downloadable(self, source_filename, dest_filename):
        with open(os.path.join(self.root, source_filename)) as input:
            content = input.read()
            with self.ctl.open_downloadable_file(dest_filename, 'w') as output:
                output.write(content)

    def run(self):
        copy_static_resources = False

        if self.static_resources_relative_path is None:
            self.static_resources_relative_path = './'
            copy_static_resources = True

        command = [
            'xsltproc',
            '--stringparam',
                'CONFIG_RESOURCE_DIR',
                self.static_resources_relative_path,
        ]

        if not self.rss_url is None:
            command.append('--stringparam')
            command.append('CONFIG_RSS_PATH')
            command.append(self.rss_url)

        command.append(os.path.join(self.root, 'hbuild/web/report.xsl'))
        command.append(self.ctl.get_artefact_absolute_path('report.xml'))

        res = self.ctl.run_command(command, needs_output=True)
        if res['failed']:
            return False

        with self.ctl.open_downloadable_file('index.html', 'w') as index_html:
            index_html.write(res['stdout'])

        if copy_static_resources:
            for filename in [ 'main.css', 'jquery-2.1.4.min.js' ]:
                src = os.path.join('hbuild/web/', filename)
                self.copy_file_to_downloadable(src, filename)
