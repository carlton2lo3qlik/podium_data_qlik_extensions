#!/bin/bash
###
### The goal of this script is to demonstrate Podium API capability to categorize and load data. Customers should perform all the necessary test against their 
### environments and requirements. This is not meant for Production use.
###
### the purpose of this script is to automatically detect new tables and create Podium entities within a Podium source
### this script utilize number of json files to struct request & response payload. after each load, we should clean up all the .json & .json-e files.
### it requires jq utility (https://stedolan.github.io/jq/), jq is a very high-level functional programming language with support for backtracking and managing streams of JSON data.
###

usage_msg() {
	echo "This script will automatically detect new tables and create Podium entities within a Podium source" 
	echo "prerequisites - jq (https://stedolan.github.io/jq/download/)"
	echo -e "\nUsage:\n bash ./pd33_detect_new_tables_in_source.sh [arg: configuration file]"
	echo -e " [i.e.] #bash ./pd33_detect_new_tables_in_source.sh ./config/pd33_detect_new_tables_in_source.config > ./logs/pd33_detect_new_tables_in_source.out 2>&1 &\n"	
	echo -e "  configuration file should contain the following variables"
	echo -e "  hostname=\"http://ludwig.podiumdata.com:8180/podium\""
	echo -e "  source_name=\"RBI\""
	echo -e "  base_dir=\"\/podiumbuild\""	
	echo -e "  group_name=\"BA_users\""	
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
echo "(LOG) $(date):: Entity Dectector - START"

# open configuration files for input variables
source $config_file

echo "==== Input Variables                                                                     " >&2
echo "==== hostname=${hostname}                                                                " >&2
echo "==== source_name=${source_name}                                                          " >&2
echo "==== base_dir=${base_dir}                                                                " >&2
echo "==== group_name=${group_name}                                                            " >&2

echo "=== clean out all the previous temporay .json & .json-e files                            =="
### notice we only turn on quit on error after rm in case there are no .json / .json-e files to be remove.
rm ./logs/pd33_detect*.json*

set -e

echo "=== get a new cookie for this session. usually cookie has a shell life of 30 minutes.    =="
curl -s -X POST ''"${hostname}"'/j_spring_security_check?j_username=podium&j_password=nvs2014!' -c ./cookie.txt

echo "=== get back all Podium source.                                                          =="
curl -s -X GET ''"${hostname}"'/source/v1/getSources?type=EXTERNAL&count=500&sortAttr=name&sortDir=ASC' -b ./cookie.txt | jq . > ./logs/pd33_detect_load_all_get_sources.json

echo "=== get source id.                                                                       =="
tmp_cmd="jq .[] ./logs/pd33_detect_load_all_get_sources.json | jq '.[] | select(.name==\"$source_name\")' | jq .id"                                                             
echo $tmp_cmd
cmd_src_id=$(eval "$tmp_cmd")
echo "source id: ${cmd_src_id}"

echo "=== edit source - to add entities                                                         =="
tmp_cmd="curl -s -X GET '$hostname/discovery/editSource/${cmd_src_id}' -b ./cookie.txt --header \"Content-Type: application/json\" | jq . > ./logs/pd33_detect_new_tab_edit_source.json"
echo $tmp_cmd
eval $tmp_cmd


echo "=== change checked=false to checked=true                                                  =="
sed -i -e 's/\"checked\": false,/\"checked\": true,/g' ./logs/pd33_detect_new_tab_edit_source.json 

### check new entities then click (2 calls)
tmp_cmd="curl -s -X POST '$hostname/discovery/findFieldsBySources' -b ./cookie.txt --header \"Content-Type: application/json\" -d @./logs/pd33_detect_new_tab_edit_source.json | jq . > ./logs/pd33_detect_new_tab_chk_entity.json"
echo $tmp_cmd
eval $tmp_cmd


echo "=== change checked=false to checked=true                                                  =="
sed -i -e 's/\"checked\": false,/\"checked\": true,/g' ./logs/pd33_detect_new_tab_chk_entity.json 

echo "=== set baseDirectory                                                                     =="
tmp_cmd="sed -i -e 's/\"baseDirectory\": null,/\"baseDirectory\": \"$base_dir\",/g' ./logs/pd33_detect_new_tab_chk_entity.json"
echo $tmp_cmd
eval $tmp_cmd

echo "=== get group into another json                                                           =="
tmp_cmd="curl -s -X GET '$hostname/security/group/v1/groupsByUser?count=500&sortAttr=name&sortDir=ASC' -b ./cookie.txt --header \"Accept: application/json\" | jq .subList | jq '.[] | select(.name==\"$group_name\") | del(.\"timeZoneOffset\", .\"origin\", .\"createdTs\")' > ./logs/pd33_detect_new_tab_groups.json"
echo $tmp_cmd
eval $tmp_cmd

echo "=== add group info into final json package prior to source save                           =="
jq --argjson groupInfo "$(<./logs/pd33_detect_new_tab_groups.json)" '.[].groups += [$groupInfo]' ./logs/pd33_detect_new_tab_chk_entity.json > ./logs/pd33_detect_new_tab_save_source.json

echo "=== update source name                                                                    =="
tmp_cmd="jq  '.[].name = \"$source_name\"' ./logs/pd33_detect_new_tab_save_source.json > ./logs/pd33_detect_new_tab_ready_save.json"
echo $tmp_cmd
eval $tmp_cmd

echo "=== now save new entities                                                                =="
tmp_cmd="curl -s -X PUT '$hostname/discovery/saveSourceWithMoreEntities' -b ./cookie.txt --header \"Content-Type: application/json\" -d @./logs/pd33_detect_new_tab_ready_save.json | jq . > ./logs/pd33_detect_new_tab_complete.json"
echo $tmp_cmd
eval $tmp_cmd

echo "(LOG) $(date):: Entity Dectector - END"
echo "==========================================================================================="
echo "==========================================================================================="
