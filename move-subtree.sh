#!/bin/bash

SUBTREE=$1
NEW_PROJECT=$2
CURRENT_PROJECT=$PWD
PROCESSORS=$3

mkdir -p $NEW_PROJECT
pushd $NEW_PROJECT
	git init
popd

if [ -n "$SUBTREE" ]; then
	for BRANCH in `git branch -r`; do
		echo "############################################################"
		echo "## Moving branch '$BRANCH' from subtree '$SUBTREE'"
		echo "############################################################"
		{ git branch | grep "^\s*$SUBTREE-local-$BRANCH$"; } && git branch -D $SUBTREE-local-$BRANCH
		{ git branch | grep "^\s*$SUBTREE-checkout-$BRANCH$"; } && git branch -D $SUBTREE-checkout-$BRANCH
		{ git branch | grep "^\s*$SUBTREE-export-$BRANCH$"; } && git branch -D $SUBTREE-export-$BRANCH
		git reset --hard HEAD
		git checkout -b $SUBTREE-local-$BRANCH remotes/$BRANCH
		if [ -d "$SUBTREE" ]; then
			git subtree split -P $SUBTREE -b $SUBTREE-export-$BRANCH
			pushd $NEW_PROJECT
				git fetch $CURRENT_PROJECT $SUBTREE-export-$BRANCH
				git checkout -b $BRANCH FETCH_HEAD
			popd
		fi
		git reset --hard HEAD
		git checkout master
		{ git branch | grep "^\s*$SUBTREE-local-$BRANCH$"; } && git branch -D $SUBTREE-local-$BRANCH
		{ git branch | grep "^\s*$SUBTREE-checkout-$BRANCH$"; } && git branch -D $SUBTREE-checkout-$BRANCH
		{ git branch | grep "^\s*$SUBTREE-export-$BRANCH$"; } && git branch -D $SUBTREE-export-$BRANCH
	done
else
	for BRANCH in `git branch -r`; do
		echo "############################################################"
		echo "## Moving branch '$BRANCH' from subtree '$SUBTREE'"
		echo "############################################################"
		{ git branch | grep "^\s*local-$BRANCH$"; } && git branch -D local-$BRANCH
		git checkout -b local-$BRANCH remotes/$BRANCH
		pushd $NEW_PROJECT
			git fetch $CURRENT_PROJECT local-$BRANCH
			git checkout -b $BRANCH FETCH_HEAD
		popd
		{ git branch | grep "^\s*local-$BRANCH$"; } && git branch -D local-$BRANCH
	done
fi

for PROCESSOR in $PROCESSORS; do
	if [ -n "$PROCESSOR" -a -f "$PROCESSOR" ]; then
		pushd $NEW_PROJECT
			for BRANCH in `git branch -l | sed -r 's/^.{2}//'`; do
				echo "############################################################"
				echo "## Processing script '$PROCESSOR' on branch '$BRANCH' from subtree '$SUBTREE'"
				echo "############################################################"
				git filter-branch --force --prune-empty --tree-filter ". $PROCESSOR" $BRANCH
			done
		popd
	fi
done

for TAG in `git tag -l`; do
	echo "##################################################"
	echo "## Tagging '$TAG' from subtree '$SUBTREE'"
	echo "##################################################"
	if [ -d "$SUBTREE" -o -z "$SUBTREE" ]; then
		TAG_TIME=`git log tags/$TAG -1 --date=raw | grep '^Date:' | awk '{print $2; }'`
		TAG_REF=`git log tags/$TAG -1 | grep '^commit' | awk '{ print $2; }'`
		TAG_BRANCH=`git branch -r --contains $TAG_REF`
		TAG_MESSAGE_FILE=/tmp/move-subtree-tag-message-$$
		git log tags/$TAG -1 --pretty='format:%s' >$TAG_MESSAGE_FILE
		tag_name=$( git log tags/$TAG -1 --pretty="format:%an" )
		tag_email=$( git log tags/$TAG -1 --pretty="format:%ae" )
		tag_date=$( git log tags/$TAG -1 --pretty="format:%ai" )
		pushd $NEW_PROJECT
			TAG_TARGET=`git log $TAG_BRANCH -1 --until=$TAG_TIME | grep '^commit' | awk '{ print $2; }'`
			GIT_COMMITTER_NAME="$tag_name" GIT_COMMITTER_EMAIL="$tag_email" GIT_COMMITTER_DATE="$tag_date" git tag -a -F $TAG_MESSAGE_FILE $TAG $TAG_TARGET
		popd
		rm $TAG_MESSAGE_FILE
	fi
done

echo "##################################################"
echo "## Moving trunk to master on subtree '$SUBTREE'"
echo "##################################################"
pushd $NEW_PROJECT
	git branch -m trunk master
popd
