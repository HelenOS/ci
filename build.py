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

import subprocess
import os
import time
import sys
import argparse
import multiprocessing
from hbuild.scheduler import BuildScheduler
from hbuild.cvs import *
from hbuild.builders.helenos import *
from hbuild.builders.coastline import *
from hbuild.builders.tests import *
from hbuild.web import *
from hbuild.output import ConsolePrinter

def create_checkout_task(name, url):
    if url.startswith("wip://"):
        return RsyncCheckoutTask(name, url[6:])
    else:
        return BzrCheckoutTask(name, url)

# Command-line options
args = argparse.ArgumentParser(description='HelenOS integration build')
args.add_argument('--helenos-repository', default='bzr://helenos.org/mainline', dest='helenos_repository',
    metavar='PATH',
    help='HelenOS repository path'
)
args.add_argument('--coastline-repository', default='bzr://helenos.org/coastline', dest='coastline_repository',
    metavar='PATH',
    help='Coastline repository path'
)
args.add_argument('--build-id', default='0', dest='build_id',
    metavar='ID',
    help='Build id (typically sequence number).',
)
args.add_argument('--rss-url', default='', dest='rss_url',
    metavar='URL_WITH_RSS',
    help='URL of RSS for latest builds.'
)
args.add_argument('--resource-path', default=None, dest='web_resource_path',
    metavar='RELATIVE_PATH',
    help='Path where static web resources are stored (when specified, the resources are NOT copied).'
)
args.add_argument('--build-directory', default=os.path.abspath('tmp'), dest='build_directory',
    metavar='DIR',
    help='Where to build (space for temporary files).',
)
args.add_argument('--artefact-directory', default=os.path.abspath('out/'), dest='artefact_directory',
    metavar='DIR',
    help='Where to place downloadable files and HTML report.'
)
args.add_argument('--platforms', default='ALL', dest='platforms',
    metavar='PLATFORM1[,PLATFORM2[,...]',
    help='Which platforms to build (defaults to all detected ones; can be either machine specific "ia64/ski" or architecture specific "ia64/*").'
)
args.add_argument('--harbours', default='ALL', dest='harbours',
    metavar='HARBOUR1[,HARBOUR2[,...]',
    help='Which harbours to build (defaults to all detected ones).'
)
args.add_argument('--tests', default='ALL', dest='tests',
    metavar='TEST1[,TEST2[,...]]',
    help='Which tests to run (shell wildcards supported).'
)
args.add_argument('--vm-memory-size', default=256, dest='vm_memory_size',
    type=int,
    metavar='RAM_SIZE_IN_MB',
    help='How much memory to give the virtual machine running the tests.'
)
args.add_argument('--jobs', default=multiprocessing.cpu_count(), dest='jobs',
    type=int,
    metavar='COUNT',
    help='Number of concurrent jobs.'
)
args.add_argument('--no-colors', default=False, dest='no_colors',
    action='store_true',
    help='Disable colorful output'
)
args.add_argument('--debug', default=False, dest='debug',
    action='store_true',
    help='Print debugging messages'
)

config = args.parse_args()
config.artefact_directory = os.path.abspath(config.artefact_directory)
config.build_directory = os.path.abspath(config.build_directory)
config.self_path = os.path.dirname(os.path.realpath(sys.argv[0]))

printer = ConsolePrinter(config.no_colors)

if config.vm_memory_size < 8:
    printer.print_warning("VM memory size too small, upgrading to 8MB.")
    config.vm_memory_size = 8

scheduler = BuildScheduler(
    max_workers=config.jobs,
    build=config.build_directory,
    artefact=config.artefact_directory,
    build_id=config.build_id,
    printer=printer,
    debug=config.debug
)

#
# Check-out both HelenOS and coastline repositories
scheduler.submit("Checking-out HelenOS",
    "helenos-checkout", 
    create_checkout_task("helenos", config.helenos_repository))
scheduler.submit("Checking-out Coastline",
    "coastline-checkout",
    create_checkout_task("coastline", config.coastline_repository))

#
# HelenOS (mainline): get list of profiles (i.e. supported architectures
# and platforms) and build all of them
scheduler.submit("Determininig available profiles",
    "helenos-get-profiles",
    HelenOSGetProfilesTask(config.platforms.split(',')),
    ["helenos-checkout"])


scheduler.submit("Schedule HelenOS builds",
    "helenos-build",
    HelenOSScheduleBuildsTask(scheduler),
    ["helenos-get-profiles"])


#
# Coastline: get list of harbours (i.e. ported software) and build all of them
# for all HelenOS builds
scheduler.submit("Determining available harbours",
    "coastline-get-harbours",
     CoastlineGetHarboursTask(config.harbours.split(',')),
     ["coastline-checkout"])

scheduler.submit("Schedule harbour tarballs fetches",
    "coastline-fetch",
    CoastlineScheduleFetchesTask(scheduler),
    ["coastline-get-harbours" ])


scheduler.submit("Schedule Coastline builds",
    "coastline-build",
    CoastlineScheduleBuildsTask(scheduler),
    [
        # Data dependencies
        "helenos-get-profiles", "coastline-get-harbours",
        # Task dependencies
        "helenos-build", "coastline-fetch"
    ])


extra_builds = HelenOSExtraBuildsManager(scheduler)

#
# Tests
scheduler.submit("Determine available test scenarios",
    "tests-get-list",
    GetTestListTask(config.self_path, config.tests.split(',')),
    [])

scheduler.submit("Schedule tests",
    "tests-schedule",
    ScheduleTestsTask(scheduler, 
        extra_builds,
        config.self_path,
        [ "--memory={}".format(config.vm_memory_size) ]
    ),
    [
        "tests-get-list",
        "helenos-build",
        "coastline-build"
    ])


#
# Wait for all builds (and everything) to complete before creating
# the web page with results.
scheduler.barrier()

scheduler.close_report()

scheduler.submit("Generate HTML report",
    "html-report",
    MakeHtmlReportTask(config.self_path, config.rss_url, config.web_resource_path))


scheduler.done()
