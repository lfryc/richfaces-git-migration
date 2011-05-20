#!/bin/bash
#shopt -s expand_aliases
alias xmled='xmlstarlet edit -N m="http://maven.apache.org/POM/4.0.0"'
alias xmlsel='xmlstarlet sel -N m="http://maven.apache.org/POM/4.0.0"'

ls -a1 | egrep -v '^(\.|\.\.|pom\.xml|bom|dist|parent|\.git)$' | xargs rm -rf

rename_module() {
        MODULE=$1
        echo $MODULE \
                | sed -r 's#^(parent|bom|dist)?(.*)$#\1../\2#' \
                | sed -r 's#\.\./$##' \
                | sed -r 's#^../build/#../#' \
                | sed -r 's#faces-shade-transformers#shade-transformers#' \
                | sed -r 's#ui$#components#'
}

if [ -f pom.xml ]; then
	cat pom.xml \
		| xmled --subnode '/m:project/m:profiles' -t elem -n profile -v '' \
		| xmled --subnode '/m:project/m:profiles/m:profile[last()]' -t elem -n id -v build \
		| xmled --move '/m:project/m:modules' '/m:project/m:profiles/m:profile[last()]' \
		| xmled --move '/m:project/m:profiles/m:profile[position() < last()]' '/m:project/m:profiles' \
		| xmled --subnode "/m:project/m:profiles/m:profile/m:id[text()='build']/../m:modules" -t elem -n module -v 'showcase' \
		| xmled --update "/m:project/m:parent/m:relativePath" -v '../parent/pom.xml' \
		| xmled --update "/m:project/m:scm/m:connection" -v '/home/lfryc/workspaces/migration/bare/build' \
		| xmled --update "/m:project/m:scm/m:developerConnection" -v '/home/lfryc/workspaces/migration/bare/build' \
		> pom.xml.1

	cat pom.xml.1 \
		| sed -r 's#<!--<module>docs</module>-->##' \
		| sed -r 's#<!-- richfaces ui -->##' \
		| sed -r 's#<!-- Remaining -->##' \
		> pom.xml.2
	cat pom.xml.2 >pom.xml.1

	for MODULE in `cat pom.xml.1 | xmlsel -t -m '/m:project/m:profiles/m:profile' -m 'm:modules/m:module' -v '.' -n`; do
		NEW_NAME=`rename_module $MODULE`
		cat pom.xml.1 | xmled --update "/m:project/m:profiles/m:profile/m:modules/m:module[text()='$MODULE']" -v "$NEW_NAME" >pom.xml.2
		cat pom.xml.2 >pom.xml.1
	done
	
	cat pom.xml.1 >pom.xml

	rm pom.xml.1 pom.xml.2
fi
