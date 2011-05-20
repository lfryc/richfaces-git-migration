#!/bin/bash

GIT_REPO=$1
SVN_REPO=$2
START_REV=$3

IGNORE_PATHS="^(?:3.*|archive|tests)"

if [ -z "$START_REV" -o -z "$SVN_REPO" -o -z "$GIT_REPO" ]; then
	echo "Syntax: $0 [GIT_REPO] [SVN_REPO] [START_REV]"
	echo "Optional EVN variables: SVN_AUTHORS, SVN_TAGS, SVN_BRANCHES"
	exit
fi

mkdir -p $GIT_REPO

pushd $GIT_REPO

	git svn init $SVN_REPO --no-metadata --no-minimize-url --trunk=trunk --tags=tags --branches=branches

	if [ -n "$SVN_AUTHORS" ]; then
		git config svn.authorsfile $SVN_AUTHORS
	fi

	if [ -n "$SVN_TAGS" ]; then
		sed -ri 's#^(\s*tags = ).*$#\1tags/{'$SVN_TAGS'}:refs/remotes/tags/*#' .git/config 
	fi

	if [ -n "$SVN_BRANCHES" ]; then
		sed -ri 's#^(\s*branches = ).*$#\1branches/{'$SVN_BRANCHES'}:refs/remotes/*#' .git/config
	fi
	
	git svn fetch --revision=$START_REV:HEAD --log-window-size=1000 --ignore-paths=$IGNORE_PATHS
popd
