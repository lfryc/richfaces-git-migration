#!/bin/bash

# Program locations
xmlstarlet=/usr/bin/xmlstarlet
git=/usr/bin/git

phase1_dir=import-phase1
phase2_dir=import-phase2
svnroot=http://anonsvn.jboss.org/repos/richfaces/
svnauthors=$PWD/svn.authors
get_resources=0
get_parent=1
get_docs=0
get_main=1
publish=0
ignore_paths="^(?:3.*|archive|tests)"   

$git for-each-ref --format='%(refname)' refs/remotes/tags/* | while read tag_ref; do
      tag=${tag_ref#refs/remotes/tags/}
      tree=$( $git rev-parse "$tag_ref": )

      # find the oldest ancestor for which the tree is the same
      parent_ref="$tag_ref";
      while [ $( $git rev-parse --quiet --verify "$parent_ref"^: ) = "$tree" ]; do
         parent_ref="$parent_ref"^
      done
      parent=$( $git rev-parse "$parent_ref" );

      # if this ancestor is in trunk then we can just tag it
      # otherwise the tag has diverged from trunk and it's actually more like a
      # branch than a tag
      merge=$( $git merge-base "refs/remotes/trunk" $parent );
      if [ "$merge" = "$parent" ]; then
          target_ref=$parent
      else
          echo "tag has diverged: $tag"
          target_ref="$tag_ref"
      fi
      target_ref=$parent

      tag_name=$( $git log -1 --pretty="format:%an" "$tag_ref" )
      tag_email=$( $git log -1 --pretty="format:%ae" "$tag_ref" )
      tag_date=$( $git log -1 --pretty="format:%ai" "$tag_ref" )
      $git log -1 --pretty='format:%s' "$tag_ref" | GIT_COMMITTER_NAME="$tag_name" GIT_COMMITTER_EMAIL="$tag_email" GIT_COMMITTER_DATE="$tag_date" $git tag -a -F - "$tag" "$target_ref"

      $git update-ref -d "$tag_ref"
done
