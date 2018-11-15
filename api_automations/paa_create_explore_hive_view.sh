#!/bin/bash
###
### The goal of this script is to demonstrate Podium API capability to categorize and load data. Customers should perform all the necessary test against their 
### environments and requirements. This is not meant for Production use.
###
### the purpose of this script is to create Podium Explore object (Hive View).
### this script utilize number of json files to struct request & response payload. after each load, we should clean up all the .json & .json-e files.
### it requires jq utility (https://stedolan.github.io/jq/), jq is a very high-level functional programming language with support for backtracking and managing streams of JSON data.
###

usage_msg() {
	echo "This script will create Podium Explore object (Hive View)" 
	echo "prerequisites - jq (https://stedolan.github.io/jq/download/)"
	echo -e "\nUsage:\n bash ./paa_create_explore_hive_view.sh [arg: configuration file]"
	echo -e " [i.e.] #bash ./paa_create_explore_hive_view.sh ./conf/paa_create_explore_hive_view.conf > ./logs/paa_create_explore_hive_view.out 2>&1 &\n"	
	echo -e "  configuration file should contain the following variables"
	echo -e "  hostname=\"http://ludwig.podiumdata.com:8180/podium\""
	echo -e "  input_source_name=\"ally_mig_clo_orc_source_hello\""
	echo -e "  input_entity_name=\"dt_test\""	
	echo -e "  explore_source_name=\"ally_ingestions_clo_1033\""	
	echo -e "  explore_view_name=\"v_123\""
	echo -e "  cart_entity_sql=\"SELECT \`dt_test\`.\`my_name\` AS \`my_name\`,\`dt_test\`.\`created_date\` AS \`created_date\`,\`dt_test\`.\`EXT_podium_delivery_date\` AS \`EXT_podium_delivery_date\` FROM \`ally_mig_clo_orc_source_hello\`.\`dt_test\` \`dt_test\`\""
	echo -e "  group_name=\"BA_users\""	
	echo -e "  base_dir=\"/podiumbuild\""	
	echo -e "  hierarchy_name=\"DEFAULT\""
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

set -e

# open configuration files for input variables
source $config_file

echo "==== Config File=$config_file"
echo "==== Input Variables                                                                     " >&2
echo "==== hostname=${hostname}                                                                " >&2
echo "==== input_source_name=${input_source_name}                                              " >&2
echo "==== input_entity_name=${input_entity_name}                                              " >&2
echo "==== explore_source_name=${explore_source_name}                                          " >&2
echo "==== explore_view_name=${explore_view_name}                                              " >&2
echo "==== cart_entity_sql=${cart_entity_sql}                                                  " >&2
echo "==== group_name=${group_name}                                                            " >&2
echo "==== base_dir=${base_dir}                                                          	   " >&2
echo "==== hierarchy_name=${hierarchy_name}                                                    " >&2

echo "=== get a new cookie for this session. usually cookie has a shell life of 30 minutes.    =="
tmp_cmd="curl -s -X POST '${hostname}/j_spring_security_check?j_username=podium&j_password=nvs2014!' -c ./logs/cookie.txt"
echo $tmp_cmd
eval $tmp_cmd

###
### before loading we need to switch to sqoop for ingest connection source
###

echo "=== get entityId by source and entity name                                              =="
tmp_cmd="curl -s -X GET --header 'Accept: application/json' '$hostname/entity/v1/getEntitiesByCrit?entityName=$input_entity_name&srcName=$input_source_name&objType=INTERNAL' -b ./logs/cookie.txt | jq .[].id"
echo $tmp_cmd
cmd_ent_id=$(eval "$tmp_cmd")
echo "Input Entity $entity_name has ID: ${cmd_ent_id}"

echo "=== get sourceID info source name.                                                      =="
tmp_cmd="curl -s -X GET --header 'Accept: application/json' '$hostname/source/v1/getSources?type=INTERNAL&count=500&sortAttr=name&sortDir=ASC' -b ./logs/cookie.txt | jq . | jq '.subList[] | select(.name==\"$explore_source_name\") | .id'"
echo $tmp_cmd
cmd_source_id=$(eval "$tmp_cmd")
echo "Explore Source $input_source_name has ID : ${cmd_source_id}"

echo "=== get source info source name.                                                        =="
#tmp_cmd="curl -s -X GET --header 'Accept: application/json' '$hostname/source/v1/getSources?type=INTERNAL&count=500&sortAttr=name&sortDir=ASC' -b ./logs/cookie.txt | jq . | jq '.subList[] | select(.name==\"$explore_source_name\")' > ./logs/paa_create_explore_hive_view_source.json"
tmp_cmd="curl -s -X GET --header 'Accept: application/json' '$hostname/source/v1/getSources?type=INTERNAL&count=500&sortAttr=name&sortDir=ASC' -b ./logs/cookie.txt | jq . | jq '.subList[] | select(.name==\"$explore_source_name\")'"
echo $tmp_cmd
part_source_json=$(eval "$tmp_cmd")
echo "Part Source JSON: ${part_source_json}"

echo "=== get sourceHierarchy info   				                                          =="
#tmp_cmd="curl -s -X GET --header 'Accept: application/json' '$hostname/sourcehier/v1/getHiers' -b ./logs/cookie.txt | jq . | jq '.[] | select(.name==\"$hierarchy_name\")' > ./logs/paa_create_explore_hive_view_sourceHeir.json"
tmp_cmd="curl -s -X GET --header 'Accept: application/json' '$hostname/sourcehier/v1/getHiers' -b ./logs/cookie.txt | jq . | jq '.[] | select(.name==\"$hierarchy_name\")'"
echo $tmp_cmd
part_sourcehier_json=$(eval "$tmp_cmd")
echo "Part sourceHierarchy JSON: ${part_sourcehier_json}"

echo "=== get groups info  						                                              =="
#tmp_cmd="curl -s -X GET --header 'Accept: application/json' '$hostname/security/group/v1/groupsByUser?count=500&sortAttr=name&sortDir=ASC' -b ./logs/cookie.txt | jq . | jq '.subList[] | select(.name==\"$group_name\")' > ./logs/paa_create_explore_hive_view_groups.json"
tmp_cmd="curl -s -X GET --header 'Accept: application/json' '$hostname/security/group/v1/groupsByUser?count=500&sortAttr=name&sortDir=ASC' -b ./logs/cookie.txt | jq . | jq '.subList[] | select(.name==\"$group_name\")'"
echo $tmp_cmd
part_group_json=$(eval "$tmp_cmd")
echo "Part Group JSON: ${part_group_json}"

echo "=== construct request layload for addTargetInfoToCart using                             =="
echo "===   souce, sourceHierarchy and groups                                                 =="
tmp_cmd="echo '{\"dataSourceInfo\":{\"sourceHierarchy\":{}},\"groups\":[{}]}' | jq '.dataSourceInfo += $part_source_json' | jq '.dataSourceInfo.sourceHierarchy += $part_sourcehier_json' | jq '.groups[0] += $part_group_json' | jq . > ./logs/paa_create_explore_hive_view_addTargetInfoToCart.json"
echo $tmp_cmd
eval $tmp_cmd

echo "=========================================================================================="
echo "=== NOW we are ready to create explore view                                             =="
echo "===  1st open the explore canvas                                                        =="
tmp_cmd="curl -s -X PUT --header 'Accept: application/json' '$hostname/myCart/explore/all' -b ./logs/cookie.txt"
echo $tmp_cmd
eval $tmp_cmd
# PUT http://ludwig.podiumdata.com:8680/podium_34/myCart/explore/all
# curl -s -X PUT 'http://ludwig.podiumdata.com:8680/podium_34/myCart/explore/all' -b ~/Downloads/cookie.txt | jq .
# 	request payload: none
# 	response payload: none

echo "===  then add source step1                                                              =="
tmp_cmd="curl -s -X PUT '$hostname/explore/addFieldsForEntities' -b ./logs/cookie.txt --header 'Content-Type: application/json' --header 'Accept: application/json' -d '[$cmd_ent_id]' "
echo $tmp_cmd
eval $tmp_cmd
##### if there are more than 1 entity, its entered as an array like [1234,4567,7890]
# PUT http://ludwig.podiumdata.com:8680/podium_34/explore/addFieldsForEntities request payload [4087]
# curl -s -X PUT 'http://ludwig.podiumdata.com:8680/podium_34/explore/addFieldsForEntities' -b ~/Downloads/cookie.txt --header 'Content-Type: application/json' --header 'Accept: application/json' -d '[4087]' | jq .
# 	request payload: [4087]
# 	response payload: none

echo "===  Set Custom Query                                                                   =="
tmp_cmd="curl -s -X POST '$hostname/explore/setCustomQuery/' -b ./logs/cookie.txt --header 'Content-Type: application/json' --header 'Accept: application/json' -d '\"$cart_entity_sql\"' | jq ."

echo $tmp_cmd
custom_select_query=$(eval "$tmp_cmd")
echo "setCustomQuery: ${custom_select_query}"
# POST http://ludwig.podiumdata.com:8680/podium_34/explore/setCustomQuery/
# curl -s -X POST 'http://ludwig.podiumdata.com:8680/podium_34/explore/setCustomQuery/' -b ~/Downloads/cookie.txt | jq .
# 	request payload: none
# 	response payload: "SELECT `dt_test`.`my_name` AS `my_name`,`dt_test`.`created_date` AS `created_date`,`dt_test`.`EXT_podium_delivery_date` AS `EXT_podium_delivery_date` FROM `ally_mig_clo_orc_source_hello`.`dt_test` `dt_test` "

echo "===  then add source step2                                                              =="
tmp_cmd="curl -s -X POST '$hostname/explore/generateSelectQuery' -b ./logs/cookie.txt | jq ."
echo $tmp_cmd
gen_select_query=$(eval "$tmp_cmd")
echo "generateSelectQuery: ${gen_select_query}"
# POST http://ludwig.podiumdata.com:8680/podium_34/explore/generateSelectQuery
# curl -s -X POST 'http://ludwig.podiumdata.com:8680/podium_34/explore/generateSelectQuery' -b ~/Downloads/cookie.txt | jq .
# 	request payload: none
# 	response payload: "SELECT `dt_test`.`my_name` AS `my_name`,`dt_test`.`created_date` AS `created_date`,`dt_test`.`EXT_podium_delivery_date` AS `EXT_podium_delivery_date` FROM `ally_mig_clo_orc_source_hello`.`dt_test` `dt_test` "

echo "===  now add target step1                                                               =="
tmp_cmd="curl -s -X POST '$hostname/entity/validateInternalEntity?entityName=$explore_view_name&sourceId=$cmd_source_id&baseDirectory=undefined&sourceName=$explore_source_name' -b ./logs/cookie.txt | jq ."
echo $tmp_cmd
view_name=$(eval "$tmp_cmd")
echo "viewName: ${view_name}"
# POST http://ludwig.podiumdata.com:8680/podium_34/entity/validateInternalEntity?entityName=v_abcd&sourceId=573&baseDirectory=undefined&sourceName=ally_ingestions_clo_1033
# curl -s -X POST 'http://ludwig.podiumdata.com:8680/podium_34/entity/validateInternalEntity?entityName=v_abcd&sourceId=573&baseDirectory=undefined&sourceName=ally_ingestions_clo_1033' -b ~/Downloads/cookie.txt | jq .
# 	request payload: query string
# 	response payload: "v_haha"

echo "===  now add target step2                                                               =="
tmp_cmd="curl -s -X PUT '$hostname/explore/setViewName/$explore_view_name/$explore_source_name/false' -b ./logs/cookie.txt"
echo $tmp_cmd
cmd_output=$(eval "$tmp_cmd")
echo "$cmd_output"
# PUT http://ludwig.podiumdata.com:8680/podium_34/explore/setViewName/v_abc/ally_ingestions_clo_1033/false
# curl -s -X PUT 'http://ludwig.podiumdata.com:8680/podium_34/explore/setViewName/v_abc/ally_ingestions_clo_1033/false' -b ~/Downloads/cookie.txt | jq .
# 	request payload: none
# 	response payload: true

echo "===  now add target step3                                                               =="
tmp_cmd="curl -s -X PUT '$hostname/explore/addTargetInfoToCart' -b ./logs/cookie.txt --header 'Content-Type: application/json' --header 'Accept: application/json' -d @./logs/paa_create_explore_hive_view_addTargetInfoToCart.json | jq ."
echo $tmp_cmd
eval $tmp_cmd
# PUT http://ludwig.podiumdata.com:8680/podium_34/explore/addTargetInfoToCart 
# curl -s -X PUT 'http://ludwig.podiumdata.com:8680/podium_34/explore/addTargetInfoToCart' -b ~/Downloads/cookie.txt --header 'Content-Type: application/json' --header 'Accept: application/json' -d @/tmp/explore_addTargetInfoToCart.json | jq .
# 	request payload: {"dataSourceInfo":{"id":573,"version":0,"lastUpdTs":1539004043520,"timeZoneOffset":-14400000,"externalData":{"default.entity.level":"MANAGED"},"name":"ally_ingestions_clo_1033","sourceType":"PODIUM_INTERNAL","commProtocol":"JDBC","baseDirectory":"/podiumbuild","businessName":null,"businessDescription":null,"defaultLevel":"MANAGED","sourceHierarchy":{"id":1,"version":134,"createdTs":1528333237188,"createdBy":"ANONYMOUS","lastUpdTs":1540912027445,"modifiedBy":"podium","timeZoneOffset":-14400000,"name":"DEFAULT","childSourceHier":[],"dataSources":null,"sourceCount":0}},"groups":[{"id":2,"lastUpdTs":1528416207161,"name":"BA_users","version":0}]}
# 	response payload: none

echo "===  time to validate step1                                                            =="
tmp_cmd="curl -s -X PUT '$hostname/explore/setViewName/$explore_view_name/$explore_source_name/false' -b ./logs/cookie.txt | jq ."
echo $tmp_cmd
eval $tmp_cmd
# PUT http://ludwig.podiumdata.com:8680/podium_34/explore/setViewName/v_abc/ally_ingestions_clo_1033/false
# curl -s -X PUT 'http://ludwig.podiumdata.com:8680/podium_34/explore/setViewName/v_abcd/ally_ingestions_clo_1033/false' -b ~/Downloads/cookie.txt | jq .
# 	request payload: none
# 	response payload: true

echo "===  time to validate step2                                                            =="
tmp_cmd="curl -s -X POST '$hostname/explore/updateCartInfo?queryEngineType=HIVE&hCatType=VIEW' -b ./logs/cookie.txt | jq ."
echo $tmp_cmd
eval $tmp_cmd
# POST http://ludwig.podiumdata.com:8680/podium_34/explore/updateCartInfo?queryEngineType=HIVE&hCatType=VIEW
# curl -s -X POST 'http://ludwig.podiumdata.com:8680/podium_34/explore/updateCartInfo?queryEngineType=HIVE&hCatType=VIEW'  -b ~/Downloads/cookie.txt | jq .
# 	request payload: query string
# 	response payload: none

echo "===  time to validate step3                                                            =="
tmp_cmd="curl -s -X POST '$hostname/explore/validate/false' -b ./logs/cookie.txt | jq ."
echo $tmp_cmd
eval $tmp_cmd
# POST http://ludwig.podiumdata.com:8680/podium_34/explore/validate/false
# curl -s -X POST 'http://ludwig.podiumdata.com:8680/podium_34/explore/validate/false'  -b ~/Downloads/cookie.txt | jq .
# 	request payload: none
# 	response payload: ""

echo "===  Checkout.                                                                         =="
tmp_cmd="curl -s -X PUT '$hostname//explore/checkoutCart' -b ./logs/cookie.txt | jq ."
echo $tmp_cmd
cmd_output=$(eval "$tmp_cmd")
echo "$cmd_output"
# PUT http://ludwig.podiumdata.com:8680/podium_34/explore/checkoutCart
# curl -s -X PUT 'http://ludwig.podiumdata.com:8680/podium_34/explore/checkoutCart'  -b ~/Downloads/cookie.txt | jq .
# 	request payload: none
# 	response payload: {"objectType":"DataEntity","id":4116,"version":0,"createdTs":1541084178536,"createdBy":"podium","lastUpdTs":1541084178536,"modifiedBy":"podium","timeZoneOffset":-14400000,"properties":[{"id":null,"version":null,"timeZoneOffset":-14400000,"name":"cart.source.entities","value":"3882","displayName":"cart.source.entities","isRequired":false,"type":null,"nullable":false,"description":null},{"id":null,"version":null,"timeZoneOffset":-14400000,"name":"cart.entity.sql","value":"CREATE VIEW ally_ingestions_clo_1033.v_haha  TBLPROPERTIES('serialization.null.format'='')AS SELECT `dt_test`.`my_name` AS `my_name`,`dt_test`.`created_date` AS `created_date`,`dt_test`.`EXT_podium_delivery_date` AS `EXT_podium_delivery_date` FROM `ally_mig_clo_orc_source_hello`.`dt_test` `dt_test` ","displayName":"cart.entity.sql","isRequired":false,"type":null,"nullable":false,"description":null}],"name":"v_haha","businessName":null,"businessDescription":null,"props":[{"id":null,"version":null,"timeZoneOffset":-14400000,"name":"cart.entity.sql","value":"CREATE VIEW ally_ingestions_clo_1033.v_haha  TBLPROPERTIES('serialization.null.format'='')AS SELECT `dt_test`.`my_name` AS `my_name`,`dt_test`.`created_date` AS `created_date`,`dt_test`.`EXT_podium_delivery_date` AS `EXT_podium_delivery_date` FROM `ally_mig_clo_orc_source_hello`.`dt_test` `dt_test` "},{"id":null,"version":null,"timeZoneOffset":-14400000,"name":"cart.source.entities","value":"3882"}],"shortName":"v_haha","threshold":0.1,"entType":"USER","internalFileFormat":"TEXT_TAB_DELIMITED","sourceConnection":null,"entityTags":[]}

echo "(LOG) $(date):: Source Creator - END"
echo "==========================================================================================="
echo "==========================================================================================="



