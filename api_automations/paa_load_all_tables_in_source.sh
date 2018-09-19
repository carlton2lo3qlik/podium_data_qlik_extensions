#!/bin/bash
###
### The goal of this script is to demonstrate Podium API capability to categorize and load data. Customers should perform all the necessary test against their 
### environments and requirements. This is not meant for Production use.
###
### The purpose of this script is automatically load all entities within a Podium source
### This script utilize number of json files to struct request & response payload. after each load, we should clean up all the .json & .json-e files.
### it requires jq utility (https://stedolan.github.io/jq/), jq is a very high-level functional programming language with support for backtracking and managing streams of JSON data.
###

usage_msg() {
	echo "This script will automatically load all entities within a Podium source" 
	echo "prerequisites - jq (https://stedolan.github.io/jq/download/)"
	echo -e "\nUsage:\n bash ./pd33_load_all_tables_in_source.sh [arg: configuration file]"
	echo -e " [i.e.] #bash ./pd33_load_all_tables_in_source.sh ./config/pd33_load_all_tables_in_source.config > ./logs/pd33_load_all_tables_in_source.out 2>&1 &\n"	
	echo -e "  configuration file should contain the following variables"
	echo -e "  hostname=\"http://ludwig.podiumdata.com:8180/podium\""
	echo -e "  source_name=\"RBI\""
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
echo "==== source_name=${source_name}                                                          " >&2

echo "=== clean out all the previous temporay .json & .json-e files                            =="
### notice we only turn on quit on error after rm in case there are no .json / .json-e files to be remove.
rm ./logs/pd33_load*.json*

set -e

echo "=== get a new cookie for this session. usually cookie has a shell life of 30 minutes.    =="
curl -s -X POST ''"${hostname}"'/j_spring_security_check?j_username=podium&j_password=nvs2014!' -c ./cookie.txt

echo "=== get back all Podium source.                                                          =="
curl -s -X GET ''"${hostname}"'/source/v1/getSources?type=EXTERNAL&count=500&sortAttr=name&sortDir=ASC' -b ./cookie.txt | jq . > ./logs/pd33_load_all_get_sources.json

echo "=== get source id.                                                                       =="
tmp_cmd="jq .[] ./logs/pd33_load_all_get_sources.json | jq '.[] | select(.name==\"$source_name\")' | jq .id"                                                             
echo $tmp_cmd
cmd_src_id=$(eval "$tmp_cmd")
echo "source id: ${cmd_src_id}"

echo "=== get entit(ies) by source                                                             =="
tmp_cmd="curl -s -X GET '$hostname/entity/v1/byParentId/$cmd_src_id?count=500&sortAttr=name&sortDir=ASC' -b ./cookie.txt --header \"Accept: application/json\" | jq . > ./logs/pd33_load_all_get_entities.json"
echo $tmp_cmd
eval $tmp_cmd

# get to the actual entity id(s), pipe that into another json to be call later. We still need to put in the UTC ISO datestamp for loadTime.
echo "=== create json for entity load with entityID                                            =="
loadTime=$(date -u +%FT%TZ)
tmp_cmd="jq .subList ./logs/pd33_load_all_get_entities.json | jq .[].id | jq -R '.' | jq -s 'map({entityId:.,loadTime:\"$loadTime\"})' > ./logs/pd33_load_all_start.json"
echo $tmp_cmd
eval $tmp_cmd

echo "=== send in request to load entities                                                   =="
tmp_cmd="curl -s -X PUT '$hostname/entity/loadDataForEntities/true' -b ./cookie.txt -d @./logs/pd33_load_all_start.json --header \"Content-Type: application/json\" | jq . > ./logs/pd33_load_all.json"
echo $tmp_cmd
eval $tmp_cmd

echo "(LOG) $(date):: Source Creator - END"
echo "==========================================================================================="
echo "==========================================================================================="
