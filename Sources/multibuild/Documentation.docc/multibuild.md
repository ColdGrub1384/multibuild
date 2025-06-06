# ``multibuild``

`multibuild` is a Swift build system for compiling to multiple architectures and sdks supporting multiple build backends.

This library only supports Apple platform for the moment and not all but it will later. My goal while writting this was to provide a declarative way of compiling open source dependencies similar to SPM manifests and to provide tools for managing several targets.

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
- ``Autoconf``
- ``CMake``
- ``Python``
