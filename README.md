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

See scripts in `scenarios/` directory for examples or the `test-in-vm.sh`
script to learn about internals.


Simple test running malloc and checking its output looks like this:

```
xx_start_machine
xx_cmd "tester malloc1" assert="Test passed" timeout=120 die_on="demo"
xx_stop_machine
```


Test checking that we are able to launch gcc (needs special image):

```
# @needs gcc
xx_start_machine
xx_cmd "gcc" assert="no input files" timeout=20
xx_stop_machine
```
