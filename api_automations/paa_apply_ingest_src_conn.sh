#!/bin/bash
###
### The goal of this script is to demonstrate Podium API capability to categorize and load data. Customers should perform all the necessary test against their 
### environments and requirements. This is not meant for Production use.
###
### the purpose of this script is add ingest source connection for all entities within a Podium source (i.e. JDBC -> Sqoop).
### this script utilize number of json files to struct request & response payload. after each load, we should clean up all the .json & .json-e files.
### it requires jq utility (https://stedolan.github.io/jq/), jq is a very high-level functional programming language with support for backtracking and managing streams of JSON data.
###

usage_msg() {
	echo "This script will automatically load all entities within a Podium source" 
	echo "prerequisites - jq (https://stedolan.github.io/jq/download/)"
	echo -e "\nUsage:\n bash ./pd33_load_all_tables_in_source.sh [arg: configuration file]"
	echo -e " [i.e.] #bash ./pd33_apply_ingest_src_conn.sh ./config/pd33_apply_ingest_src_conn.config > ./logs/pd33_apply_ingest_src_conn.out 2>&1 &\n"	
	echo -e "  configuration file should contain the following variables"
	echo -e "  hostname=\"http://ludwig.podiumdata.com:8180/podium\""
	echo -e "  source_name=\"RBI\""
	echo -e "  source_conn_name=\"ORALCE\""	
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
echo "==== source_name=${source_name}                                                          " >&2
echo "==== source_connection_name=${source_connection_name}                                    " >&2

echo "=== get a new cookie for this session. usually cookie has a shell life of 30 minutes.    =="
curl -s -X POST ''"${hostname}"'/j_spring_security_check?j_username=podium&j_password=nvs2014!' -c ./cookie.txt

###
### before loading we need to switch to sqoop for ingest connection source
###

# create a function to apply ingest source to entity
apply_ent_ingest_src () {

entity_id=$1;
    echo "=== entity_id is: $entity_id. =========================================================="

	echo "=== list all source connections                                                       =="
	tmp_cmd="curl -s -X GET '$hostname/entity/entityWithParentInfo/$entity_id?omitConnectionProps=false' -b ./cookie.txt --header \"Accept: application/json\" | jq . > ./logs/pd33_apply_ingest_src_conn_1.json"
	echo $tmp_cmd
	eval $tmp_cmd

	echo "=== get the all source connection listing                                             =="
	tmp_cmd="curl -s -X GET '$hostname/srcConnection/all/?count=100&start=0&sortAttr=lastUpdTs&sortDir=DESC' -b ./cookie.txt --header \"Accept: application/json\" | jq . > ./logs/pd33_apply_ingest_src_conn_2.json"
	echo $tmp_cmd
	eval $tmp_cmd

	echo "=== get the source connection ID by name                                              =="
	tmp_cmd="jq .subList ./logs/pd33_apply_ingest_src_conn_2.json | jq '.[] | select(.name==\"$source_connection_name\")' | jq .id" 
	echo $tmp_cmd
	cmd_src_conn_id=$(eval "$tmp_cmd")
	echo "source connection id: ${cmd_src_conn_id}"

	echo "=== get source connection details                                                     =="
	tmp_cmd="curl -s -X GET '$hostname/srcConnection/$cmd_src_conn_id' -b ./cookie.txt --header \"Accept: application/json\" | jq . > ./logs/pd33_apply_ingest_src_conn_3.json"
	echo $tmp_cmd
	eval $tmp_cmd

	jq '.groups=[]' ./logs/pd33_apply_ingest_src_conn_3.json | jq '.entities=[]' | jq '.isAssigned=false' > ./logs/pd33_apply_ingest_src_conn_4.json

	#for sqoop connection, we need to specific define schema in 
	echo "=== get it from src.file_glob                                                         =="
	tmp_cmd="curl -s -X GET --header 'Accept: application/json' '$hostname/entity/v1/getProperty/$entity_id/src.file.glob' -b ./cookie.txt | sed 's/^.*FROM //; s/\..*$//'"
	echo $tmp_cmd
	cmd_schema_name=$(eval "$tmp_cmd")
	echo "schema_name: ${cmd_schema_name}"

	#for some clients, we need to pass schema_name.table_name to conn.sqoop.table.name
	echo "=== get it from original.name (is table_name)                                        =="
	tmp_cmd="curl -s -X GET --header 'Accept: application/json' '$hostname/entity/v1/getProperty/$entity_id/original.name' -b ./cookie.txt | sed 's/.//;s/.$//'"
	echo $tmp_cmd
	cmd_table_name=$(eval "$tmp_cmd")
	echo "table_name: ${cmd_table_name}"

	passin_table_name=$cmd_schema_name
	passin_table_name+="."
	passin_table_name+=$cmd_table_name

	echo "passin_table_name: ${passin_table_name}"

	echo "=== time to save entity with source connection                                        =="
	tmp_cmd="curl -s -X PUT '$hostname/srcConnection/apply/$entity_id' -b ./cookie.txt -d @./logs/pd33_apply_ingest_src_conn_4.json --header \"Content-Type: application/json\" | jq . > ./logs/pd33_apply_ingest_src_conn_5.json"
	echo $tmp_cmd
	eval $tmp_cmd

#	echo "=== update entity property conn.sqoop.schema.name                                     =="
#	tmp_cmd="curl -s -X POST -b ./cookie.txt --header \"Content-Type: application/json\" --header \"Accept: application/json\" -d '{ \"externalData\": {}, \"name\": \"conn.sqoop.schema.name\", \"value\": \"$cmd_schema_name\" }' '$hostname/entity/v2/updateProperty/$entity_id' | jq . > ./logs/pd33_apply_ingest_src_conn_6.json"
#	echo $tmp_cmd
#	eval $tmp_cmd

	echo "=== update entity property default.field.allow.non.ascii.chars                        =="
	tmp_cmd="curl -s -X POST -b ./cookie.txt --header \"Content-Type: application/json\" --header \"Accept: application/json\" -d '{ \"externalData\": {}, \"name\": \"default.field.allow.non.ascii.chars\", \"value\": \"true\" }' '$hostname/entity/v2/updateProperty/$entity_id' | jq . > ./logs/pd33_apply_ingest_src_conn_6.json"
	echo $tmp_cmd
	eval $tmp_cmd

	echo "=== update entity property enable.archiving                        					=="
	tmp_cmd="curl -s -X POST -b ./cookie.txt --header \"Content-Type: application/json\" --header \"Accept: application/json\" -d '{ \"externalData\": {}, \"name\": \"enable.archiving\", \"value\": \"false\" }' '$hostname/entity/v2/updateProperty/$entity_id' | jq . > ./logs/pd33_apply_ingest_src_conn_6.json"
	echo $tmp_cmd
	eval $tmp_cmd

	echo "=== update entity property conn.sqoop.table.name                        				=="
	tmp_cmd="curl -s -X POST -b ./cookie.txt --header \"Content-Type: application/json\" --header \"Accept: application/json\" -d '{ \"externalData\": {}, \"name\": \"conn.sqoop.table.name\", \"value\": \"$passin_table_name\" }' '$hostname/entity/v2/updateProperty/$entity_id' | jq . > ./logs/pd33_apply_ingest_src_conn_6.json"
	echo $tmp_cmd
	eval $tmp_cmd
}

echo "=== loop thru all entities within a scource and apply ingest source connection ============"
echo "=== get back all Podium source.                                                          =="
curl -s -X GET ''"${hostname}"'/source/v1/getSources?type=EXTERNAL&count=500&sortAttr=name&sortDir=ASC' -b ./cookie.txt | jq . > ./logs/pd33_load_all_get_sources.json

echo "=== get source id                                                                        =="
tmp_cmd="jq .[] ./logs/pd33_load_all_get_sources.json | jq '.[] | select(.name==\"$source_name\")' | jq .id"                                                             
echo $tmp_cmd
cmd_src_id=$(eval "$tmp_cmd")
echo "source id: ${cmd_src_id}"

echo "=== get entit(ies) by source                                                             =="
tmp_cmd="curl -s -X GET '$hostname/entity/v1/byParentId/$cmd_src_id?count=500&sortAttr=name&sortDir=ASC' -b ./cookie.txt --header \"Accept: application/json\" | jq . > ./logs/pd33_apply_ingest_src_conn_7.json"
echo $tmp_cmd
eval $tmp_cmd

# get to the actual entity id(s), pipe that into another json to be call later. We still need to put in the UTC ISO datestamp for loadTime.
# entity_id coming back with double quotes in the beginning and end of string, need to strip
echo "=== create json for entity load with entityID                                            =="
tmp_cmd="jq .subList ./logs/pd33_apply_ingest_src_conn_7.json | jq .[].id | jq -R '.' | sed 's/^.\(.*\).$/\1/'"
echo $tmp_cmd
cmd_ent_id=($(eval "$tmp_cmd"))

for i in "${!cmd_ent_id[@]}";
do
	echo "apply ingest source connection to entity_id:: ${cmd_ent_id[$i]}"
	apply_ent_ingest_src ${cmd_ent_id[$i]}
done

echo "(LOG) $(date):: Source Creator - END"
echo "==========================================================================================="
echo "==========================================================================================="