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

import os
import re
import fnmatch

from hbuild.scheduler import Task
from hbuild.builders.helenos import HelenOSBuildWithHarboursTask

class GetTestListTask(Task):
    def __init__(self, root_path, test_filter):
        Task.__init__(self, None)
        self.root_path = os.path.abspath(os.path.join(root_path, 'scenarios'))
        self.test_filter = test_filter

    def get_scenario_list(self, root, base):
        if base == 'dummy/':
            return []
        
        tests = []
        for name in os.listdir(root):
            path = os.path.join(root, name)
            if os.path.isdir(path):
                tmp = self.get_scenario_list(path, base + name + '/')
                for t in tmp:
                    tests.append(t)
            elif os.path.isfile(path):
                xxx, ext = os.path.splitext(path)
                if ext == '.yml':
                    tests.append(base + name)
        
        return tests

    def run(self):
        files = self.get_scenario_list(self.root_path, '')
        
        if 'ALL' in self.test_filter:
            self.test_filter = files
        
        files_filtered = []
        for fn in files:
            for pat in self.test_filter:
                if fnmatch.fnmatch(fn, pat):
                    files_filtered.append(fn)
                    break
        
        self.ctl.dprint('scenarios files: %s', files_filtered)
        return {
            'scenarios' : files_filtered,
            'scenario_dir': self.root_path
        }


class ScheduleTestsTask(Task):
    NEEDED_HARBOUR_PATTERN = re.compile('^[ ]*#[ ]*@needs[ ]+(?P<HARBOURS>.*)$')
    SPLIT_HARBOURS_PATTERN = re.compile('\w+')
    
    def __init__(self, scheduler, extra_builds, base_path, extra_tester_options):
        self.scheduler = scheduler
        self.testable_profiles = [ 'ia32', 'amd64', 'arm32/integratorcp', 'ppc32' ]
        self.extra_builds = extra_builds
        self.base_path = base_path
        self.extra_tester_options = extra_tester_options
        Task.__init__(self, None)
    
    def run(self):
        helenos_build_tasks = self.ctl.get_dependency_data('helenos_tasks')
        scenarios = self.ctl.get_dependency_data('scenarios')
        scenario_base_path = self.ctl.get_dependency_data('scenario_dir')
        harbour_tasks = self.ctl.get_dependency_data('harbour_tasks')
        
        self.extra_builds.set_dependent_tasks(helenos_build_tasks, harbour_tasks)
        
        profiles_all = helenos_build_tasks.keys()
        profiles = []
        for p in self.testable_profiles:
            if p in profiles_all:
                profiles.append(p)
        
        
        for scenario in scenarios:
            for profile in profiles:
                scenario_filename = os.path.join(scenario_base_path, scenario)
                dep_harbours = self.get_needed_harbours(scenario_filename)
                if len(dep_harbours) > 0:
                    helenos_task = self.extra_builds.build(profile, dep_harbours)
                    if helenos_task is None:
                        # TODO: properly handle the error
                        continue
                else:
                    helenos_task = helenos_build_tasks[profile]
                scenario_flat = scenario.replace('/', '-').replace('.', '-')
                self.scheduler.submit("Testing {} on {}".format(scenario, profile),
                    'test-{}-{}'.format(profile.replace('/', '-'), scenario_flat),
                    TestRunTask(profile, scenario, scenario_filename,
                        os.path.abspath(os.path.join(self.base_path, 'vm-test.py')), self.extra_tester_options),
                    [ helenos_task ],
                    [ 'qemu-kvm' ]
                )
        
        
#         scenario_dependencies = {}
#         for s in scenarios:
#             scenario_dependencies[s] = {}
#             harbours =
#             for p in profiles:
#                 scenario_dependencies[s][p] = [
#                     self.extra_builds.build(p, harbours)
#                 ]
#                 
#         
#         needed_harbours = {}
#         for s in scenarios:
#            
#             needed_harbours[ s ] = {
#                 'harbours': harbours,
#                 'hash': '-'.join(harbours)
#             }
#         
#         self.ctl.dprint('Harbour tasks: {}'.format(harbour_tasks))
#         self.ctl.dprint('Needed harbours: {}'.format(needed_harbours))
#         
#         for p in profiles:
#             special_images_tasks = {}
#             for s in scenarios:
#                 self.ctl.dprint('{}/{}: special-tasks: {}'.format(p, s, special_images_tasks))
#                 s_flat = s.replace('/', '-').replace('.', '-')
#                 deps = [ helenos_build_tasks[p] ]
#                 if len(needed_harbours[s]['harbours']) > 0:
#                     if not needed_harbours[s]['hash'] in special_images_tasks:
#                         extra_deps = [ helenos_build_tasks[p] ]
#                         continue_outer = False
#                         for h in needed_harbours[s]['harbours']:
#                             if h not in harbour_tasks[p]:
#                                 continue_outer = True
#                                 break
#                             else:
#                                 extra_deps.append(harbour_tasks[p][h])
#                         if continue_outer:
#                             continue
#                         task_name = 'extra-{}-with-{}'.format(p.replace('/', '-'), needed_harbours[s]['hash'])
#                         self.scheduler.submit("Special build of {} with {}".format(p, ','.join(needed_harbours[s]['harbours'])),
#                             task_name,
#                             HelenOSBuildWithHarboursTask(p, needed_harbours[s]['harbours']),
#                             extra_deps,
#                             [ 'extras-{}'.format(p) ]
#                         )
#                         special_images_tasks[ needed_harbours[s]['hash'] ] = task_name
#                     deps.append(special_images_tasks[ needed_harbours[s]['hash'] ])
#                 self.scheduler.submit("Testing {} on {}".format(s, p),
#                     'test-{}-{}'.format(p.replace('/', '-'), s_flat),
#                     TestRunTask(p, s, os.path.join(scenario_base_path, s)),
#                     deps,
#                     [ 'qemu-kvm' ]
#                 )
#         
        return True
    
    def get_needed_harbours(self, scenario_filename):
        with open(scenario_filename) as f:
            try:
                import yaml
                scenario = yaml.load(f)
                if ('meta' in scenario) and ('harbours' in scenario['meta']):
                    res = scenario['meta']['harbours']
                    res.sort()
                    return res
            except Exception as ex:
                pass
        return []

class TestRunTask(Task):
    def __init__(self, profile, scenario_name, scenario_full_filename, test_script_filename, extra_test_script_options):
        self.profile = profile
        self.scenario_name = scenario_name
        self.scenario = scenario_full_filename
        self.tester = os.path.abspath(test_script_filename)
        self.tester_options = extra_test_script_options
        Task.__init__(self, 'test', arch=profile, scenario=scenario_name)

    def run(self):
        os_image = self.ctl.get_dependency_data('image')
        my_dir = self.ctl.get_dependency_data('dir')
        if os_image is None:
            return False
        # FIXME: this is probably not the best location for the files
        vterm_dump = os.path.join(my_dir, 'dump.txt')
        screenshot = os.path.join(my_dir, 'screenshot.png')
        command = [
            self.tester,
            '--debug',
            '--headless',
            '--arch={}'.format(self.profile),
            '--image={}'.format(os_image),
            '--vterm-dump={}'.format(vterm_dump),
            '--last-screenshot={}'.format(screenshot),
        ]
        for i in self.tester_options:
            command.append(i)
        command.append('--scenario')
        command.append(self.scenario)
        res = self.ctl.run_command(command)
        if res['failed']:
            return False

        profile_flat = self.profile.replace("/", "-")
        scenario_flat = self.scenario_name.replace('.yml', '').replace('/', '-').replace('.', '-')
        self.ctl.add_downloadable_file("Last screen", '{}/test-{}-screen.png'.format(profile_flat, scenario_flat), screenshot)
        self.ctl.add_downloadable_file("Terminal dump", '{}/test-{}-vterm.txt'.format(profile_flat, scenario_flat), vterm_dump)

        return True
