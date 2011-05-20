#!/bin/bash
cat >.gitignore <<END
target
test-output
.classpath
.settings
.project
.clover
.externalToolBuilders
END
