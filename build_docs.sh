#!/bin/bash

swift package --allow-writing-to-directory ./docs generate-documentation --symbol-graph-minimum-access-level public --transform-for-static-hosting --hosting-base-path emma/cosas/documentaciones/multibuild --output-path ./docs/multibuild
