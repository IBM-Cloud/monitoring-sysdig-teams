#!/bin/bash
# set -o errexit
# set -o pipefail
# set -o xtrace

eval "$(jq -r '@sh "ibmcloud_api_key=\(.ibmcloud_api_key) region=\(.region) resource_group_id=\(.resource_group_id) config_directory=\(.config_directory) team_go_name=\(.team_go_name) team_go_description=\(.team_go_description) team_go_theme=\(.team_go_theme) team_go_show=\(.team_go_show) team_go_filter=\(.team_go_filter) team_node_name=\(.team_node_name) team_node_description=\(.team_node_description) team_node_theme=\(.team_node_theme) team_node_show=\(.team_node_show) team_node_filter=\(.team_node_filter) IBMInstanceID=\(.IBMInstanceID)"')"

ibmcloud login --apikey ${ibmcloud_api_key} 2>&1 >/dev/null
[ $? -ne 0 ] && exit 1

ibmcloud target -r ${region} -g ${resource_group_id} 2>&1 >/dev/null
[ $? -ne 0 ] && exit 1

iam_oauth_tokens=$(ibmcloud iam oauth-tokens --output json)
[ $? -ne 0 ] && exit 1

iam_token=$(echo "${iam_oauth_tokens}" | jq -r '.iam_token')

sysdig_uri=${region}.monitoring.cloud.ibm.com

cat > "${config_directory}/post_node_payload.json" <<- EOF
{
  "name": "${team_node_name}",
  "description": "${team_node_description}",
  "theme": "${team_node_theme}",
  "show": "${team_node_show}",
  "filter": "${team_node_filter}",
  "default": false,
  "canUseSysdigCapture": false,
  "canUseAwsMetrics": false,
  "canUseCustomEvents": false,
  "canUseBeaconMetrics": false
}
EOF

post_node_result=$(curl -s -X POST -H "Content-Type: application/json" -H "authorization: ${iam_token}" -H "IBMInstanceID: ${IBMInstanceID}" -d @${config_directory}/post_node_payload.json "https://${sysdig_uri}/api/teams")


cat > "${config_directory}/post_go_payload.json" <<- EOF
{
  "name": "${team_go_name}",
  "description": "${team_go_description}",
  "theme": "${team_go_theme}",
  "show": "${team_go_show}",
  "filter": "${team_go_filter}",
  "default": false,
  "canUseSysdigCapture": false,
  "canUseAwsMetrics": false,
  "canUseCustomEvents": false,
  "canUseBeaconMetrics": false
}
EOF

post_go_result=$(curl -s -X POST -H "Content-Type: application/json" -H "authorization: ${iam_token}" -H "IBMInstanceID: ${IBMInstanceID}" -d @${config_directory}/post_go_payload.json "https://${sysdig_uri}/api/teams")

echo ${post_node_result} >${config_directory}/post_node_result.json
team_node_teamId=$(jq -r '.team | select (.!=null) | .userRoles[].teamId' ${config_directory}/post_node_result.json | tr -d '\r')
# if [ -z ${team_node_teamId} ]; then
#   jq -n '{"status": "error obtaining team node id"}'
#   exit 1
# fi

echo ${post_go_result} >${config_directory}/post_go_result.json
team_go_teamId=$(jq -r '.team | select (.!=null) | .userRoles[].teamId' ${config_directory}/post_go_result.json | tr -d '\r')
# if [ -z ${team_go_teamId} ]; then
#   jq -n '{"status": "error obtaining team go id"}'
#   exit 1
# fi

if [ ! -z ${team_node_teamId} ] && [ ! -z ${team_go_teamId} ]; then
  jq -n --arg team_node_teamId "${team_node_teamId}" --arg team_go_teamId "${team_go_teamId}" '{"team_node_teamId":$team_node_teamId, "team_go_teamId":$team_go_teamId}'
else
  jq -n '{"error": "error obtaining team id", "team_node_teamId": "", "team_go_teamId": ""}'
fi 
# jq -n '{"status": "done"}'

exit 0