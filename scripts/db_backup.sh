#!/bin/bash 


DATASOURCE=`buildkite-agent meta-data get "DATASOURCE"`
CHANGELOG_DIR=`pwd`
URL=`echo ${JDBC_URL} | jq ".${DATASOURCE}_psql_url" | tr -d '"'`
#DB_BACKUP_KEY=`buildkite-agent meta-data get "DB-BACKUP"`

chmod 755 $CHANGELOG_DIR

DB_OPS_DIR="${CHANGELOG_DIR}/"
PSQL_STATEMENTS_DIR="${CHANGELOG_DIR}/sql_scripts"

mkdir "${PSQL_STATEMENTS_DIR}"
chmod -R 766 "${PSQL_STATEMENTS_DIR}"

FIRST_RETENTION=1 #LATEST_BACKUP_RETENTION
SECOND_RETENTION=2 #RETAINING FOR 2 BACKUP
THIRD_RETENTION=3 #DROPPING THIRD BACKUP
export BUILD_ID="BUILD-DB-BACKUP:${BUILDKITE_COMMIT::5}#${BUILDKITE_BUILD_NUMBER}-${BUILDKITE_BUILD_ID}"

function create_alter_table_statement(){

    local NEW_RETENTION=$1
    local OLD_RETENTION=$2
    local FILENAME=$3
    cat ${FILENAME} | sed  "s/NEW_RETENTION/${NEW_RETENTION}/g"  | sed  "s/OLD_RETENTION/${OLD_RETENTION}/g" | tee "${PSQL_STATEMENTS_DIR}/${NEW_RETENTION}_alter_table.sql"
    
    
}
function create_drop_table_statement(){

    local DROP_RETENTION=$1
    local FILENAME=$2
    cat ${FILENAME} | sed  "s/DROP_RETENTION/${DROP_RETENTION}/g" | tee "${PSQL_STATEMENTS_DIR}/${DROP_RETENTION}_drop_table.sql"
}

function create_backup_table_statement(){
    local RETENTION=$1
    local FILENAME=$2
    cat ${FILENAME} | sed "s/RETENTION/${RETENTION}/g" | tee "${PSQL_STATEMENTS_DIR}/${RETENTION}_backup_table.sql"
}

function check_backup_table(){
    local RETENTION=$1
    data=`docker run --rm psql-client psql ${URL} -AXqtc "SELECT * FROM tenants.backup_${RETENTION}_tenants;" 2>/dev/null`
    if [ ${#data} -eq 0 ]
    then
        echo 0 #echo "Table ${RETENTION}_backup_aws_ec2_details  does not exists"
    else
        echo 1 #echo "Table ${RETENTION}_backup_aws_ec2_details does exists"
    fi
}

function apply_sql_statement(){
    local FILENAME=$1
    echo -e "\napplying file:${FILENAME}"
    docker run --rm   -v "${PSQL_STATEMENTS_DIR}:/tmp" psql-client psql ${URL} -f "/tmp/${FILENAME}"
     
}


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




echo -e "\nChecking For Second Backup" > message.txt

if [[ $(check_backup_table ${SECOND_RETENTION}) -eq 0 ]]
then
    echo -e "SECOND BACKUP_DOES NOT EXISTS" >> message.txt
else
    echo -e "SECOND BACKUP_DOES  EXISTS\nMOVING SECOND BACKUP TO THRID...." >> message.txt
    create_alter_table_statement ${THIRD_RETENTION} ${SECOND_RETENTION} "${DB_OPS_DIR}/sql_scripts/alter_table.sql" >> tee message.txt
    apply_sql_statement "${THIRD_RETENTION}_alter_table.sql" >> message.txt
fi

echo -e "\nChecking For First Backup" >> message.txt

if [[ $(check_backup_table ${FIRST_RETENTION}) -eq 0 ]]
then
    echo -e "FIRST BACKUP_DOES NOT EXISTS\nCREATING FIRST BACKUP...." >> message.txt
    create_backup_table_statement ${FIRST_RETENTION} "${DB_OPS_DIR}/sql_scripts//backup_table.sql" >> tee message.txt
    apply_sql_statement "${FIRST_RETENTION}_backup_table.sql" >> tee message.txt
else
    echo -e "FIRST BACKUP_DOES  EXISTS\nMOVING FIRST BACKUP TO SECOND...." >> message.txt
    create_alter_table_statement ${SECOND_RETENTION} ${FIRST_RETENTION} "${DB_OPS_DIR}/sql_scripts/alter_table.sql" >> tee message.txt
    apply_sql_statement "${SECOND_RETENTION}_alter_table.sql" >> message.txt

    echo -e "\nCREATING LATEST BACKUP..." >> message.txt
    create_backup_table_statement ${FIRST_RETENTION} "${DB_OPS_DIR}/sql_scripts/backup_table.sql" >> message.txt
    apply_sql_statement "${FIRST_RETENTION}_backup_table.sql" >> message.txt
fi

echo -e "\nChecking For Third Backup" >> message.txt

if [[ $(check_backup_table ${THIRD_RETENTION}) -eq 0 ]]
then
    echo -e "THIRD BACKUP_DOES NOT EXISTS" >> message.txt
else
    echo -e "THIRD BACKUP_DOES EXISTS\nCREATING DROP TABLE STATEMENT...." >> message.txt
    create_drop_table_statement ${THIRD_RETENTION} "${DB_OPS_DIR}/sql_scripts/drop_table.sql" >> message.txt
    apply_sql_statement "${THIRD_RETENTION}_drop_table.sql" >> message.txt
fi

exit_status=$?
cat message.txt

if [ ${exit_status} -ne 0 ]; then

    #message=`cat message.txt`
     send_slack_notification "DB_BACKUP FAILED" $exit_status
     exit ${exit_status}
    
else
    send_slack_notification "DB_BACKUP SUCCESSFULL" $exit_status
    exit ${exit_status}

fi  

