#!/bin/bash

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
  local var="$1"
  local fileVar="${var}_FILE"
  local def="${2:-}"

  if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
    echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
    exit 1
  fi

  local val="$def"
  if [ "${!var:-}" ]; then
    val="${!var}"
  elif [ "${!fileVar:-}" ]; then
    val="$(< "${!fileVar}")"
  fi

  export "$var"="$val"
  unset "$fileVar"
}

# Make sure we're not confused by old, incompletely-shutdown httpd
# context after restarting the container.  httpd won't start correctly
# if it thinks it is already running.
rm -rf /run/apache2/* /tmp/apache2*

# WARNING: If DOCROOT is set it must must begin with /var/application
# DOCROOT is a combination of absolute and relatave path
# Once decommision the Transitional Platform  we should refactor
# Propose two variables for maximum flexibilty and clarity
# 1.) GIT_PATH: The path to do the Git Clone to
# 2.) DOC_SUBDIR: The RELATIVE path from GIT_PATH to the Drupal files
# DocumentRoot in httpd config would be set to GIT_PATH+DOC_SUBDIR

file_env 'DOCROOT'
if [ ! -z "$DOCROOT" ] && ! grep -q "^DocumentRoot \"$DOCROOT\"" /etc/httpd/conf/httpd.conf ; then
  sed -i "s#/var/www/public#$DOCROOT#g" /etc/httpd/conf/httpd.conf
fi
echo "export DOCROOT='$DOCROOT'" > /etc/profile.d/docroot.sh

# GIT_DIR is currently hard coded
GIT_DIR="/var/application" 
GIT_REPO="$GIT_DIR/.git"

if [ -z "$GIT_BRANCH" ]; then
  GIT_BRANCH="master"
fi

# To do manual git management leave GIT_URL unset,  DOCROOT will still be used by Apache as the DocumentRoot
if [ -v GIT_URL ] && [ ! -e "/initialized" ]; then
  if [ ! -d "$GIT_REPO" ]; then
    echo "Git clone of $GIT_URL to $GIT_DIR"
    git clone $GIT_URL $GIT_DIR
  fi

  echo "Checking out $GIT_BRANCH git branch"
  git --git-dir=$GIT_REPO --work-tree=$GIT_DIR checkout -q $GIT_BRANCH

  echo "Pulling the latest code into $GIT_DIR"
  git --git-dir=$GIT_REPO --work-tree=$GIT_DIR pull origin $GIT_BRANCH

  if [ -f "$GIT_DIR/.gitmodules" ]; then 
    echo "Updating submodules"
    # Unfortunately we have to CD to the working directory for this to work
    # there is a bug with submodule that --work-tree is ignored
    cd $GIT_DIR
  
    # We aren't using ssh keys so we need to make github urls relative
    sed -i.bak "s/git@github\.com\:/\.\.\/\.\.\//g" "$GIT_DIR/.gitmodules"
    sed -i.bak "s/git@bitbucket\.org\:/\.\.\/\.\.\//g" "$GIT_DIR/.gitmodules"

    git --git-dir=$GIT_REPO --work-tree=$GIT_DIR submodule update --init --recursive --remote
    git --git-dir=$GIT_REPO --work-tree=$GIT_DIR submodule foreach -q --recursive 'git checkout $(git config -f $toplevel/.gitmodules submodule.$name.branch || echo master)'
    cd $OLDPWD
  fi

else
  echo "Warning: GIT_URL environemnt variable not set, no drupal code pulled"
fi

# Symlink appropriate directories into the drupal document root
# It would be good to have a more dynamic way to do this
# to support other use cases
if [ -f "/var/application/.mounts" ] && [ ! -e "/initialized" ]; then
  while read p; do
    src=$(echo $p | cut -f1 -d:)
    dst=$(echo $p | cut -f2 -d:)

    # Removes existing files and directories without existing symlinks as a precaution
    if [[ !(-L "$dst") && -e "$dst" ]]; then
      rm -fR "$dst"
    fi

    # Make sure the directory one level above $dest so the simbolic link will not fail
    mkdir -p ${dst%/*}

    ln -sf $src $dst
    echo $src $dst
  done </var/application/.mounts
fi

# Create a file on local filesystem to faciliate container restart speed
# as well as to ensure .mounts logic runs only once
# the conditional helps with testing as the file is only touched once, etc. 
if [ ! -e "/initialized" ]; then
  touch "/initialized"
fi

exec /usr/sbin/httpd -DFOREGROUND
