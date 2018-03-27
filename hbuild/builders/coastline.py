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

from hbuild.scheduler import Task, TaskException, RunCommandException

def sorted_dir(root):
    list = os.listdir(root)
    list.sort()
    return list

class CoastlineGetHarboursTask(Task):
    def __init__(self, harbour_filter):
        self.harbour_filter = harbour_filter
        Task.__init__(self, None)
        
    def get_harbour_dependencies(self, harbour_file):
        try:
            cmd = '. %s; echo $shiptugs;' % harbour_file
            res = self.ctl.run_command([ 'sh', '-c', cmd ], needs_output=True)
            return res['stdout'].split()
        except RunCommandException as e:
            return []
    
    def run(self):
        root = self.ctl.get_dependency_data('dir')
        self.ctl.dprint("Looking into %s", root)
        harbours = []
        dependencies = {}
        for name in sorted_dir(root):
            path = os.path.join(root, name)
            canon = os.path.join(path, 'HARBOUR')
            if os.path.isdir(path) and os.path.exists(canon) and os.path.isfile(canon):
                harbours.append(name)
                dependencies[name] = self.get_harbour_dependencies(canon)
        
        # Clean-up the dependencies
        for h in harbours:
            deps = dependencies[h]
            dependencies[h] = []
            for d in deps:
                if d in harbours:
                    dependencies[h].append(d)
        
        # Filter which harbours should be actually built
        if 'ALL' in self.harbour_filter:
            self.harbour_filter = dependencies.keys()
        
        harbours_to_build = {}
        for h in harbours:
            if h in self.harbour_filter:
                harbours_to_build[h] = True
        dependency_added = True
        while dependency_added:
            dependency_added = False
            so_far = list(harbours_to_build.keys())
            for h in so_far:
                for d in dependencies[h]:
                    if not d in harbours_to_build:
                        harbours_to_build[d] = True
                        dependency_added = True
        
        self.ctl.dprint("harbours_to_build = %s", list(harbours_to_build.keys()))
        
        # Sort harbours in buildable order
        build_order = []
        remaining_dependencies = dependencies.copy()
        while len(remaining_dependencies) > 0:
            self.ctl.dprint("remaining = %s", remaining_dependencies)
            leafs = []
            for d in remaining_dependencies:
                if len(remaining_dependencies[d]) == 0:
                    if d in harbours_to_build:
                        build_order.append(d)
                    leafs.append(d)
            # In every step we have to find (at least) one element to
            # remove
            if len(leafs) == 0:
                raise TaskException("Circular dependency found!")
            for l in leafs:
                del remaining_dependencies[l]
                for d in remaining_dependencies:
                    remaining_dependencies[d] = [x for x in remaining_dependencies[d] if x != l]
        
        
        self.ctl.dprint("harbours = %s", build_order)
        self.ctl.dprint("deps = %s" , dependencies)
        
        return {
            'harbours': build_order,
            'harbour_deps': dependencies,
            'coastline_root': root
        }

class CoastlineFetchTask(Task):
    def __init__(self, harbour, root, mirror):
        self.harbour = harbour
        self.root = root
        self.mirror = mirror
        Task.__init__(self, 'harbour-fetch', package=harbour)
    
    def run(self):
        self.ctl.run_command([ self.root + '/hsct.sh', 'fetch', self.harbour ], cwd=self.mirror)


class CoastlineScheduleFetchesTask(Task):
    def __init__(self, scheduler):
        self.scheduler = scheduler
        Task.__init__(self, None)
    
    def run(self):
        harbours = self.ctl.get_dependency_data('harbours')
        coastline_root = self.ctl.make_temp_dir('repo/coastline')

        mirror = self.ctl.make_temp_dir('mirror')

        tasks = {}
        for h in harbours:
            task_name = "coastline-fetch-%s" % h
            self.scheduler.submit("Fetching tarballs for %s" % h,
                task_name,
                CoastlineFetchTask(h, coastline_root, mirror))
            tasks[ h ] = task_name
        return {
            'fetch_tasks': tasks
        }

class CoastlinePrebuildTask(Task):
    def __init__(self, profile, build_dir_basename, archive_format):
        self.profile = profile
        self.build_dir_basename = build_dir_basename
        self.archive_format = archive_format
        Task.__init__(self, None)
    
    def run(self):
        root = self.ctl.make_temp_dir('repo/coastline')
        
        my_dir = self.ctl.make_temp_dir('build/%s/coast' % self.build_dir_basename)
        hsrootdir = self.ctl.make_temp_dir('build/%s/helenos' % self.build_dir_basename)
        self.ctl.run_command([ root + '/hsct.sh', 'init', hsrootdir ], cwd=my_dir)
        
        return {
            'dir': my_dir
        }

class CoastlineBuildTask(Task):
    def __init__(self, harbour, profile, archive_format):
        self.harbour = harbour
        self.profile = profile
        self.archive_format = archive_format
        Task.__init__(self, 'harbour-build', package=harbour, arch=profile)
    
    def run(self):
        my_dir = self.ctl.get_dependency_data('dir')
        
        root = self.ctl.make_temp_dir('repo/coastline')
        
        res = self.ctl.run_command([ root + '/hsct.sh', 'archive', self.harbour ], cwd=my_dir)
        if res['failed']:
            return False
        
        # Add downloadable archive
        profile_flat = self.profile.replace("/", "-")
        title = "%s for %s" % ( self.harbour, self.profile )
        target_filename = '%s/%s-for-helenos-%s.%s' % ( profile_flat, self.harbour, profile_flat, self.archive_format )
        current_filename = '%s/archives/%s.%s' % ( my_dir, self.harbour, self.archive_format )
        self.ctl.add_downloadable_file(title, target_filename, current_filename)
        
        return {
            'harbour-{}'.format(self.harbour): current_filename
        }


class CoastlineScheduleBuildsTask(Task):
    def __init__(self, scheduler, archive_format):
        self.scheduler = scheduler
        self.archive_format =archive_format
        Task.__init__(self, None)
    
    def run(self):
        profiles = self.ctl.get_dependency_data('profiles')
        harbours = self.ctl.get_dependency_data('harbours')
        harbour_deps = self.ctl.get_dependency_data('harbour_deps')
        
        ret = {}
        
        for p in profiles:
            if p == 'special/abs32le':
                continue
            
            ret[ p ] = {}
            
            p_flat = p.replace("/", "-")
            
            self.scheduler.submit("Preparing coastline for %s" % p,
                "coastline-prepare-for-%s" % p_flat,
                CoastlinePrebuildTask(p, p_flat, self.archive_format),
                [ "helenos-build-%s" % p_flat ])
            
            for h in harbours:    
                task_name = "coastline-build-%s-for-%s" % (h, p_flat)
                deps = [
                    "coastline-prepare-for-%s" % p_flat,
                    "coastline-fetch-%s" % h
                ]
                for d in harbour_deps[ h ]:
                    deps.append( "coastline-build-%s-for-%s" % (d, p_flat) )
                self.scheduler.submit("Building %s for %s" % (h, p),
                    task_name,
                    CoastlineBuildTask(h, p, self.archive_format),
                    deps)
                
                ret[p][h] = task_name
        
        return {
            'harbour_tasks' : ret
        }
