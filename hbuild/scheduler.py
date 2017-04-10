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
import datetime
import shutil
import colorama
import sys

from threading import Lock, Condition

colorama.init()

class Task:
    def __init__(self, report_tag, **report_args):
        self.report = {
            'name': report_tag,
            'result': 'unknown',
            'attrs': {},
        }
        for k in report_args:
            self.report['attrs'][k] = report_args[k]
        self.ctl = None
    
    def execute(self):
        start_time = time.time()
        try:
            res = self.run()
            if res == False:
                raise Exception('run() returned False')
            self.report['result'] = 'ok'
            
            self.report['files'] = self.ctl.get_files()
            
            end_time = time.time()
            self.report['attrs']['duration'] = (end_time - start_time) * 1000
            
            if res is None:
                res = {}
            
            self.ctl.done()
            
            return {
                'status': 'ok',
                'data': res
            }
        except Exception as e:
            end_time = time.time()
            self.report['attrs']['duration'] = (end_time - start_time) * 1000
            
            self.report['result'] = 'fail'
            self.report['files'] = []
            self.ctl.done()
            raise e
    
    def run(self):
        pass
    
    def get_report(self):
        return self.report


class TaskException(Exception):
    def __init__(self, msg):
        Exception.__init__(self, msg)

class RunCommandException(TaskException):
    def __init__(self, msg, rc, output):
        self.rc = rc
        self.output = output
        Exception.__init__(self, msg)

class TaskController:
    def __init__(self, name, data, build_directory, artefact_directory, print_debug = False):
        self.name = name
        self.data = data
        self.files = []
        self.log = None
        self.log_tail = []
        self.build_directory = build_directory
        self.artefact_directory = artefact_directory
        self.print_debug_messages = print_debug
    
    def derive(self, name, data):
        return TaskController(name, data, self.build_directory, self.artefact_directory, self.print_debug_messages)
    
    def dprint(self, str, *args):
        if self.print_debug_messages:
            from colorama import Fore, Style
        
            print(Style.RESET_ALL + "[" + Fore.YELLOW + "debug " + self.name + Style.RESET_ALL + "]: " + str % args)
        
    
    def get_dependency_data(self, dep, key=None):
        if key is None:
            return self.get_data(dep)
        return self.data[dep][key]
    
    def get_data(self, key):
        for dep in self.data:
            if key in self.data[dep]:
                return self.data[dep][key]
        raise TaskException("WARN: unknown key %s" % key)
    
    def run_command(self, cmd, cwd=None, needs_output=False):
        self.dprint("Running `%s'..." % ' '.join(cmd))
        output = []
        last_line = ""
        rc = 0
        
        # FIXME: can we keep stdout and stderr separated?
        with subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, cwd=cwd) as proc:
            for line in proc.stdout:
                line = line.decode('utf-8').strip('\n')
                self.append_line_to_log_file(line)
                if needs_output:
                    output.append(line)
                last_line = line
            proc.wait()
            rc = proc.returncode
        if rc != 0:
            #self.dprint('stderr=%s' % stderr.strip('\n'))
        
            raise RunCommandException(
                "`%s' failed: %s" % (' '.join(cmd), last_line),
                rc, output)
        
        return {
            'output': output,
            'stdout': '\n'.join(output),
            'stderr': '\n'.join(output),
            'rc': rc,
            'failed': not rc == 0
        }
    
    def make_temp_dir(self, name):
        dname = '%s/%s' % ( self.build_directory, name )
        os.makedirs(dname, exist_ok=True)
        return os.path.abspath(dname)
    
    def recursive_copy(self, src_dir, dest_dir):
        os.makedirs(dest_dir, exist_ok=True)
        self.run_command([ 'rsync', '-a', src_dir + '/', dest_dir ])
    
    def set_log_file(self, log_filename):
        # TODO: open the log lazily
        # TODO: propagate the information to XML report
        self.log = self.open_downloadable_file('logs/' + log_filename, 'w')
    
    def append_line_to_log_file(self, line):
        if not self.log is None:
            self.log.write(line + '\n')
        self.log_tail.append(line)
        self.log_tail = self.log_tail[-10:]
    
    def get_artefact_absolute_path(self, relative_name, create_dirs=False):
        base = os.path.dirname(relative_name)
        name = os.path.basename(relative_name)
        dname = '%s/%s/' % ( self.artefact_directory, base )
        
        if create_dirs:
            os.makedirs(dname, exist_ok=True)
        
        return os.path.abspath(dname + name)

    # TODO: propagate title + download_name to the report
    def add_downloadable_file(self, title, download_name, current_filename):
        self.dprint("Downloadable `%s' at %s", title, download_name)
        self.files.append({
            'filename' : download_name,
            'title' : title
        })
        
        target = self.get_artefact_absolute_path(download_name, True)
        shutil.copy(current_filename, target)
    
    def open_downloadable_file(self, download_name, mode):
        return open(self.get_artefact_absolute_path(download_name, True), mode)
    
    def done(self):
        if not self.log is None:
            self.log.close()

    def get_files(self):
        return self.files

    def ret(self, *args, **kwargs):
        status = 'ok'
        if len(args) == 1:
            status = args[0]
            if status == True:
                status = 'ok'
            elif status == False:
                status = 'fail'
        result = {
            'status': status,
            'data': {}
        }
        
        for k in kwargs:
            result['data'][k] = kwargs[k]
        
        return result



class TaskWrapper:
    def __init__(self, id, task, description, deps, mutexes):
        self.id = id
        self.dependencies = deps
        self.description = description
        self.task = task
        self.status = 'n/a'
        self.completed = False
        self.data = {}
        self.lock = Lock()
        self.mutexes = mutexes
    
    def has_completed_okay(self):
        with self.lock:
            return self.completed and (self.status == 'ok')
    
    def has_finished(self):
        with self.lock:
            return self.completed
    
    def get_status(self):
        with self.lock:
            return self.status
    
    def get_data(self):
        with self.lock:
            return self.data
    
    def set_status(self, status, reason):
        with self.lock:
            self.status = status
            self.reason = reason
    
    def set_done(self, data):
        with self.lock:
            self.data = data
            self.completed = True
    
    def set_skipped(self, reason):
        self.set_status('skip', reason)


class BuildScheduler:
    def __init__(self, max_workers, build, artefact, build_id, debug = False):
        self.config = {
            'build-directory': build,
            'artefact-directory': artefact,
        }
        
        self.start_timestamp = time.time()
        self.start_date = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).astimezone().isoformat(' ')

        # Parent task controller
        self.ctl = TaskController('scheduler', {}, build, artefact, debug)

        # Start the log file
        self.report_file = self.ctl.open_downloadable_file('report.xml', 'w')
        self.report_file.write("<?xml version=\"1.0\"?>\n")
        self.report_file.write("<build number=\"%s\">\n" % build_id)

        # The following attributes (up to self.guard declaration) are guarded
        # by the self.guard mutex and use self.cond to notify about changes
        # in any of them.
        # Lower granularity of the locking would be possible but would
        # complicate too much the conditions inside queue processing where we
        # need to react to multiple events (new task added vs some task
        # terminated vs selecting the right task to be executed).

        # Known tasks (regardless of their state). The mapping is between
        # a task id and TaskWrapper class.
        self.tasks = {}

        # Queue of tasks not yet run (uses task ids only). We insert mutex
        # tasks at queue beginning (instead of appending) as a heuristic to
        # prevent accumulation of mutex tasks at the end of run where it could
        # hurt concurrent execution.
        self.queue = []

        # Number of currently running (executing) tasks. Used solely to
        # control number of concurrently running tasks.
        self.running_tasks_count = 0

        # Flag for the queue processing whether to terminate the loop to allow
        # clean termination of the executor.
        self.terminate = False

        # Here we record which mutexes are held by executing tasks. Mutexes are
        # identified by their (string) name that is used as index. When the
        # value is True, the mutex is held (i.e. do not run any other task
        # claming the same mutex), mutex is not held when the value is False
        # or when the key is not present at all.
        self.task_mutexes = {}

        # Condition variable guarding the above attributes.
        # We initialize CV only without attaching a lock as it creates one
        # automatically and CV serves as a lock too.
        #
        # Always use notify_all as we are waiting in multiple functions
        # for it (e.g. while processing the queue or in barrier).
        self.guard = Condition()

        # Lock guarding output synchronization
        self.output_lock = Lock()
        
        # Executor for running of individual tasks
        from concurrent.futures import ThreadPoolExecutor
        self.max_workers = max_workers
        self.executor = ThreadPoolExecutor(max_workers=max_workers + 2)

        # Start the queue processor
        self.executor.submit(BuildScheduler.process_queue_wrapper, self)

    def process_queue_wrapper(self):
        """
        To allow debugging of the queue processor.
        """
        try:
            self.process_queue()
        except:
            import traceback
            traceback.print_exc()

    def submit(self, description, task_id, task, deps = [], mutexes = []):
        with self.guard:
            #print("Submitting {} ({}, {}, {})".format(description, task_id, deps, mutexes))
            # Check that dependencies are known
            for d in deps:
                if not d in self.tasks:
                    raise Exception('Dependency %s is not known.' % d)
            # Add the wrapper
            wrapper = TaskWrapper(task_id, task, description, deps, mutexes)
            self.tasks[task_id] = wrapper

            # Append to the queue
            # We use a simple heuristic: if the task has no mutexes, we
            # append to the end of the queue. Otherwise we prioritize the
            # task a little bit to prevent ending with serialized execution
            # of the mutually excluded tasks. (We add before first non-mutexed
            # task.)
            if len(mutexes) > 0:
                new_queue = []
                inserted = False
                for q in self.queue:
                    if (len(self.tasks[q].mutexes) == 0) and (not inserted):
                        new_queue.append(task_id)
                        inserted = True
                    new_queue.append(q)
                if not inserted:
                    new_queue.append(task_id)
                self.queue = new_queue
            else:
                self.queue.append(task_id)
            
            self.guard.notify_all()
    
    def task_run_wrapper(self, wrapper, task_id, can_be_run):
        try:
            self.task_run_inner(wrapper, task_id, can_be_run)
        except:
            import traceback
            traceback.print_exc()
    
    def xml_escape_line(self, s):
        from xml.sax.saxutils import escape
        import re
        
        s_without_ctrl = re.sub(r'[\x00-\x08\x0A-\x1F]', '', s)
        s_escaped = escape(s_without_ctrl)
        s_all_entities_encoded = s_escaped.encode('ascii', 'xmlcharrefreplace')
        
        return s_all_entities_encoded.decode('utf8')
    
    def task_run_inner(self, wrapper, task_id, can_be_run):
        data = {}
        
        if can_be_run:
            for task_dep_id in wrapper.dependencies:
                task_dep = self.tasks[task_dep_id]
                data[task_dep_id] = task_dep.get_data()
        
        wrapper.task.ctl = self.ctl.derive(task_id, data)
        wrapper.task.ctl.set_log_file('%s.log' % task_id)
        
        if can_be_run:
            self.announce_task_started_(wrapper)
            
            try:
                res = wrapper.task.execute()
                if (res == True) or (res is None):
                    res = {
                        'status': 'ok',
                        'data': {}
                    }
                elif res == False:
                    res = {
                        'status': 'fail',
                        'data': {}
                    }
                reason = None
            except Exception as e:
                import traceback
                res = {
                    'status': 'fail',
                    'data': {}
                }
                #traceback.print_exc()
                reason = '%s' % e
        else:
            for task_dep_id in wrapper.dependencies:
                task_dep = self.tasks[task_dep_id]
                if task_dep.has_finished() and (not task_dep.has_completed_okay()):
                    reason = 'dependency %s failed (or also skipped).' % task_dep_id
            res = {
                'status': 'skip',
                'data': {}
            }
            wrapper.task.ctl.append_line_to_log_file('Skipped: %s' % reason)

        status = res['status']
        report = wrapper.task.get_report()

        if (not report['name'] is None) and (not self.report_file is None):
            report_xml = '<' + report['name']
            report['attrs']['result'] = status
            for key in report['attrs']:
                report_xml = report_xml + ' %s="%s"' % (key, report['attrs'][key] )
            report_xml = report_xml + ' log="logs/%s.log"' % wrapper.id
            report_xml = report_xml + ">\n"
            
            if 'files' in report:
                for f in report['files']:
                    file = '<file title="%s" filename="%s" />\n' % ( f['title'], f['filename'])
                    report_xml = report_xml + file
            
            if (not wrapper.task.ctl is None) and (len(wrapper.task.ctl.log_tail) > 0):
                report_xml = report_xml + ' <log>\n'
                for line in wrapper.task.ctl.log_tail:
                    report_xml = report_xml + '  <logline>' + self.xml_escape_line(line) + '</logline>\n'
                report_xml = report_xml + ' </log>\n'
            
            report_xml = report_xml + '</' + report['name'] + ">\n"
            
             
            self.report_file.write(report_xml)
        
        wrapper.set_status(status, reason)
        self.announce_task_finished_(wrapper)
        wrapper.set_done(res['data'])
        
        with self.guard:
            self.running_tasks_count = self.running_tasks_count - 1
            
            if can_be_run:
                for m in wrapper.mutexes:
                    self.task_mutexes [ m ] = False
        
            #print("Task finished, waking up (running now {})".format(self.running_tasks_count))
            self.guard.notify_all()

    
    def process_queue(self):
        while True:
            with self.guard:
                #print("Process queue running, tasks {}".format(len(self.queue)))
                # Break inside the loop
                while True:
                    slot_available = self.running_tasks_count < self.max_workers
                    task_available = len(self.queue) > 0
                    #print("Queue: {} (running {})".format(len(self.queue), self.running_tasks_count))
                    if slot_available and task_available:
                        break
                    if self.terminate and (not task_available):
                        return
                    
                    #print("Queue waiting for free slots (running {}) or tasks (have {})".format(self.running_tasks_count, len(self.queue)))
                    self.guard.wait()
                    #print("Guard woken-up after waiting for free slots.")

                # We have some tasks in the queue and we can run at
                # least one of them
                ( ready_task_id, can_be_run )  = self.get_first_ready_task_id_()
                #print("Ready task is {}".format(ready_task_id))
                
                if ready_task_id is None:
                    #print("Queue waiting for new tasks to appear (have {})".format(len(self.queue)))
                    self.guard.wait()
                    #print("Guard woken-up after no ready task.")
                else:
                    # Remove the task from the queue
                    self.queue.remove(ready_task_id)
                    
                    ready_task = self.tasks[ready_task_id]
                    
                    # Need to update number of running tasks here and now
                    # because the executor might start the execution later
                    # and we would evaluate incorrectly the condition above
                    # that we can start another task.
                    self.running_tasks_count = self.running_tasks_count + 1
                    
                    #print("Ready is {}".format(ready_task))
                    if can_be_run:
                        for m in ready_task.mutexes:
                            self.task_mutexes [ m ] = True
                    #print("Actually starting task {}".format(ready_task_id))
                    self.executor.submit(BuildScheduler.task_run_wrapper,
                        self, ready_task, ready_task_id, can_be_run)

    def get_first_ready_task_id_(self):
        """
        Return tuple of first task that can be run (or failed immediately)
        with note whether the result is predetermined.
        Returns None when no task can be run.
        """
        # We assume self.guard was already acquired
        # We use here the for ... else construct of Python (recall that else
        # is taken when break is not used)
        for task_id in self.queue:
            task = self.tasks[task_id]
            for task_dep_id in task.dependencies:
                task_dep = self.tasks[ task_dep_id ]
                if not task_dep.has_finished():
                    break
                # Failed dependency means we can return now
                if task_dep.get_status() != 'ok':
                    return ( task_id, False )
            else:
                for task_mutex in task.mutexes:
                    if (task_mutex in self.task_mutexes) and self.task_mutexes[ task_mutex ]:
                        break
                else:
                    return ( task_id, True )
        return ( None, None )


    def announce_task_started_(self, task):
        with self.output_lock:
            print(colorama.Style.RESET_ALL + "       " + task.description + " ...", flush=True)
            sys.stdout.flush()
    
    def announce_task_finished_(self, task):
        description = task.description
        if task.status == 'ok':
            msg = 'done'
            msg_color = colorama.Fore.GREEN
            description = description + '.'
        elif task.status == 'skip':
            msg = 'skip'
            msg_color = colorama.Fore.CYAN
            description = description + ': ' + task.reason
        else:
            msg = 'fail'
            msg_color = colorama.Fore.RED
            description = description + ': ' + task.reason

        with self.output_lock:
            print(colorama.Style.RESET_ALL + "[" + msg_color + msg + colorama.Style.RESET_ALL + "] " + description, flush=True)
            sys.stdout.flush()


    def barrier(self):
        with self.guard:
            #print("Barrier ({}, {})...".format(self.running_tasks_count, len(self.queue)))
            while (self.running_tasks_count > 0) or (len(self.queue) > 0):
                #print("Barrier waiting ({}, {})...".format(self.running_tasks_count, len(self.queue)))
                self.guard.wait()
    
    def done(self):
        with self.guard:
            self.terminate = True
            self.guard.notify_all()
        self.barrier()
        self.close_report()
        self.executor.shutdown(True)
    
    def close_report(self):
        if not self.report_file is None:
            end_time = time.time()
            self.report_file.write("<buildinfo started=\"{}\" duration=\"{}\" parallelism=\"{}\" />\n".format(
                self.start_date, ( end_time - self.start_timestamp ) * 1000,
                self.max_workers
            ))
            self.report_file.write("</build>\n")
            self.report_file.close()
            self.report_file = None

