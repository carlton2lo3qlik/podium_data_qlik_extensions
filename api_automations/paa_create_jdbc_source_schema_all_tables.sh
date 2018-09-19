#!/bin/bash
###
### The goal of this script is to demonstrate Podium API capability to categorize and load data. Customers should perform all the necessary test against their 
### environments and requirements. This is not meant for Production use.
###
### the purpose of this script is automatically create Podium source with all tables from a specific schema via JDBC connection
### this should be an one-time use for initial source creation ONLY.
###
### this script utilize number of json files to struct request & response payload. after each load, we should clean up all the .json & .json-e files.
### it requires jq utility (https://stedolan.github.io/jq/), jq is a very high-level functional programming language with support for backtracking and managing streams of JSON data.
###

usage_msg() {
	echo "This script will automatically create Podium source with all tables from a specific schema via JDBC connection." 
	echo "This should be an one-time use for initial source creation ONLY." 
	echo "prerequisites - jq (https://stedolan.github.io/jq/download/)"
	echo -e "\nUsage:\n bash ./pd33_create_jdbc_source_schema_all_tables.sh [arg: configuration file]"
	echo -e " [i.e.] #bash ./pd33_create_jdbc_source_schema_all_tables.sh ./config/pd33_create_jdbc_source_schema_all_tables.config > ./logs/pd33_create_jdbc_source_schema_all_tables.out 2>&1 &\n"	
	echo -e "  configuration file should contain the following variables"
	echo -e "  hostname=\"http://ludwig.podiumdata.com:8180/podium\""
	echo -e "  source_connection_name=\"PODIUM_POSTGRES_CONNECTION\""pd33_create_get_ONLY_WANTED_SCHEMA_TABLES_OUT_jdbc_source_jq.json
	echo -e "  schema_name=\"podium_core\""
	echo -e "  source_name=\"RBI\""
	echo -e "  base_dir=\"\/podiumbuild\""
	echo -e "  group_name=\"BA_users\""
	echo -e "  hierarchy_name=\"DEFAULT\""							
	echo -e "  exclude_list=\"table1,view3,table3\""	
}
### if less than one arguments supplied, display usage 
if [ $# -le 0 ]
then
	usage_msg
	exit 1
fi

config_file=$1

echo "==========================================================================================="
echo "==========================================================================================="
echo "(LOG) $(date):: Source Creator - START"

# open configuration files for input variables
source $config_file

echo "==== Input Variables                                                                     " >&2
echo "==== hostname=${hostname}                                                                " >&2
echo "==== source_connection_name=${source_connection_name}                                    " >&2
echo "==== schema_name=${schema_name}                                                          " >&2
echo "==== source_name=${source_name}                                                          " >&2
echo "==== base_dir=${base_dir}                                                                " >&2
echo "==== group_name=${group_name}                                                            " >&2
echo "==== hierarchy_name=${hierarchy_name}                                                    " >&2
echo "==== exclude_list=${exclude_list}                                                    " >&2

echo "==========================================================================================="
echo "== 1. New Source (click dropdown and select JDBC)                                        =="
echo "==========================================================================================="
echo "=== clean out all the previous temporay .json & .json-e files                            =="

## notice we only turn on quit on error after rm in case there are no .json / .json-e files to be remove.
rm ./logs/pd33_create*.json*

set -e

echo "=== get a new cookie for this session. usually cookie has a shell life of 30 minutes.    =="
curl -s -X POST ''"${hostname}"'/j_spring_security_check?j_username=podium&j_password=nvs2014!' -c ./cookie.txt

echo "=== source connections                                                                   =="
curl -s -X GET ''"${hostname}"'/srcConnection/sourceConnectionsPerSourceType/sourceType/JDBC' -b ./cookie.txt > ./logs/pd33_create_get_jdbc_sources.json

### user will pass in the source-connection name (i.e. PODIUM_ORACLE) we will check against the list above and get back the connection string.
### here we get all the objects from ONLY PODIUM_ORACLE source connection. we will need this to pass into next step (2. below) for "test connection"
### had issue constructing cmd with variable inside both single & double quotes. setup the cmd as a variable then eval it.
echo "=== select only to the source connection                                                 =="
tmp_cmd="jq '.[] | select(.name==\"$source_connection_name\")' ./logs/pd33_create_get_jdbc_sources.json > ./logs/pd33_create_get_ONLY_WANTED_jdbc_source_jq.json"
echo $tmp_cmd
eval $tmp_cmd

echo "=== get source connection id                                                             =="
tmp_cmd="jq '.[] | select(.name==\"$source_connection_name\")' ./logs/pd33_create_get_jdbc_sources.json | jq .id"
echo $tmp_cmd
cmd_srconnn_output=$(eval "$tmp_cmd")
echo $cmd_srconnn_output

echo "==========================================================================================="
echo "== 2. Click next to step 2                                                               =="
echo "==========================================================================================="
echo "=== update connection string                                                             =="
jq '.externalData' ./logs/pd33_create_get_ONLY_WANTED_jdbc_source_jq.json | jq '.["ddusername"] = ."conn.user.name"' | jq '.["ddtype"] = ."conn.jdbc.source.type"' | jq '.["ddpassword"] = ."conn.user.password"' | jq '.["ddurl"] = ."connection.string" | del(."conn.user.name", ."conn.jdbc.source.type", ."conn.user.password", ."connection.string")' > ./logs/pd33_create_get_SCHEMA_jdbc_source_jq.json

### here I need to unpretty the json response by jq when I select just the schema by calling jq again with -c.
echo "=== convert to un-pretty json format                                                     =="
tmp_cmd="curl -s -X POST '$hostname/discovery/findSources' -b ./cookie.txt -d @./logs/pd33_create_get_SCHEMA_jdbc_source_jq.json --header \"Content-Type: application/json\" | jq '.[] | select(.name==\"$schema_name\")' | jq -c . > ./logs/pd33_create_get_ONLY_WANTED_SCHEMA_jdbc_source_jq.json"
echo $tmp_cmd
eval $tmp_cmd

echo "=== need to add [ & ] in the beginning and end of json                                   =="
sed 's/^/[/' ./logs/pd33_create_get_ONLY_WANTED_SCHEMA_jdbc_source_jq.json | sed 's/$/]/' | jq . > ./logs/pd33_create_get_ONLY_WANTED_SCHEMA_jdbc_source_jq_2.json

echo "=== do we need to turn checked: false TO checked: true                                   =="
jq '.[].checked = "true"' ./logs/pd33_create_get_ONLY_WANTED_SCHEMA_jdbc_source_jq_2.json > ./logs/pd33_create_get_ONLY_WANTED_SCHEMA_jdbc_source_jq_3.json 

echo "==========================================================================================="
echo "== 3. Select schema $schema_name and hit next - returns with all entities in schema      =="
echo "==========================================================================================="
echo "=== get all entities from source conn & schema                                           =="
curl -s -X POST ''"${hostname}"'/discovery/findEntitiesBySources' -b ./cookie.txt -d @./logs/pd33_create_get_ONLY_WANTED_SCHEMA_jdbc_source_jq_3.json --header "Content-Type: application/json" | jq . > ./logs/pd33_create_get_ONLY_WANTED_SCHEMA_TABLES_jdbc_source_jq.json

echo "=== filter to the checked=false and change to true.                                      =="
sed -i -e 's/\"checked\": false,/\"checked\": true,/g' ./logs/pd33_create_get_ONLY_WANTED_SCHEMA_TABLES_jdbc_source_jq.json 

echo "=== loop thru exclude_list and set checked to false                                      =="
for i in $(echo $exclude_list | sed "s/,/ /g")
do
	# loop thru each element in the exclude_list array and turn checked from "true" to "false"
	# will put the jq logic here to update the element value
	echo "$i"	
	tmp_cmd="jq '[.[].discoveredEntities[] |= if (.name==\"$i\") then (.checked = \"false\") else . end]' ./logs/pd33_create_get_ONLY_WANTED_SCHEMA_TABLES_jdbc_source_jq.json > ./logs/pd33_create_get_ONLY_WANTED_SCHEMA_TABLES_jdbc_source_jq_2.json"
	echo $tmp_cmd
	eval $tmp_cmd
	sed '$d' < ./logs/pd33_create_get_ONLY_WANTED_SCHEMA_TABLES_jdbc_source_jq_2.json | sed "1d" > ./logs/pd33_create_get_ONLY_WANTED_SCHEMA_TABLES_jdbc_source_jq.json # remove 1st & last line, not sure why its adding [ ] to the file
done

echo "==========================================================================================="
echo "== 4. Select group & all entities, click next                                            =="
echo "===========================================================================================" 
echo "=== seems to work, same byte count                                                       =="
tmp_cmd="curl -s -X POST '$hostname/discovery/findFieldsBySources' -b ./cookie.txt -d @./logs/pd33_create_get_ONLY_WANTED_SCHEMA_TABLES_jdbc_source_jq.json --header \"Content-Type: application/json\" | jq . > ./logs/pd33_create_get_ONLY_WANTED_SCHEMA_TABLES_OUT_jdbc_source_jq.json"
echo $tmp_cmd
eval $tmp_cmd

echo "=== again need to change checked=false to true for fields         						=="
jq '.[].discoveredEntities[].discoveredFields[] |= (.checked = "true")' ./logs/pd33_create_get_ONLY_WANTED_SCHEMA_TABLES_OUT_jdbc_source_jq.json > ./logs/pd33_create_get_ONLY_WANTED_SCHEMA_TABLES_OUT_jdbc_source_jq_2.json          

echo "==========================================================================================="
echo "== 5. Click \"Save Selected\" (last step to create source + all entities)                =="
echo "===========================================================================================" 
echo "=== change the name to point to schema name in DB                                        =="
### p.s. there is a displayName object in the request json, it is actually the name of the db schame
tmp_cmd="sed -i -e 's/\"name\": \"$schema_name\",/\"name\": \"$source_name\",/g' ./logs/pd33_create_get_ONLY_WANTED_SCHEMA_TABLES_OUT_jdbc_source_jq_2.json"
echo $tmp_cmd
eval $tmp_cmd

echo "=== set baseDirectory                                                                    =="
tmp_cmd="sed -i -e 's/\"baseDirectory\": null,/\"baseDirectory\": \"$base_dir\",/g' ./logs/pd33_create_get_ONLY_WANTED_SCHEMA_TABLES_OUT_jdbc_source_jq_2.json"
echo $tmp_cmd
eval $tmp_cmd

echo "=== get & set hierarchy id based on hierarchy_name                                       =="
tmp_cmd="curl -s -X GET '$hostname/sourcehier/v1/getHiers' -b ./cookie.txt --header \"Accept: application/json\" | jq '.[] | select(.name==\"$hierarchy_name\")' | jq .id"
cmd_hier_output=$(eval "$tmp_cmd")
echo $cmd_hier_output

echo "=== update json to assign source to group                                                =="
tmp_cmd="curl -s -X GET '$hostname/security/group/v1/groupsByUser?count=500&sortAttr=name&sortDir=ASC' -b ./cookie.txt --header \"Accept: application/json\" | jq .subList | jq '.[] | select(.name==\"$group_name\") | del(.\"timeZoneOffset\", .\"origin\", .\"createdTs\")' > ./logs/pd33_create_groups.json"
echo $tmp_cmd
eval $tmp_cmd

echo "=== add group info into final json package prior to source save                          =="
jq --argjson groupInfo "$(<./logs/pd33_create_groups.json)" '.[].groups += [$groupInfo]' ./logs/pd33_create_get_ONLY_WANTED_SCHEMA_TABLES_OUT_jdbc_source_jq_2.json > ./logs/pd33_create_get_ONLY_WANTED_SCHEMA_TABLES_OUT_jdbc_source_jq_NEW.json

echo "=== Save the source podium object with all tables from the JDBC schema                   =="
tmp_cmd="curl -s -X PUT '$hostname/discovery/saveSources?hierId=$cmd_hier_output&sourceConnectionId=$cmd_srconnn_output' -b ./cookie.txt -d @./logs/pd33_create_get_ONLY_WANTED_SCHEMA_TABLES_OUT_jdbc_source_jq_NEW.json --header \"Content-Type: application/json\" | jq . > ./logs/pd33_create_create_source.json"
echo $tmp_cmd
eval $tmp_cmd

echo "(LOG) $(date):: Source Creator - END"
echo "==========================================================================================="
echo "==========================================================================================="


