#! /bin/bash
# Script to create directories for GitHub publishihg repositories

######### VARIABLES

PROJECT=$1

REMOTE=""
SECTIONS=""
BRANCH_DOC="doc"
# used in sphinxinit
KEEP=".gitkeep"
STATIC="_static"
DEPLOY="_deploy"
XSTATIC=""
XDEPLOY=""
DIRS="_build _downloads _images"
THEME="aaltsys"
# used in main program
MASTER="master"
CONFPY=""

# ===============function to initialize Sphinx in a folder=====================

sphinxinit () {

  # create directories and keep for git
  for DIR in $DIRS ; do
    if [[ ! -d $DIR ]] ; then
      mkdir $DIR
    fi
    touch $DIR/$KEEP
  done

  # add aaltsys theme and aaltsys.css
   mkdir -p $XSTATIC/$THEME
   wget -O $XSTATIC/$THEME.css_t http://develop.aaltsys.info/resources/_downloads/aaltsys.css_t
   wget -O $XSTATIC/$THEME/theme.conf http://develop.aaltsys.info/resources/_downloads/aaltsys/theme.conf

  # add entries for pseudo-dynamic deployment at Heroku
  touch $XSTATIC/index.php
  echo 'php_flag engine off' > $XSTATIC/.htaccess
  
  # add sphinx to documents folder
  echo -e "$(tput setaf 1)\n -- Initializing Sphinxdoc in folder \"${PWD##*/}\" -- \n$(tput sgr0)"
  sphinx-quickstart

  # edit conf.py: use aaltsys theme, remove index navigation link
  sed -i "s^\['$STATIC'\]^\['$XSTATIC'\]^" ./conf.py
  sed -i "s^\#html_use_index = True^html_use_index = False^" ./conf.py
  sed -i "s^html_theme = 'default'^html_theme = '$THEME'^" ./conf.py
  sed -i "s^\#html_theme_path = \[\]^html_theme_path = \['$XSTATIC'\]^" ./conf.py
  sed -i "s^\_patterns = \['_build'\]^_patterns = \['_build', '_deploy'\]^" ./conf.py
  if [[ $SECTIONS != "" ]] ; then
    sed -i "s^extensions = \[\]^extensions = \['sphinx.ext.intersphinx'\]^" ./conf.py
    rm -rf $STATIC
  fi

  # make sphinx initial index html
  make clean html
}

# =============================================================================

######### PRE-EXECUTION TESTS

# test for no project name entered
if [[ $PROJECT = "" ]] ; then
  # project folder may be open already
  if [[ ! -d .git ]] ; then
    echo "Not in a project, or no project name given. Exiting ... "
    exit
  else
    PROJECT=${PWD##*/}
  fi
else
  # test for project folder does not exist
  if [[ -d $PROJECT ]] ; then
    # test for project folder is not a git repository
    if [[ -d $PROJECT/.git ]] ; then
      # now open project folder
      cd $PROJECT
    else
      echo "Folder \"$PROJECT\" is not a git repository. Exiting ... "
      exit
    fi
  else
    echo "Project folder \"$PROJECT\" does not exist. Exiting ... "
    exit
  fi
fi

echo "Project is \"$PROJECT\""

# test for project has a remote, otherwise document deployment will not work
set -- $(git remote -v)
REMOTE=$2
if [[ $REMOTE = "" ]] ; then
  echo "Project \"$PROJECT\" has no remote. Exiting ... "
  exit
fi

echo "Remote for project is $REMOTE"

########## MAIN PROGRAM

# if no sections specified, look for a file \"sections\" listing sections
if [[ -e sections ]] ; then
  SECTIONS+=" "$(<sections)
fi

# setup .gitignore for documentation project
wget -O .gitignore http://develop.aaltsys.info/resources/_downloads/.gitignore

# initialize main or subsections folders
if [[ $SECTIONS = "" ]] ; then
  XSTATIC="$STATIC"
  XDEPLOY="$DEPLOY"
  DIRS="$DIRS $STATIC $DEPLOY"
  sphinxinit
else
  # $STATIC and $DEPLOY must be shared --
  touch index.rst
  XSTATIC='../'$STATIC
  XDEPLOY='../'$DEPLOY
  DIRS="$DIRS $XSTATIC $XDEPLOY"
  
  CONFPY='\n\n''intersphinx_mapping = {'
  for SECT in $SECTIONS ; do
    if [[ ! -d $SECT ]] ; then
      mkdir $SECT
    fi
    cd $SECT
    sphinxinit
    cd ..
    if [[ $SECT != $MASTER ]] ; then
      CONFPY=${CONFPY}'\n'"   '$SECT': ('$SECT', '$XDEPLOY/$SECT/objects.inv'),"
    fi
  done
  CONFPY=${CONFPY}'\n'"}"
  if [[ $SECT == $MASTER ]] ; then
    echo -e ${CONFPY} >> $MASTER/conf.py
  fi
fi

######### NORMAL EXIT

cd ..

echo -e "\nFinished creating directories and files for project \"$PROJECT\".\n"
echo "Edit main \".gitignore\" file to ignore \"_build\", \"_deploy\" folders."
if [[ ! $SECTIONS = "" ]] ; then
  echo "Edit master index to reference"
  echo "$SECTIONS"
fi
echo "Start each indexable document with a numeric digit."
echo "Edit index files to glob \"[0-9]*\"."
exit

# Authors: Gerald Lovel, gerald@lovels.us
