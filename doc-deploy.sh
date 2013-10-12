#! /bin/bash
# Script to deploy .rst documents in a git repository

######### VARIABLES

PROJECT=$1

OWNER=""
REMOTE=""
SECTIONS=""
BRANCH_DEPLOY=""
REMOTE_DEPLOY=""
MASTER="master"
DEPLOY="deploy"
FILE_SPHINX="index.rst"
# DIR_DOC="doc"
DIR_DOC="_doc"
DIR_DOWNLOADS="_downloads"
DIR_BUILD="_build"
DIR_DEPLOY="_deploy"
DIR_STATIC="_static"
MAKE_METHOD="html"
GITHUB="gh-pages"
HEROKU="master"

# ===========function to build  github deployment in a folder==================

# Compile fresh output for one or more books and copy to deployment folder
makedeployment () {
  make clean $MAKE_METHOD BUILDDIR=$DIR_BUILD

  cp -R $DIR_BUILD/$MAKE_METHOD/* $DIR_OUT/

  # Add downloads if they exist
  if [[ -d $DIR_DOWNLOADS ]] ; then
    cp -R $DIR_DOWNLOADS $DIR_OUT/
  fi

  # Add section-specific static content
  if [[ -d $DIR_STATIC ]] ; then
    cp -RH $DIR_STATIC/* $DIR_OUT/
    # cp $DIR_STATIC/.ht* $DIR_OUT/ &>/dev/null || RC=$?
    cp -RH $DIR_STATIC/.ht* $DIR_OUT/ &>/dev/null || RC=$?
    if [[ $RC > 0 ]] ; then echo "$(pwd)$(tput setaf 1) $LINENO: cp -RH $DIR_STATIC/.ht* $DIR_OUT/ $(tput sgr0)" ; fi
  fi
  
}

# =============================================================================

######### PRE-EXECUTION TESTS

# test for no project name entered and not in a project already
if [[ $PROJECT = "" ]] ; then
  if [[ ! -d .git ]] ; then
    # not in a project and no project name given
    echo "Not in a project, or no project name given. Exiting ... "
    exit 1
  else
    # set project folder to present working directory
    PROJECT=${PWD##*/}
  fi
else
  if [[ ! -d $PROJECT ]] ; then
    # project folder does not exist
    echo "Project folder \"$PROJECT\" does not exist. Exiting ... "
    exit 1
  elif [[ ! -d $PROJECT/.git ]] ; then
    # no git repository in project
    echo "Folder \"$PROJECT\" is not a git repository. Exiting ... "
    exit 1
  else 
    # open project folder to set present working directory
    cd $PROJECT
  fi
fi

# test for type of remote in main project
set -- $(git remote -v)
if [[ $2 = "" ]] ; then
  # project has no remote
  echo "Project \"$PROJECT\" has no remote. Exiting ... "
  exit 1
else
  # save remote name
  REMOTE=$1
fi

# test for embedded documentation project folder or main documentation project
if [[ -e $DIR_DOC/$FILE_SPHINX ]] ; then
  # embedded sphinx documentation project found; set directory to it
  PROJECT=$PROJECT/$DIR_DOC
  cd $DIR_DOC
elif [[ ! -e $FILE_SPHINX ]] ; then
  # no embedded sphinx and not a sphinx project
  echo "No sphinxdoc configuration or document folder missing, Exiting ..."
  exit 1
fi

# test for or create remote in documentation (sub)project
set -- $(git remote -v)
TEST=$1
REMOTE_DEPLOY=$2
if [[ "${TEST#*$REMOTE}" = "$TEST" ]] ; then
  if [[ $REMOTE = "heroku" ]] ; then
    # project is deployed on Heroku, create documentation deployment there too
    echo -e "\nCreating new heroku remote deployment for documentation\n"
    heroku create
    echo "$(git remote -v)"
    set -- $(git remote -v)
    REMOTE_DEPLOY=$2
  else
    # main project deployed somewhere and documentation remote not set
    echo -e "Use \"git remote ... \" to set deployment for $PROJECT. Exiting ..."
    exit 1
  fi
  # project has a remote; use it
fi

# set branch name for deploy pull and push
case $REMOTE_DEPLOY in
  *"github"*)  
    BRANCH_DEPLOY=$GITHUB
    ;;
  *"heroku"*)
    BRANCH_DEPLOY=$HEROKU
    ;;
  **)
    # this script does not know how to deploy to the specified remote
    echo "Script does not support remote $REMOTE_DEPLOY. Exiting ..."
    exit 1
    ;;
esac

#  Project folder, supported remote, (embedded) sphinxdoc index.rst

echo -e "\nDocumentation project folder is $PROJECT"
echo -e "Remote for documentation is at $REMOTE_DEPLOY"
echo -e "Documentation branches:\n$(git branch -a)"
echo -e "Documentation remotes:\n$(git remote -v) \n"

########## CONFIGURING DEPLOYMENT FOLDER

echo "  --- CONFIGURING DEPLOYMENT ---"

# Read CNAME owner for github deployment, in case there is one
if [[ -e cnameowner ]] ; then
  OWNER=$(<cnameowner)
fi

# in the event it is missing, create a git project deployment folder
if [[ ! -d $DIR_DEPLOY ]] ; then
  mkdir -p $DIR_DEPLOY
fi
if [[ ! -d $DIR_DEPLOY/.git ]] ; then
  echo -e "\nCreating deployment folder $DIR_DEPLOY\n"
  cd $DIR_DEPLOY
  git init
  git commit --allow-empty -m "empty first commit"
  set -- $(git branch)
  git branch -m $2 $DEPLOY
  # ##
  echo "git remote add origin $REMOTE_DEPLOY"
  # ##
  git remote add origin $REMOTE_DEPLOY
  echo "BRANCH is \"$(git branch -a)\""
  git fetch origin
  # git checkout -B $DEPLOY
  # Save directory in git and Prevent jekyll markup interpretation
  touch .gitkeep
  touch .gitignore
  touch .nojekyll
  git add .
  git commit -m "hidden control files"
  cd ..
fi

# Clean the deployment folder and pull the repository branch
rm -rf $DIR_DEPLOY/*
cd $DIR_DEPLOY
# fatal error returned if remote site does not include the deploy branch
TEST=$(git branch -a)
if [[ "$TEST" != "${TEST/$BRANCH_DEPLOY/}" ]] ; then
  git pull -f origin $BRANCH_DEPLOY:$DEPLOY
fi 
cd ..

echo "  ----- CREATING OUTPUT -----"

# if no sections specified, look for a file "sections" listing sections
if [[ -e sections ]] ; then
  SECTIONS+=" "$(<sections)
fi

# Compile fresh output for one or more books and copy to deployment folder
if [[ "$SECTIONS" = "" ]] ; then
  DIR_OUT=$DIR_DEPLOY
  makedeployment
else
  
  # Add shared static content
  if [[ -d $DIR_STATIC ]] ; then
    cp -RH $DIR_STATIC/* $DIR_DEPLOY/
    # cp $DIR_STATIC/.ht* $DIR_DEPLOY/ &>/dev/null || RC=$?
    cp -RH $DIR_STATIC/.ht* $DIR_DEPLOY/ &>/dev/null || RC=$?
    if [[ $RC > 0 ]] ; then echo "$(pwd)$(tput setaf 1) $LINENO: cp -RH $DIR_STATIC/.ht* $DIR_DEPLOY/ $(tput sgr0)" ; fi
  fi
  
  # Make HTML, other deployment files
  for SECT in $SECTIONS ; do
    if [[ -d $SECT ]] ; then
      DIR_OUT=../$DIR_DEPLOY/$SECT
      cd $SECT
        echo -e "$(tput setaf 2)\n Making section $SECT \n$(tput sgr0)"
        mkdir -p $DIR_OUT
        makedeployment
        # Copy MASTER from its deploy subdirectory
        if [[ $SECT == $MASTER ]] ; then
          cp -RH $DIR_OUT/* ../$DIR_DEPLOY/
          # cp $DIR_OUT/.ht* ../$DIR_DEPLOY/ &>/dev/null || RC=$?
          cp -RH $DIR_OUT/.ht* ../$DIR_DEPLOY/ &>/dev/null || RC=$?
          if [[ $RC > 0 ]] ; then echo "$(pwd)$(tput setaf 1) $LINENO: cp -RH $DIR_OUT/.ht* ../$DIR_DEPLOY/ $(tput sgr0)" ; fi
          # If it exists, delete CNAME from master deploy subdirectory
          if [[ -e $DIR_OUT/CNAME ]] ; then
            echo "CNAME $(<../$DIR_DEPLOY/$MASTER/CNAME) found in ../$DIR_DEPLOY/$MASTER/CNAME"
            rm $DIR_OUT/CNAME
          fi
        fi
      cd ..
    fi
  done

fi

# if we are on gh-pages AND there exists a CNAME file
if [[ $BRANCH_DEPLOY = $GITHUB ]] ; then
  if [[ -e $DIR_DEPLOY/CNAME ]] ; then
    if [[ "$REMOTE_DEPLOY" == "${REMOTE_DEPLOY/$OWNER/}" ]] ; then
      # if $GITHUB and CNAME owner != remote deployer, remove CNAME
      rm $DIR_DEPLOY/CNAME
    fi
  fi
fi

# Deploy the repository branch
if [[ -d $DIR_DEPLOY ]] ; then
  cd $DIR_DEPLOY
  git add .
  git commit -m "Deployed documentation"
  git push -u origin $DEPLOY:$BRANCH_DEPLOY

  echo -e "\npushed to origin branch $DEPLOY:$BRANCH_DEPLOY\n"

  cd ..
fi

######### NORMAL EXIT

echo "  --- FINISHED ---"
echo "Check all messages for possible errors."
echo "Then commit and push source changes as well."

# Authors: Gerald Lovel, glovel@aaltsys.com; Julia Lovel, jlovel@aaltsys.com

# 12/17/2012 - GARL -- Added copy master folder contents to $DIR_DEPLOY root
# 02/20/2013 - GARL -- Added support for deployment to Heroku, Github, ...
# 03/10/2013 - GARL -- Embedded documentation in code projects added
