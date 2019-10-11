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

from hbuild.scheduler import Task

def sorted_dir(root):
    list = os.listdir(root)
    list.sort()
    return list

class HelenOSBuildTask(Task):
    def __init__(self, profile, build_dir_basename, src_dir, image_name):
        self.profile = profile
        self.build_dir_basename = build_dir_basename
        self.src_dir = src_dir
        self.image = image_name
        Task.__init__(self, 'helenos-build', arch=profile)
    
    def run(self):
        my_dir = self.ctl.make_temp_dir('build/%s/helenos' % self.build_dir_basename)
        self.ctl.recursive_copy(self.src_dir, my_dir)
        
        build_dir = my_dir + '/build'
        
        self.ctl.run_command([ 'mkdir', build_dir ], cwd=my_dir);
        
        res = self.ctl.run_command([ 'sh', my_dir + '/configure.sh', self.profile ], cwd=build_dir);
        if res['failed']:
            return False
        
        res = self.ctl.run_command([ 'ninja' ], cwd=build_dir)
        if res['failed']:
            return False
        
        res = self.ctl.run_command([ 'ninja', 'image_path' ], cwd=build_dir)
        if res['failed']:
            return False
        
        ret = {
            'image': None,
            'built-image': self.image,
            'dir': my_dir,
        }
        
        if not self.image is None:
            profile_flat = self.profile.replace("/", "-")
            xxx, image_extension = os.path.splitext(self.image)
            target_image_name = '%s/helenos-%s%s' % ( profile_flat, profile_flat, image_extension )
            build_image_name = '%s/%s' % ( build_dir, self.image )
            ret['image'] = self.ctl.add_downloadable_file("HelenOS boot image", target_image_name, build_image_name)
        
        return ret

class HelenOSBuildWithHarboursTask(Task):
    def __init__(self, profile, harbours):
        self.profile = profile
        self.harbours = harbours
        Task.__init__(self, 'helenos-extra-build', arch=profile, harbours=','.join(harbours))
    
    def run(self):
        my_dir = self.ctl.get_dependency_data('dir')
        res = self.ctl.run_command([ 'rm', '-rf', os.path.join('uspace', 'overlay')], cwd=my_dir)
        os.makedirs(os.path.join(my_dir, 'uspace', 'overlay'), exist_ok=True)
        if res['failed']:
            return False
        
        build_dir = my_dir + '/build'
        
        # Unpack the tarball
        for h in self.harbours:
            tarball = self.ctl.get_dependency_data('harbour-{}'.format(h))
            if tarball.endswith('.tar.xz'):
                command = [ 'tar', 'xJf', tarball ]
            elif tarball.endswith('.tar.gz'):
                command = [ 'tar', 'xzf', tarball ]
            else:
                return False
            res = self.ctl.run_command(command, cwd=os.path.join(my_dir, 'uspace', 'overlay'))
            if res['failed']:
                return False
        
        res = self.ctl.run_command([ 'ninja' ], cwd=build_dir)
        if res['failed']:
            return False
        
        res = self.ctl.run_command([ 'ninja', 'image_path' ], cwd=build_dir)
        if res['failed']:
            return False
        
        ret = {
            'image': None,
            'dir': my_dir,
        }
        
        image_name = self.ctl.get_dependency_data('built-image')
        if not image_name is None:
            profile_flat = self.profile.replace("/", "-")
            xxx, image_extension = os.path.splitext(image_name)
            target_image_name = '{}/helenos-{}-with-{}{}'.format( profile_flat, profile_flat, '-'.join(self.harbours), image_extension )
            build_image_name = os.path.join(build_dir, image_name)
            ret['image'] = self.ctl.add_downloadable_file("HelenOS boot image with {}".format(', '.join(self.harbours)), target_image_name, build_image_name)
            
        return ret

class HelenOSExtraBuildsManager:
    def __init__(self, scheduler):
        self.scheduler = scheduler
        self.already_scheduled = []
        self.helenos_tasks = {}
        self.coastline_tasks = {}
        
    def set_dependent_tasks(self, helenos_tasks, coastline_tasks):
        self.helenos_tasks = helenos_tasks
        self.coastline_tasks = coastline_tasks
    
    def build(self, profile, harbours):
        #print("HelenOSExtraBuildsManager.build({}, {})".format(profile, harbours))
        harbours = sorted(harbours)
        
        key = 'extra-{}-with-{}'.format(profile.replace('/', '-'), '-'.join(harbours))
        if key in self.already_scheduled:
            return key
        
        # FIXME - propagate the problem in a more meaningful way
        if not profile in self.helenos_tasks.keys():
            return None
        if not profile in self.coastline_tasks.keys():
            return None
        
        deps = [ self.helenos_tasks[profile] ]
        for h in harbours:
            if not h in self.coastline_tasks[profile].keys():
                return None
            deps.append(self.coastline_tasks[profile][h])
        
        self.already_scheduled.append(key)
                
        self.scheduler.submit(
            "Special build of {} with {}".format(profile, ','.join(harbours)),
            key,
            HelenOSBuildWithHarboursTask(profile, harbours),
            deps,
            [ 'extras-{}'.format(profile) ]
        )
        
        return key

class HelenOSGetProfilesTask(Task):
    def __init__(self, platform_filter):
        self.platform_filter = platform_filter
        Task.__init__(self, None)
    
    def _try_read_output_filename(self, dirname):
        try:
            with open('%s/output' % dirname, 'r') as output:
                content = output.read()
            return content
        except OSError as e:
            return None

    def get_output_filename(self, root, name, subname = None):
        if not subname is None:
            output = self._try_read_output_filename('%s/%s/%s' % (root, name, subname))
            if not output is None:
                return output
        return self._try_read_output_filename('%s/%s' % (root, name))


    def run(self):
        root = self.ctl.get_dependency_data('dir')
        root = "%s/defaults" % root
        self.ctl.dprint("Looking into %s", root)
        profiles = {}
        for name in sorted_dir(root):
            path = os.path.join(root, name)
            canon = os.path.join(path, 'Makefile.config')
            if os.path.isdir(path) and os.path.exists(canon) and os.path.isfile(canon):
                subprofile = False
                for subname in sorted_dir(path):
                    subpath = os.path.join(path, subname)
                    subcanon = os.path.join(subpath, 'Makefile.config')
                    if os.path.isdir(subpath) and os.path.exists(subcanon) and os.path.isfile(subcanon):
                        subprofile = True
                        output = self.get_output_filename(root, name, subname)
                        n = '{}/{}'.format(name, subname)
                        # Hack for some arm32 architectures
                        if n in [ 'arm32/beagleboardxm', 'arm32/beaglebone', 'arm32/gta02', 'arm32/raspberrypi' ]:
                            output = 'uImage.bin'
                        profiles[ n ] = output
                if not subprofile:
                    profiles[ name ] = self.get_output_filename(root, name)

        if 'ALL' in self.platform_filter:
            self.platform_filter = profiles.keys()
        
        profiles_filtered = {}
        for p in profiles:
            p_wildcard = p.split('/')[0] + '/*'
            if (p in self.platform_filter) or (p_wildcard in self.platform_filter):
                profiles_filtered[p] = profiles[p]
        
        self.ctl.dprint("%s", profiles_filtered)

        return {
            'profiles': profiles_filtered,
            'dir': self.ctl.get_dependency_data('dir')
        }

class HelenOSScheduleBuildsTask(Task):
    def __init__(self, scheduler):
        self.scheduler = scheduler
        Task.__init__(self, None)
    
    def run(self):
        profiles = self.ctl.get_dependency_data('profiles')
        root_dir = self.ctl.get_dependency_data('dir')
        tasks = {}
        for p in profiles:
            p_flat = p.replace("/", "-")
            task_name = "helenos-build-%s" % p_flat
            self.scheduler.submit("Building HelenOS for %s" % p,
                task_name,
                HelenOSBuildTask(p, p_flat, root_dir, profiles[p]))
            tasks[ p ] = task_name
        return {
            'helenos_tasks': tasks
        }

