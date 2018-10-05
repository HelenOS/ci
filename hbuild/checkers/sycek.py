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

from hbuild.scheduler import Task, RunCommandException, TaskException
import os
import re

class SycekBuildTask(Task):
    def __init__(self):
        Task.__init__(self, 'tool-build', tool='sycek')

    def run(self):
        my_dir = self.ctl.make_temp_dir('build/sycek')

        # Clone sycek
        res = self.ctl.run_command([
                'git',
                'clone',
                '--quiet',
                '--depth', '1',
                'https://github.com/jxsvoboda/sycek',
                my_dir
            ])
        if res['failed']:
            return False

        # Build sycek
        res = self.ctl.run_command([
                'make',
            ], cwd=my_dir)
        if res['failed']:
            return False

        ret = {
            'sycek_bin': my_dir + '/ccheck',
        }

        return ret

class SycekCheckTask(Task):
    def __init__(self):
        Task.__init__(self, 'sycek-style-check')
        self.ignored_files_patterns = [
             re.compile('^uspace/lib/pcut/')
        ]

    def check_one_file(self, sycek, root_dir, filename):
        try:
            res = self.ctl.run_command([ sycek, filename ], cwd=root_dir, needs_output=True)
        except RunCommandException as ex:
            res = {
                'output': ex.output
            }
        issues_count = len(res['output'])
        if issues_count == 0:
            self.ctl.append_line_to_log_file("%s: no error." % filename)
            return ( True, 0 )
        else:
            self.ctl.append_line_to_log_file("%s: there were issues, see above." % filename)
            return ( False, issues_count )

    def run(self):
        root_dir = self.ctl.get_dependency_data('dir')
        sycek_bin = self.ctl.get_dependency_data('sycek_bin')

        all_okay = True

        top_dirs = [ 'abi', 'kernel', 'boot', 'uspace' ]

        files_total = 0
        files_okay = 0
        files_failures = 0
        files_errors = 0
        issues_total = 0


        for top_dir in top_dirs:
            for path_prefix, dirs_ignored, filenames in os.walk(os.path.join(root_dir, top_dir)):
                path_prefix = os.path.relpath(path_prefix, root_dir)
                for filename in filenames:
                    is_c_file = filename.endswith('.h') or filename.endswith('.c')
                    if not is_c_file:
                        continue

                    filename_with_path = os.path.join(path_prefix, filename)

                    skip = False
                    for pat in self.ignored_files_patterns:
                        if pat.match(filename_with_path) is not None:
                            skip = True
                            break
                    if skip:
                        continue

                    ( okay, issues_count ) = self.check_one_file(sycek_bin, root_dir, filename_with_path)
                    all_okay = all_okay and okay

                    files_total = files_total + 1
                    if okay:
                        if issues_count == 0:
                            files_okay = files_okay + 1
                        else:
                            files_failures = files_failures + 1
                        issues_total = issues_total + issues_count
                    else:
                        files_errors = files_errors + 1

        self.ctl.append_line_to_log_file("")
        self.ctl.append_line_to_log_file("Sycek C style checker summary")
        self.ctl.append_line_to_log_file("Files scanned: %d" % files_total)
        self.ctl.append_line_to_log_file("Files clean: %d" % files_okay)
        self.ctl.append_line_to_log_file("Files with issues: %d" % files_failures)
        self.ctl.append_line_to_log_file("Files with errors: %d" % files_errors)
        self.ctl.append_line_to_log_file("Total issues found: %d" % issues_total)

        if all_okay:
            return True
        else:
            raise TaskException("Some files has C style issues.")
