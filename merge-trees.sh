#!/bin/bash

PROJECT1=$1
PROJECT2=$2
NEW_PROJECT=$3

BRANCH1=$4
BRANCH2=$5
NEW_BRANCH=$6

FORMAT_PATCH_OPTIONS=""
AM_OPTION="--ignore-white-space"

fromdos="fromdos -a -d"

pushd $PROJECT1 >/dev/null
	git reset --hard HEAD >/dev/null
	git checkout $BRANCH1
	git reset --hard HEAD >/dev/null
popd >/dev/null

pushd $PROJECT2 >/dev/null
	git reset --hard HEAD >/dev/null
	git checkout $BRANCH2
	git reset --hard HEAD >/dev/null
popd >/dev/null

mkdir -p $NEW_PROJECT
pushd $NEW_PROJECT >/dev/null
	if [ ! -d "$NEW_PROJECT/.git" ]; then
		git init >/dev/null
	else
		echo ref: refs/heads/$NEW_BRANCH >.git/HEAD
		ls -a1 | egrep -v '^(\.|\.\.|\.git)$' | xargs rm -rf
	fi
popd >/dev/null

remove_carriage_returns() {
	for FILE in `git ls-files`; do
		$fromdos $FILE
	done
}

pushd $PROJECT1 >/dev/null
	for GIT_COMMIT in `{ echo "after"; git log --pretty='format:%H'; } | cat -n | sort -nr | awk '{print $2}'`; do
		if [ "$GIT_COMMIT" = "after" ]; then
			ANCESTORS=1
		else
			ANCESTORS=`git log -2 --pretty='format:%H' $GIT_COMMIT | wc -l`
		fi
		if [ "$ANCESTORS" -eq 0 ]; then
			git archive $GIT_COMMIT | tar -x -C $NEW_PROJECT/
			TAG_TIME=`git log $GIT_COMMIT -1 --date=raw | grep '^Date:' | awk '{ print $2; }'`
			TAG_MESSAGE_FILE=/tmp/tag-message-$$
			git log $GIT_COMMIT -1 --pretty='format:%s' >$TAG_MESSAGE_FILE
			tag_name=` git log $GIT_COMMIT -1 --pretty="format:%an"`
			tag_email=`git log $GIT_COMMIT -1 --pretty="format:%ae"`
			tag_date=`git log $GIT_COMMIT -1 --pretty="format:%ai"`
			pushd $NEW_PROJECT >/dev/null
				git add -A
				remove_carriage_returns
				git add -A
				git commit -F $TAG_MESSAGE_FILE
				git filter-branch -f --commit-filter '
					if [ "$GIT_AUTHOR_EMAIL" = "lfryc@redhat.com" ];
					then
						GIT_AUTHOR_NAME="'"$tag_name"'";
						GIT_AUTHOR_EMAIL="'"$tag_email"'";
						GIT_AUTHOR_DATE="'"$tag_date"'";
						git commit-tree "$@";
					else
						git commit-tree "$@";
					fi' HEAD
			popd >/dev/null
		else
			if [ "$GIT_COMMIT" != "after" ]; then	
				PREVIOUS_COMMIT="$GIT_COMMIT^1"
				PREVIOUS_TIME=`git log $PREVIOUS_COMMIT -1 --date=raw | grep '^Date:' | awk '{print $2; }'`
				COMMIT_TIME=`git log $GIT_COMMIT -1 --date=raw | grep '^Date:' | awk '{print $2; }'`
			fi
			pushd $PROJECT2 >/dev/null
				if [ "$GIT_COMMIT" != "after" ]; then	
					INTRODUCE_COMMITS=`git log --after=$PREVIOUS_TIME --before=$COMMIT_TIME --pretty='format:%H' | cat -n | sort -nr | awk '{print $2}'`
				else
					INTRODUCE_COMMITS=`git log --after=$COMMIT_TIME --pretty='format:%H' | cat -n | sort -nr | awk '{print $2}'`
				fi
				if [ -n "$INTRODUCE_COMMITS" ]; then
					for INTRODUCE_COMMIT in $INTRODUCE_COMMITS; do
							ANCESTORS=`git log -2 --pretty='format:%H' $INTRODUCE_COMMIT | wc -l`
							if [ "$ANCESTORS" -eq 0 ]; then
								git archive $INTRODUCE_COMMIT | tar -x -C $NEW_PROJECT/
								TAG_TIME=`git log $INTRODUCE_COMMIT -1 --date=raw | grep '^Date:' | awk '{ print $2; }'`
								TAG_MESSAGE_FILE=/tmp/tag-message-$$
								git log $INTRODUCE_COMMIT -1 --pretty='format:%s' >$TAG_MESSAGE_FILE
								tag_name=` git log $INTRODUCE_COMMIT -1 --pretty="format:%an"`
								tag_email=`git log $INTRODUCE_COMMIT -1 --pretty="format:%ae"`
								tag_date=`git log $INTRODUCE_COMMIT -1 --pretty="format:%ai"`
								pushd $NEW_PROJECT >/dev/null
									git add -A
									remove_carriage_returns
									git add -A
									git commit -F $TAG_MESSAGE_FILE
									git filter-branch -f --commit-filter '
										if [ "$GIT_AUTHOR_EMAIL" = "lfryc@redhat.com" ];
										then
											GIT_AUTHOR_NAME="'"$tag_name"'";
											GIT_AUTHOR_EMAIL="'"$tag_email"'";
											GIT_AUTHOR_DATE="'"$tag_date"'";
											git commit-tree "$@";
										else
											git commit-tree "$@";
										fi' HEAD
								popd >/dev/null
							else
								git format-patch $FORMAT_PATCH_OPTIONS --stdout $INTRODUCE_COMMIT^1..$INTRODUCE_COMMIT >/tmp/patch
								pushd $NEW_PROJECT >/dev/null
									$fromdos /tmp/patch
									git am $AM_OPTIONS /tmp/patch  || exit 1
								popd >/dev/null
							fi
					done
				fi
			popd >/dev/null
			if [ "$GIT_COMMIT" != "after" ]; then	
				git format-patch $FORMAT_PATCH_OPTIONS --stdout $GIT_COMMIT^1..$GIT_COMMIT >/tmp/patch
				pushd $NEW_PROJECT >/dev/null
					$fromdos /tmp/patch
					git am $AM_OPTIONS /tmp/patch  || exit 1
				popd >/dev/null
			fi
		fi
	done
popd >/dev/null

pushd $NEW_PROJECT >/dev/null
	git filter-branch -f --commit-filter '
			GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME";
			GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL";
			GIT_COMMITTER_DATE="$GIT_AUTHOR_DATE";
			git commit-tree "$@";
		' HEAD
popd
