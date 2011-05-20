#!/bin/bash
rm -rf checkstyle faces-shade-transformers

cat >.gitignore <<END
target
test-output
.classpath
.settings
.project
.clover
.externalToolBuilders
END
