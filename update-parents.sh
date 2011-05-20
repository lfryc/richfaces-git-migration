#!/bin/bash
alias xmled='xmlstarlet edit -N m="http://maven.apache.org/POM/4.0.0"'
alias xmlsel='xmlstarlet sel -N m="http://maven.apache.org/POM/4.0.0"'

updateRelativePath() {
	POM=$1
	PARENT_ARTIFACT=`xmlsel -t -v '/m:project/m:parent/m:artifactId' $POM`
	case "$PARENT_ARTIFACT" in
		"richfaces-root-parent")
			sed -ri 's#(<relativePath>.*)/parent/#\1/build/parent/#' $POM
			;;
		"richfaces-parent")
			sed -ri 's#(<relativePath>.*)/build/parent/#\1/parent/#' $POM
			;;
	esac
}

for POM in `find -maxdepth 4 -name "pom.xml" `; do
	updateRelativePath "$POM"
done

cat >.gitignore <<END
target
test-output
.classpath
.settings
.project
.clover
.externalToolBuilders
END
