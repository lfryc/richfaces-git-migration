#!/bin/bash

rf2git_setup() {
	if [ -z "$1" ]; then
		echo "Syntax: rf2git_setup workdir"
	else 
		export SCRIPTS=`dirname $(readlink -f $0)`
		export WORKDIR=`readlink -f $1`
		export FETCH=$WORKDIR/fetch
		export CLEANUP=$WORKDIR/cleanup
		export EXPORT=$WORKDIR/export
		export SVN_ROOT=https://svn.jboss.org/repos/richfaces
		export SVN_AUTHORS=$SCRIPTS/svn.authors

		export move_subtree=". $SCRIPTS/move-subtree.sh"
		export fetch_svn="bash $SCRIPTS/fetch-svn.sh"
		export fix_tags="bash $SCRIPTS/fix-tags.sh"
		export introduce_gitignore="$SCRIPTS/introduce-gitignore.sh"
		export merge_trees="bash $SCRIPTS/merge-trees.sh"
		export tag_merged_trees="bash $SCRIPTS/tag-merged-trees.sh"

		mkdir -p $FETCH $EXPORT $CLEANUP
	fi
}

rf2git_fetch() {
	# fetch parent
	pushd $FETCH
		git svn clone -s $SVN_ROOT/modules/build/parent/ parent \
			--revision=17000:HEAD --log-window-size=2500 --no-metadata --authors-file=$SVN_AUTHORS || exit
	popd


	# fetch resources
	pushd $FETCH
		git svn clone -s $SVN_ROOT/modules/build/resources resources \
			--revision=17000:HEAD --log-window-size=2500 --no-metadata --authors-file=$SVN_AUTHORS || exit
	popd


	# fetch trunk
	mkdir $FETCH/trunk
	pushd $FETCH/trunk
		FETCH_TAGS="4.0.0.20100713-M1,4.0.0.20100715-M1,4.0.0.20100822-M2,4.0.0.20100824-M2,4.0.0.20100826-M2,4.0.0.20100929-M3,4.0.0.20101004-M3,4.0.0.20101107-M4,4.0.0.20101110-M4,4.0.0.20101220-M5,4.0.0.20101226-M5,4.0.0.20110206-M6,4.0.0.20110207-M6,4.0.0.20110209-M6,4.0.0.20110220-CR1,4.0.0.20110227-CR1,4.0.0.20110313-Final,4.0.0.20110319-Final,4.0.0.Alpha1,4.0.0.Alpha2"
		FETCH_BRANCHES="4.0.0.20100713-M1,4.0.0.Alpha1,4.0.0.Alpha2,4.0.0.CR1,4.0.0.M5,4.0.0.M6,4.0.X"
		IGNORE_PATHS="^(?:3.*|archive|tests)"
		START_REV=18327

		#START_REV=`svn log --stop-on-copy $SVN_ROOT -q | tail -2 | head -1 | awk '{print substr($1,2)}'`

		git svn init $SVN_ROOT \
			--no-metadata --no-minimize-url --trunk=trunk --tags=tags --branches=branches
		git config svn.authorsfile $SVN_AUTHORS
		sed -ri 's#^(\s*tags = ).*$#\1tags/{'$FETCH_TAGS'}:refs/remotes/tags/*#' .git/config
		sed -ri 's#^(\s*branches = ).*$#\1branches/{'$FETCH_BRANCHES'}:refs/remotes/*#' .git/config
		git svn fetch --revision=$START_REV:HEAD --log-window-size=1000 --ignore-paths=$IGNORE_PATHS || exit
	popd
}

rf2git_tag_by_commit_message() {
	git log --pretty='format:%H %s' | grep $1 | awk '{ print $1; }' | head -n 1 | xargs git tag $1
}

rf2git_export() {
	# export build-resources
	rm -rf $CLEANUP/build-resources
	rm -rf $EXPORT/build-resources
	cp -r $FETCH/resources $CLEANUP/build-resources
	pushd $CLEANUP/build-resources
		git checkout master
		# remove all branches other than master
		git branch -r | sed -r 's/.{2}//' | grep -v '^trunk$' | xargs git branch -r -d
		$move_subtree '' $EXPORT/build-resources ". $SCRIPTS/fix-build-resources.sh"
	popd

	# export build-pom
	rm -rf $CLEANUP/build-pom
	rm -rf $EXPORT/build-pom
	cp -r $FETCH/trunk $CLEANUP/build-pom
	pushd $CLEANUP/build-pom
		$fix_tags
		$move_subtree '' $EXPORT/build-pom ". $SCRIPTS/fix-build-pom.sh"
	popd

	# join build-resources and build-pom to build
	rm -rf $EXPORT/build
	mkdir -p $EXPORT/build
	pushd $EXPORT/build-pom
		for BRANCH in `git branch | sed -r 's/.{2}//'`; do
			$merge_trees $EXPORT/build-resources $EXPORT/build-pom $EXPORT/build master $BRANCH $BRANCH
		done
	popd
	$tag_merged_trees $EXPORT/build-pom $EXPORT/build

	# export richfaces-shade-transformers
	rm -rf $CLEANUP/shade-transformers
	rm -rf $EXPORT/shade-transformers
	cp -r $FETCH/resources $CLEANUP/shade-transformers
	pushd $CLEANUP/shade-transformers
		$move_subtree faces-shade-transformers $EXPORT/shade-transformers
	popd
	pushd $EXPORT/shade-transformers
		git checkout master
		# remove all branches other than master
		git branch | sed -r 's/.{2}//' | grep -v master | xargs git branch -D
		# tag by commit message
		rf2git_tag_by_commit_message richfaces-shade-transformers-2
		rf2git_tag_by_commit_message richfaces-shade-transformers-3
		rf2git_tag_by_commit_message richfaces-shade-transformers-4
	popd

	# export richfaces-checkstyle
	rm -rf $CLEANUP/checkstyle
	rm -rf $EXPORT/checkstyle
	cp -r $FETCH/resources $CLEANUP/checkstyle
	pushd $CLEANUP/checkstyle
		$move_subtree checkstyle $EXPORT/checkstyle
	popd
	pushd $EXPORT/checkstyle
		git checkout master
		# remove all branches other than master
		git branch | sed -r 's/.{2}//' | grep -v master | xargs git branch -D
		# tag by commit message
		rf2git_tag_by_commit_message richfaces-checkstyle-1
		rf2git_tag_by_commit_message richfaces-checkstyle-2
	popd
	
	# export parent
	rm -rf $CLEANUP/parent
	rm -rf $EXPORT/parent
	cp -r $FETCH/parent $CLEANUP/parent
	pushd $CLEANUP/parent
		$fix_tags
		$move_subtree '' $EXPORT/parent ". $introduce_gitignore"
	popd
	pushd $EXPORT/parent
		git checkout master
		# richfaces-parent-9 is wrongly tagged
		git tag richfaces-parent-9 trunk@18535
		# remove all duplicate tags with @revision
		git tag -l | grep '@' | xargs git tag -d
		# remove all branches other than master
		git branch  | grep -v master | xargs git branch -D
	popd
	
	rm -rf $CLEANUP/trunk
	rm -rf $EXPORT/{cdk,core,components,showcase,archetypes,examples}
	cp -r $FETCH/trunk $CLEANUP/trunk
	pushd $CLEANUP/trunk
		$fix_tags
		$move_subtree cdk $EXPORT/cdk \
			"$SCRIPTS/update-parents.sh"
		$move_subtree core $EXPORT/core \
			"$SCRIPTS/update-parents.sh"
		$move_subtree ui $EXPORT/components \
			"$SCRIPTS/update-parents.sh"
		$move_subtree examples/richfaces-showcase $EXPORT/showcase \
			"$SCRIPTS/fix-showcase.sh $SCRIPTS/introduce-gitignore.sh"
		$move_subtree archetypes $EXPORT/archetypes \
			"$SCRIPTS/update-parents.sh"
		$move_subtree examples $EXPORT/examples \
			"$SCRIPTS/fix-examples.sh $SCRIPTS/update-parents.sh"
	popd
}

rf2git_setup $1

case $2 in
	fetch)
		rf2git_fetch
		;;
	export)
		rf2git_export
		;;
esac
	
