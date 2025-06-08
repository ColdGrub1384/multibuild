# ``multibuild``

A Swift build system for compiling to multiple architectures and sdks supporting multiple build backends.

This library provides types that define projects, configurations and also a command line interface to trigger builds.
It only supports Apple platforms for the moment and not all because that's what I'm testing against currently but I plan to add support for at least Linux / Android.

See <doc:getting-started>.

## Topics

### Configuring a project

- ``Build``
- ``Framework``
- ``Product``
- ``Platform``
- ``Project``
- ``Target``

### Command line interface

- ``BuildCommand``
- ``BuildPlan``
- ``PlanBuilder``

### Build backend systems

- ``BuildBackend``
- ``TargetConditionalBackend``

- ``Autoconf``
- ``CMake``
- ``Python``
- ``Xcode``