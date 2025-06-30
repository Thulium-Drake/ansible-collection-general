#!/bin/bash
# Checks out all stuff from Gitea or other sources and builds collection
# Expects the following envvars set GITHUB_TOKEN, GITHUB_SERVER_URL and GALAXY_TOKEN

# Variables
# The UID of the org where all roles are located
GITEA_ORG_UID=19

# Collect current published version and compare
COLLECTION_GALAXY_VERSION_FULL=$(curl -s https://galaxy.ansible.com/api/v3/plugin/ansible/content/published/collections/index/thulium_drake/general/ | jq -r .highest_version.version)

COLLECTION_GALAXY_VERSION_WEEK=$(echo $COLLECTION_GALAXY_VERSION_FULL | cut -d. -f1-2)
COLLECTION_GALAXY_VERSION_RELEASE=$(echo $COLLECTION_GALAXY_VERSION_FULL | cut -d. -f3)

COLLECTION_VERSION=$(date +%Y.%-W)
COLLECTION_MINOR=${1:-0}

if test "$COLLECTION_GALAXY_VERSION_WEEK" == "$COLLECTION_VERSION"
then
  COLLECTION_MINOR=$(( $COLLECTION_GALAXY_VERSION_RELEASE + 1 ))
fi

# Set up git
git config --global url."https://$GITEA_TOKEN@$GITHUB_SERVER_URL".insteadOf "$GITHUB_SERVER_URL/"
ROLE_REPOS=$(curl -H "Authorization: token $GITHUB_TOKEN" "$GITHUB_SERVER_URL/api/v1/repos/search?q=role&uid=$GITEA_ORG_UID&limit=100" | jq '.data[] | "\(.name) ssh://\(.ssh_url)"')

# Create collection
START_DIR=$PWD
VERSION_FILE=$START_DIR/VERSIONS.md
rm -rf $START_DIR/{roles,plugins,playbooks} thulium_drake-general-*.tar.gz
git checkout galaxy.yml >/dev/null 2>&1

echo -e "$ROLE_REPOS"
exit 1

echo "Going to process"
mkdir -p $START_DIR/{roles,plugins,playbooks}

echo "|        Role name       | Version |" > $VERSION_FILE
echo "| ---------------------- | ------- |" >> $VERSION_FILE

for i in $($TEA_BIN repo s --owner 'Ansible' -lm 100 -o csv -f name,ssh role | tail -n+2)
do
  ROLE_NAME=$(echo $i | cut -d\" -f2 | cut -d- -f2)
  ROLE_SSH_URL=$(echo $i | cut -d\" -f4)

  echo "Processing role $ROLE_NAME"
  git clone $ROLE_SSH_URL $START_DIR/roles/$ROLE_NAME >/dev/null 2>&1
  cd $START_DIR/roles/$ROLE_NAME || exit 1
  ROLE_TAG=$(git describe --tags $(git rev-list --tags --max-count=1))
  git checkout $ROLE_TAG >/dev/null 2>&1
  echo "| $ROLE_NAME | ${ROLE_TAG:-master} |" | tee -a $VERSION_FILE
  rm -rf $START_DIR/roles/$ROLE_NAME/.git
  if test -d playbooks
  then
    cd playbooks
    echo "Processing playbooks for $ROLE_NAME"
    for i in *.yml
    do
      cp $i $START_DIR/playbooks
    done
  fi
done

echo "Processing plugin ansible-merge-vars"
# 3rd-party stuff that is outside of any existing collection
mkdir -p $START_DIR/plugins/action
wget -o /dev/null https://raw.githubusercontent.com/leapfrogonline/ansible-merge-vars/master/ansible_merge_vars.py -O $START_DIR/plugins/action/merge_vars.py

echo "Updating galaxy.yml"
sed -i "s/VERSION/$COLLECTION_VERSION.$COLLECTION_MINOR/" $START_DIR/galaxy.yml

cd $START_DIR
ansible-galaxy collection build $START_DIR --force
git checkout galaxy.yml >/dev/null 2>&1

ansible-galaxy collection publish thulium_drake-general-$COLLECTION_VERSION.$COLLECTION_MINOR.tar.gz
