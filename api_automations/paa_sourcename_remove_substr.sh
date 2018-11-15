#!/bin/bash
###
### The goal of this script is to demonstrate Podium API capability to categorize and load data. Customers should perform all the necessary test against their 
### environments and requirements. This is not meant for Production use.
###
### the purpose of this script is to remove substring witin podium source name. for example, given substing 'PD_', this script will loop thru all source names, identify names with 'PD_' 
### and remove it from the name, i.e. 
###    source names prior; PD_CUSTOMER, PD_ACCOUNT, BILLS
###	   source names post;  CUSTOMER, ACCOUNT, BILLS
###
### this script utilize number of json files to struct request & response payload. after each load, we should clean up all the .json & .json-e files.
### it requires jq utility (https://stedolan.github.io/jq/), jq is a very high-level functional programming language with support for backtracking and managing streams of JSON data.
###

usage_msg() {
	echo "This script remove substring witin podium source name." 
	echo "prerequisites - jq (https://stedolan.github.io/jq/download/)"
	echo -e "\nUsage:\n bash ./paa_sourcename_remove_substr.sh [arg: configuration file]"
	echo -e " [i.e.] #bash ./paa_sourcename_remove_substr.sh ./config/paa_sourcename_remove_substr.config > ./logs/paa_sourcename_remove_substr.out 2>&1 &\n"	
	echo -e "  configuration file should contain the following variables"
	echo -e "  hostname=\"http://ludwig.podiumdata.com:8180/podium\""
	echo -e "  remove_substr=\"PD_\""
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
echo "(LOG) $(date):: SourceName Remove Subtsr - START"

# open configuration files for input variables
source $config_file

#remove_substr="ERS_"

echo "==== Input Variables                                                                     " >&2
echo "==== hostname=${hostname}                                                                " >&2
echo "==== remove_substr=${remove_substr}                                                      " >&2

echo "==========================================================================================="
echo "== 1. Get all Source name                                                                =="
echo "==========================================================================================="
echo "=== clean out all the previous temporay .json & .json-e files                            =="

## notice we only turn on quit on error after rm in case there are no .json / .json-e files to be remove.
rm ./logs/pd33_sourcename_remove_substr*.json*

set -e

echo "=== get a new cookie for this session. usually cookie has a shell life of 30 minutes.    =="
curl -s -X POST ''"${hostname}"'/j_spring_security_check?j_username=podium&j_password=nvs2014!' -c ./cookie.txt

echo "=== get sourceId for the sourcename with substr                                          =="
echo "==========================================================================================="
# 	curl -s -X GET 'http://ludwig.podiumdata.com:8680/podium_34/source/external/?count=10&start=0&sortAttr=lastUpdTs&sortDir=DESC' -b ~/Downloads/	cookie.txt | jq . > ./get_all_source_response.json
tmp_cmd="curl -s -X GET '$hostname/source/external/?start=0&sortAttr=lastUpdTs&sortDir=DESC' -b ./cookie.txt | jq '.subList[] | select(.name | contains(\"${remove_substr}\")) | .id'"
echo $tmp_cmd
src_ids=$(eval "$tmp_cmd")
echo $src_ids

echo "=== loop thru src_ids, remove subtsr from sourcename and save.                           =="
echo "==========================================================================================="
for i in $(echo $src_ids)
do
	# loop thru each element in the src_ids array"
	# will put the jq logic here to update the element value

	echo "---------------------------------------------------------------------------------------"	
	echo "=== get source general info for srcId: $i                                            =="
	tmp_cmd="curl -s -X GET '$hostname/source/getSource/$i?bLoadHierarchy=true' -b ./cookie.txt | jq . > ./logs/pd33_sourcename_remove_substr_get_source_general_response_$i.json"
	echo $tmp_cmd
	eval $tmp_cmd

	tmp_cmd="jq .name ./logs/pd33_sourcename_remove_substr_get_source_general_response_$i.json | sed 's/^.\(.*\).$/\1/' | sed 's/\\${remove_substr}//g'"
	echo $tmp_cmd
	new_src_name=$(eval "$tmp_cmd")
	echo "found sourcename: $(eval "jq .name ./logs/pd33_sourcename_remove_substr_get_source_general_response_$i.json")"
	echo "remove subtsr $remove_substr new sourcename: $new_src_name"

	echo "=== update sourcename in: ./logs/pd33_sourcename_remove_substr_get_source_general_response_$i.json        =="
	tmp_cmd="jq '. | (.name=\"$new_src_name\")' ./logs/pd33_sourcename_remove_substr_get_source_general_response_$i.json | jq . > ./logs/pd33_sourcename_remove_substr_save_source_general_request_$i.json"
	echo $tmp_cmd
	eval $tmp_cmd

	echo "=== save sourcename for srcId: $i                                                   =="
	tmp_cmd="curl -s -X PUT '$hostname/source/save?&bLoadHierarchy=true' -b ./cookie.txt -d @./logs/pd33_sourcename_remove_substr_save_source_general_request_$i.json --header \"Content-Type: application/json\" | jq . > ./logs/pd33_sourcename_remove_substr_save_source_general_response_$i.json"
	echo $tmp_cmd
	eval $tmp_cmd
	echo "---------------------------------------------------------------------------------------"

done

echo "(LOG) $(date):: SourceName Remove Subtsr - END"
echo "==========================================================================================="
echo "==========================================================================================="


