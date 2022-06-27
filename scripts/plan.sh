#!/bin/bash

DATASOURCE=`buildkite-agent meta-data get "DATASOURCE"`
CHANGELOG_DIR=`pwd`

URL=`echo ${JDBC_URL} | jq ".${DATASOURCE}_jdbc_url" | tr -d '"'`
CHANGELOG_FILE="${DATASOURCE}-changelog.postgres.sql"
LIQUIBASE_LOG_FILE="${CHANGELOG_DIR}/changelog/liquibase.log"

export BUILD_ID="BUILD-PLAN:${BUILDKITE_COMMIT::8}#${BUILDKITE_BUILD_NUMBER}-${BUILDKITE_BUILD_ID}"

chmod 755  $CHANGELOG_DIR
chmod 777 -R $CHANGELOG_DIR/pipelinePlatforms/databaseOperation/changelog/

echo "" > ${LIQUIBASE_LOG_FILE}

chmod 766  "${LIQUIBASE_LOG_FILE}"

function send_slack_notification(){

  local message=$1
  SLACK_URL="$SLACK_URL"
  TITLE="Build #${BUILDKITE_BUILD_NUMBER} | $BUILDKITE_BRANCH | ${BUILDKITE_COMMIT::8}"
  EXIT_STATUS=$2
  COLOR='good'

  if [ ${EXIT_STATUS} -ne 0 ]; then
    COLOR='danger'
  fi  

  PAYLOAD_SKELETON='{"attachments":[{"title":"","color":"","fields":[{"title":"BUILD_STEP","value":"DB_BACKUP","short":true},{"title":"BUILD_URL","value":"DB_BACKUP","short":false},{"title":"BUILD_STEP_MESSAGE","value":"SUCCESSFULL","short":true}],"footer":"liquibase"}]}'

  UPDATE_PAYLOAD=`echo $PAYLOAD_SKELETON | jq --indent 0 --arg build_label "${BUILDKITE_LABEL}" '.attachments[0].fields[0].value = $build_label'`
  UPDATE_PAYLOAD=`echo $UPDATE_PAYLOAD | jq --indent 0 --arg build_url "${BUILDKITE_BUILD_URL}" '.attachments[0].fields[1].value = $build_url'`
  UPDATE_PAYLOAD=`echo $UPDATE_PAYLOAD | jq --indent 0 --arg title "$TITLE" '.attachments[0].title = $title'`
  UPDATE_PAYLOAD=`echo $UPDATE_PAYLOAD | jq --indent 0 --arg color "$COLOR" '.attachments[0].color = $color'`
  
  echo $UPDATE_PAYLOAD | jq --indent 0 --arg message "$message" '.attachments[0].fields[2].value = $message' > payload.json
  curl -w "%{http_code}\n" -XPOST $SLACK_URL -H 'Content-Type: application/json' -d @payload.json
}

docker run --name liquibase_${BUILDKITE_BUILD_NUMBER} -v "${CHANGELOG_DIR}/changelog:/liquibase/changelog"  liquibase/liquibase \
    --url=${URL} \
    --changelogFile="${CHANGELOG_FILE}" --log-level=info  updateSQL | tee ${LIQUIBASE_LOG_FILE}

docker_exit_code=`docker inspect liquibase_${BUILDKITE_BUILD_NUMBER} --format='{{.State.ExitCode}}'`
docker rm -f liquibase_${BUILDKITE_BUILD_NUMBER}

#message=`cat ${LIQUIBASE_LOG_FILE}`


if [ ${docker_exit_code} -ne 0 ]; then

    #message=`cat message.txt`
     send_slack_notification "LIQUIBASE UPDATESQL PLAN FAILED" $docker_exit_code
     exit ${docker_exit_code}
    
else
    send_slack_notification "LIQUIBASE UPDATESQL PLAN SUCCESSFULL" $docker_exit_code
    exit ${docker_exit_code}

fi  
# send_slack_notification "'${message}'"