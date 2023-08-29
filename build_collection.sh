#!/bin/bash
# Requires tea, Gitea CLI
# Checks out all stuff from Gitea or other sources and builds collection

START_DIR=$PWD
VERSION_FILE=$START_DIR/VERSIONS.md
COLLECTION_VERSION=$(date +%Y.%W)
COLLECTION_MINOR=${1:-0}
rm -rf $START_DIR/roles/* $START_DIR/plugins/*
git checkout galaxy.yml >/dev/null 2>&1

echo "|        Role name       | Version |" > $VERSION_FILE
echo "| ---------------------- | ------- |" >> $VERSION_FILE

for i in $(tea repo s --owner 'Ansible' -o csv -f name,ssh | tail -n+3)
do
  ROLE_NAME=$(echo $i | cut -d\" -f2 | cut -d- -f2)
  ROLE_SSH_URL=$(echo $i | cut -d\" -f4)

  echo "Processing role $ROLE_NAME"
  git clone $ROLE_SSH_URL $START_DIR/roles/$ROLE_NAME >/dev/null 2>&1
  cd $START_DIR/roles/$ROLE_NAME
  ROLE_TAG=$(git describe --tags $(git rev-list --tags --max-count=1))
  git checkout $ROLE_TAG >/dev/null 2>&1
  echo "| $ROLE_NAME | ${ROLE_TAG:-master} |" >> $VERSION_FILE
  rm -rf .git
done

echo "Processing plugin ansible-merge-vars"
# 3rd-party stuff that is outside of any existing collection
mkdir -p $START_DIR/plugins/action
wget -o /dev/null https://raw.githubusercontent.com/leapfrogonline/ansible-merge-vars/master/ansible_merge_vars.py -O $START_DIR/plugins/action/ansible_merge_vars.py

echo "Updating galaxy.yml"
sed -i "s/VERSION/$COLLECTION_VERSION.$COLLECTION_MINOR/" $START_DIR/galaxy.yml

cd $START_DIR
ansible-galaxy collection build $START_DIR --force
echo "Work's done! Run command below to publish:

ansible-galaxy collection publish thulium_drake-general-$COLLECTION_VERSION.$COLLECTION_MINOR.tar.gz"
