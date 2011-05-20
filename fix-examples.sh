#!/bin/bash

# Removing richfaces-showcase (as it is in separated repository)
# Removing empty directory dist
rm -rf richfaces-showcase dist

# remove module dist
sed -ri 's#<module>richfaces-showcase</module>##' pom.xml

