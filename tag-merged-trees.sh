#!/bin/bash

PROJECT=$1
NEW_PROJECT=$2

date2stamp () {
	date --utc --date="$1" "+%s"
}

stamp2date (){
	date --utc --date "1970-01-01 $1 sec" "+%Y-%m-%d %T"
}


pushd $PROJECT >/dev/null
	for TAG in `git tag -l`; do
		TAG_TIME=`git log tags/$TAG -1 --date=raw | grep '^Date:' | awk '{ print $2; }'`
		TAG_REF=`git log tags/$TAG -1 | grep '^commit' | awk '{ print $2; }'`
		TAG_BRANCH=`git branch --contains $TAG_REF | sed -r 's/^.{2}//' | sort -n | head -n 1`
		TAG_MESSAGE_FILE=/tmp/tag-message-$$
                git log tags/$TAG -1 --pretty='format:%s' >$TAG_MESSAGE_FILE
                tag_name=` git log tags/$TAG -1 --pretty="format:%an"`
                tag_email=`git log tags/$TAG -1 --pretty="format:%ae"`
                tag_date=`git log tags/$TAG -1 --pretty="format:%ai"`
		pushd $NEW_PROJECT >/dev/null
			git checkout $TAG_BRANCH &>/dev/null
			TAG_TARGET=`git log --date=raw | grep -B 2 $TAG_TIME | head -n 1 | awk '{ print $2; }'`
			GIT_COMMITTER_NAME="$tag_name" GIT_COMMITTER_EMAIL="$tag_email" GIT_COMMITTER_DATE="$tag_date" git tag -a -F $TAG_MESSAGE_FILE $TAG $TAG_TARGET
		popd >/dev/null
		rm $TAG_MESSAGE_FILE
	done
popd >/dev/null
