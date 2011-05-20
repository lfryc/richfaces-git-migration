#!/bin/bash

# add dependency on core-impl
sed -ri 's#^    <dependencies>#    <dependencies>\n        <dependency>\n            <groupId>org.richfaces.core</groupId>\n             <artifactId>richfaces-core-impl</artifactId>\n        </dependency>#' pom.xml

# update parent
sed -ri 's#^        <groupId>org.richfaces.examples</groupId>#        <groupId>org.richfaces</groupId>#' pom.xml
sed -ri 's#^        <artifactId>richfaces-example-parent</artifactId>#        <artifactId>richfaces-root-parent</artifactId>#' pom.xml
sed -ri 's#^        <relativePath>../parent/pom.xml</relativePath>#        <relativePath>../build/parent/pom.xml</relativePath>#' pom.xml
