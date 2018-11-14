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


import argparse
import yaml
import logging
import sys

from htest.vm.controller import VMManager
from htest.vm.qemu import QemuVMController
from htest.tasks import *

args = argparse.ArgumentParser(
    description='Testing of HelenOS in VM',
    formatter_class=argparse.RawDescriptionHelpFormatter,
    epilog="""
Typical invocation will use the following arguments:
  --image helenos.iso
  --scenario scenario.yml
  --arch amd64               # ia32, ppc32 etc.
  --vterm-dump dump.txt      # all text from main vterm
  --last-screenshot shot.png # last VM screen
"""
)
args.add_argument('--headless',
    dest='headless',
    default=False,
    action='store_true',
    help='Do not show any VM windows.'
)
args.add_argument('--scenario',
    metavar='FILENAME.yml',
    dest='scenario',
    required=True,
    help='Scenario file'
)
args.add_argument('--arch',
    metavar='ARCHITECTURE',
    dest='architecture',
    required=True,
    help='Emulated architecture identification.'
)
args.add_argument('--memory',
    metavar='MB',
    dest='memory',
    type=int,
    required=False,
    default=256,
    help='Amount of memory for the virtual machine.'
)
args.add_argument('--image',
    metavar='FILENAME',
    dest='boot_image',
    required=True,
    help='HelenOS boot image (e.g. ISO file).'
)
args.add_argument('--disk',
    metavar='FILENAME',
    dest='disk_image',
    required=False,
    default=None,
    help='Disk image (e.g. hdisk.img).'
)
args.add_argument('--pass',
    metavar='OPTION',
    dest='pass_thru_options',
    default=[],
    action='append',
    help='Extra options to pass through to the emulator'
)
args.add_argument('--vterm-dump',
    metavar='FILENAME.txt',
    dest='vterm_dump',
    default=None,
    help='Where to store full vterm dump.'
)
args.add_argument('--last-screenshot',
    metavar='FILENAME.png',
    dest='last_screenshot',
    default=None,
    help='Where to store last screenshot.'
)
args.add_argument('--debug',
    dest='debug',
    default=False,
    action='store_true',
    help='Print debugging messages'
)

config = args.parse_args()

if config.debug:
    config.logging_level = logging.DEBUG
else:
    config.logging_level = logging.INFO

logging.basicConfig(
    format='[%(asctime)s %(name)-16s %(levelname)7s] %(message)s',
    level=config.logging_level
)

logger = logging.getLogger('main')

with open(config.scenario, 'r') as f:
    try:
        scenario = yaml.load(f)
    except yaml.YAMLError as ex:
        logger.error(ex)
        sys.exit(1)

if config.memory < 8:
    logger.error("Specify at least 8MB of memory.")
    sys.exit(1)

controller = None
for ctl in [ QemuVMController ]:
    if ctl.is_supported(config.architecture):
        controller = ctl

if controller is None:
    logger.error("Unsupported architecture {}.".format(config.architecture))
    sys.exit(1)

vmm = VMManager(controller, config.architecture, config.boot_image, config.disk_image, config.memory, config.headless, config.pass_thru_options)

scenario_tasks = []
for t in scenario['tasks']:
    task_name = None
    if type(t) is dict:
        k = list(set(t.keys()) - set(['name', 'machine']))
        if len(k) != 1:
            raise Exception("Unknown task ({})!".format(k))
        task_name = k[0]
    elif type(t) is str:
        task_name = t
        t = {
            task_name: {}
        }
    else:
        raise Exception("Unknown task!")
    task_classname = 'ScenarioTask' + task_name.title().replace('-', '_')
    task_class = globals()[task_classname]
    task_inst = task_class(t[task_name])
    if not ('machine' in t):
        t['machine'] = None
    machine = vmm.get(t['machine'])
    if machine is None:
        if t['machine'] is None:
            t['machine'] = 'default'
        logger.debug("Creating new machine {}.".format(t['machine']))
        machine = vmm.create(t['machine'])
    task_inst.set_machine(machine)
    scenario_tasks.append(task_inst)

exit_code = 0
try:
    for t in scenario_tasks:
        t.run()
    print("Scenario passed.")
except Exception as ex:
    logger.exception("Scenario aborted: {}".format(ex))
    print("Scenario aborted: {}".format(ex))
    exit_code = 1

vmm.terminate(config.vterm_dump, config.last_screenshot)
sys.exit(exit_code)
