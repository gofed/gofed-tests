# gofed-tests

With every update of a golang project in my ecosystem, I would like to know if my project still passes all tests and does not break any other project.

I would like to know if my project the way it is packaged can be build on all supported distributions and architectures.

As my ecosystem can be quite huge and contain hundreds of golang projects it gives me an oportunity to run various tests like:
- with each update of golang compiler I would like to know if the update does not introduces any regressions
- with each update of golang compiler I would like to know if the compiler's new features (or backports) works better or at least the same as so far
- with new architectures or new compiler I would like to know if all tests are passing and if not find out why (and report bugs/issue on the compiler)

For some projects I would like to run additional tests to:
- measure performance
- to tests my changes in API or backported features
- ...

This repository is for collection various tests suites, settings and configurations that can be installed and run in CI job or other environment to be able to run it without additional configuration.
