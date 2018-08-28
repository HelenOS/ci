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
