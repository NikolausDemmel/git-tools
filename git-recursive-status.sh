#!/bin/bash

# recusively look for git repositories in the current directory and print their
# status 

PARAM1=$1

function gitcheckstatus {
	olddir=`pwd`
	cd $1
	STATUS=`git status`
    [[ $STATUS =~ .*(working\ directory\ clean).* ]]
    CLEAN=$?
    git log git-svn..master --oneline
	if `exit $CLEAN` ; then
		# echo "clean"
		if [[ $PARAM1 == "all" ]] ; then
			git status -s
		fi
	else
		git status -s
	fi
	cd $olddir
}

function doit {

	repos=`find . -name ".git" -type d -printf "%h\n" | sort`

	for r in $repos ; do
		echo "    CHECKING: $r"
		gitcheckstatus $r	
	done
}

doit