HelenOS Continuous Integration Testing Scripts
==============================================

The purpose of this repository is to have a universal script for building
and testing (almost) everything related to HelenOS. Currently, the script
is able to:

 * fetch latest versions of HelenOS and harbours (ported software)
 * build HelenOS for all supported architectures
 * build all harbours (the full matrix)
 * run automated tests in QEMU (selected platforms only)

See http://www.helenos.org/wiki/CI for more information. Nightly builds
using this tool are pushed to http://ci.helenos.org/.

**Note:** this tool is not meant to be used for normal development of
HelenOS (i.e. the "edit - incrementally compile - test" loop) but rather
for pre-merge tests or automated nightly builds.


Running
-------

```shell
# Fetch default branches and build everything.
./build.py

# Limit paralellism
./build.py --jobs 3

# Fetch from non-default branches
./build.py --helenos-repository git@github.com:login/helenos.git
```

Tests
-----

The tests are executed in QEMU and it is possible to type text
into console and assert for command output.

See scripts in `scenarios/` directory for examples or the `test-in-vm.py`
script to learn about internals.

```text
usage: test-in-vm.py [-h] [--headless] [--scenario FILENAME.yml] --arch
                     ARCHITECTURE [--memory MB] --image FILENAME
                     [--pass OPTION] [--vterm-dump FILENAME.txt]
                     [--last-screenshot FILENAME.png] [--debug]

Testing of HelenOS in VM

optional arguments:
  -h, --help            show this help message and exit
  --headless            Do not show any VM windows.
  --scenario FILENAME.yml
                        Scenario file
  --arch ARCHITECTURE   Emulated architecture identification.
  --memory MB           Amount of memory for the virtual machine.
  --image FILENAME      HelenOS boot image (e.g. ISO file).
  --pass OPTION         Extra options to pass through to the emulator
  --vterm-dump FILENAME.txt
                        Where to store full vterm dump.
  --last-screenshot FILENAME.png
                        Where to store last screenshot.
  --debug               Print debugging messages

Typical invocation will use the following arguments:
  --image helenos.iso
  --scenario scenario.yml
  --arch amd64               # ia32, ppc32 etc.
  --vterm-dump dump.txt      # all text from main vterm
  --last-screenshot shot.png # last VM screen
```

Simple test running malloc and checking its output looks like this:

```yml
meta:
  name: "tester malloc"
  harbours: []

tasks:
  - boot
  - command:
      args: "tester malloc1"
      assert:  "Test passed"
      negassert: "Test failed"
```


Test checking that we are able to launch GCC (needs special image):

```yml
meta:
  name: "gcc --version"
  harbours:
     - gcc

tasks:
  - boot
  - command:
      args: "gcc --version"
      assert:  "GCC"
```
