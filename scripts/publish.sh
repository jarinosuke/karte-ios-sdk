#!/bin/bash -e

# Copyright 2020 PLAID, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

##################################################
# Functions (Sub command functions)
##################################################

function set_remote_repository() {
  EXIST_REMOTE_REPO=`git remote | grep sync_repo | echo $?`
  if [[ $EXIST_REMOTE_REPO == 0 ]]; then
    git remote add sync_repo ${GITHUB_REMOTE_ADDRESS}
    git fetch sync_repo
  fi
}

function set_tag() {
  local TAG=$1
  git tag $TAG
  git push origin $TAG  
  git push sync_repo $TAG
}

function has_tag() {
  local TAG=$1
  REMOTE_TAGS=(`git tag`)
  for REMOTE_TAG in ${REMOTE_TAGS[@]}; do
    if [[ $REMOTE_TAG == $TAG ]]; then
      return 1
    fi
  done
  return 0
}

function sync_repository() {
  git push -f sync_repo master
}

function publish() {
  local TARGET_PODSPECS=($@)
  if [ ${#TARGET_PODSPECS[*]} -eq 0 ]; then
    echo "Podspec is not updated"
    exit 1
  fi

  local PODSPECS=("KarteUtilities.podspec" "KarteCore.podspec" "KarteInAppMessaging.podspec" "KarteRemoteNotification.podspec" "KarteVariables.podspec" "KarteVisualTracking.podspec" "KarteCrashReporting.podspec" "KarteNotificationServiceExtension.podspec")
  local SORTED_PODSPECS=()
  for PODSPEC in ${PODSPECS[@]}; do
    for TARGET_PODSPEC in ${TARGET_PODSPECS[@]}; do
      if [[ $PODSPEC == $TARGET_PODSPEC ]]; then
        SORTED_PODSPECS+=($PODSPEC)
      fi
    done
  done

  echo ${SORTED_PODSPECS[@]}

  # Synchronize repository.
  sync_repository

  # Set tag for Swift-PM
  publish_spm ${SORTED_PODSPECS[@]}

  # Set tag for Pods
  for PODSPEC in ${SORTED_PODSPECS[@]}; do
    local TARGET=`echo $PODSPEC | sed -e "s/.podspec//"`
    TAG_VERSION=`ruby scripts/bump_version.rb current-tag -p Karte.xcodeproj -t $TARGET`

    has_tag $TAG_VERSION
    if [ $? -eq 1 ]; then
      echo "This tag is already exist: $TAG_VERSION"
      exit 1
    else
      set_tag $TAG_VERSION
    fi
  done

  # Register cocoapods.
  publish_pods ${SORTED_PODSPECS[@]}

  # Publish release node
  ruby scripts/publish_changelog.rb
}

function publish_pods() {
  local PUBLISH_PODSPECS=($@)
  for PODSPEC in ${PUBLISH_PODSPECS[@]}; do
    POD_NAME=${PODSPEC%.*}
    POD_VERSION=`ruby scripts/bump_version.rb current-tag -p Karte.xcodeproj -t $POD_NAME`

    bundle exec pod trunk push $PODSPEC $PODSPEC_OPTS --synchronous

    SLACK_MESSAGE=`get_slack_message $? $POD_NAME ${POD_VERSION##*-}`
    curl -i -H "Content-type: application/json" -s -S -X POST -d "${SLACK_MESSAGE}" "${SLACK_WEBHOOK_URL}"
  done
}

function publish_spm() {
  TAG_VERSION=`cat .spm-version`

  has_tag $TAG_VERSION
  if [ $? -eq 1 ]; then
    echo "This tag is already exist: $TAG_VERSION"
    exit 1
  else
    set_tag $TAG_VERSION
  fi
}

function get_slack_message() {
  local RESULT=$1
  local NAME=$2
  local VERSION=$3

  local STATUS="Success"
  local COLOR="#007a5a"
  if [ $RESULT -ne 0 ]; then
    STATUS="Failure"
    COLOR="#de4e2b"
  fi
  cat <<EOF
{
  "blocks": [
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "The result of registering a Pod to CocoaPods.\nhttps://cocoapods.org/pods/${NAME}"
      }
    },
  ],
  "attachments": [
    {
      "color": "${COLOR}",
      "blocks": [
        {
          "type": "section",
          "fields": [
            {
              "type": "mrkdwn",
              "text": "*Status*"
            },
            {
              "type": "plain_text",
              "text": " "
            },
            {
              "type": "plain_text",
              "text": "${STATUS}",
              "emoji": true
            },
            {
              "type": "plain_text",
              "text": " "
            }
          ]
        },
        {
          "type": "section",
          "fields": [
            {
              "type": "mrkdwn",
              "text": "*Module*"
            },
            {
              "type": "mrkdwn",
              "text": "*Version*"
            },
            {
              "type": "plain_text",
              "text": "${NAME}",
              "emoji": true
            },
            {
              "type": "plain_text",
              "text": "${VERSION}",
              "emoji": true
            }
          ]
        },
      ]
    }
  ]
}
EOF
}

##################################################
# Checkout
##################################################

cd `dirname $0`
cd ../

##################################################
# Commands
##################################################

if [[ $EXEC_ENV == public ]]; then
  echo "This execution environment is public"
  exit 0
fi

if [ -z $PODSPEC_ONLY ]; then
  git config --global user.name "${GITHUB_USER_NAME}"
  git config --global user.email "${GITHUB_USER_EMAIL}"

  set_remote_repository

  DIFF_TARGETS=(`git diff --name-only sync_repo/master | grep podspec`)
  publish ${DIFF_TARGETS[@]}
else
  if [ -z "$PODSPECS" ]; then
    echo '$PODSPECS is not defined.' 1>&2
    echo 'ex) PODSPECS="KarteCore.podspec KarteInAppMessaging.podspec"' 1>&2
    exit 1
  fi
  publish_pods ${PODSPECS}
fi

