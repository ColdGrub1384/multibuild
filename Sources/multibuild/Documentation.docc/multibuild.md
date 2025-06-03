# ``multibuild``

`multibuild` is a Swift build system for compiling to multiple architectures and sdks supporting multiple build backends.

This library only supports Apple platform for the moment and not all but it will later. My goal while writting this was to provide a declarative way of compiling open source dependencies similar to SPM manifests and to provide tools for managing several targets.

## Topics

### Types

- ``Build``
- ``BuildBackend``
- ``Framework``
- ``Product``
- ``Platform``
- ``Project``
- ``Target``

### Build systems

- ``Autoconf``
- ``CMake``
- ``Python``