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
	echo "This script will add ingest source connection for all entities within a Podium source (i.e. JDBC -> Sqoop)" 
	echo "prerequisites - jq (https://stedolan.github.io/jq/download/)"
	echo -e "\nUsage:\n bash ./paa_load_all_tables_in_source.sh [arg: configuration file]"
	echo -e " [i.e.] #bash ./paa_apply_ingest_src_conn.sh ./conf/paa_apply_ingest_src_conn.config > ./logs/paa_apply_ingest_src_conn.out 2>&1 &\n"	
	echo -e "  configuration file should contain the following variables"
	echo -e "  hostname=\"http://ludwig.podiumdata.com:8180/podium\""
	echo -e "  source_name=\"PD_clo_ally_ingest_migrate_2\""
	echo -e "  entity_name=\"creditcard_ods_cc_td_creditcard_info\""
	echo -e "  source_connection_name=\"postgres_sqoop_new\""
	echo -e "  record_layout=\"PARQUET\""
	echo -e "  sqoop_append=\"true\""
	echo -e "  sqoop_mappers_count=\"1\""
	echo -e "  sqoop_as_parquetfile=\"true\""
	echo -e "  sqoop_check_column=\"SOLICITATION_ID\""
	echo -e "  sqoop_fields_terminated_by=\"\001\""
	echo -e "  sqoop_hive_drop_import_delims=\"true\""
	echo -e "  sqoop_incremental=\"append\""
	echo -e "  sqoop_last_value=\"2\""
	echo -e "  sqoop_map_column_java=\"ACCOUNT_IDENTIFIER=String\""	
	echo -e "  sqoop_query=\"SELECT \"CLOSE_DATE\",\"SOLICITATION_ID\",\"ALLY_CUSTOMER_ID\",\"ACCOUNT_IDENTIFIER\" FROM PODIUM_ORACLE.\"ORA_TS6_2_BIGINT\" WHERE \$CONDITIONS\""
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
echo "==== entity_name=${entity_name}                                                          " >&2
echo "==== source_connection_name=${source_connection_name}                                    " >&2
echo "==== record_layout=${record_layout}                                    				   " >&2
echo "==== sqoop_append=${sqoop_append}                                    					   " >&2
echo "==== sqoop_mappers_count=${sqoop_mappers_count}                                    	   " >&2
echo "==== sqoop_as_parquetfile=${sqoop_as_parquetfile}                                    	   " >&2
echo "==== sqoop_check_column=${sqoop_check_column}                                    		   " >&2
echo "==== sqoop_fields_terminated_by=${sqoop_fields_terminated_by}                            " >&2
echo "==== sqoop_hive_drop_import_delims=${sqoop_hive_drop_import_delims}                      " >&2
echo "==== sqoop_incremental=${sqoop_incremental}                                    		   " >&2
echo "==== sqoop_last_value=${sqoop_last_value}                                    			   " >&2
echo "==== sqoop_map_column_java=${sqoop_map_column_java}                                      " >&2
echo "==== sqoop_query=${sqoop_query}                                    					   " >&2

echo "=== get a new cookie for this session. usually cookie has a shell life of 30 minutes.    =="
curl -s -X POST ''"${hostname}"'/j_spring_security_check?j_username=podium&j_password=nvs2014!' -c ./cookie.txt

###
### before loading we need to switch to sqoop for ingest connection source
###


echo "=== get source ID by source name.                                                        =="
tmp_cmd="curl -s -X GET --header 'Accept: application/json' '$hostname/source/v1/getSources?type=EXTERNAL&count=500&sortAttr=name&sortDir=ASC' -b ./cookie.txt | jq . | jq '.subList[] | select(.name==\"$source_name\") | .id'"
echo $tmp_cmd
cmd_src_id=$(eval "$tmp_cmd")
echo "Source $source_name has ID: ${cmd_src_id}"

echo "=== get entityId by source and entity name                                              =="
tmp_cmd="curl -s -X GET '$hostname/entity/v1/byParentId/$cmd_src_id?count=500&sortAttr=name&sortDir=ASC' -b ./cookie.txt --header \"Accept: application/json\" | jq . | jq '.subList[] | select(.name==\"$entity_name\") | .id'"
echo $tmp_cmd
cmd_ent_id=$(eval "$tmp_cmd")
echo "Entity $entity_name has ID: ${cmd_ent_id}"

echo "=== get the all source connection listing                                             =="
tmp_cmd="curl -s -X GET '$hostname/srcConnection/all/?count=100&start=0&sortAttr=lastUpdTs&sortDir=DESC' -b ./cookie.txt --header \"Accept: application/json\" | jq . | jq '.subList[] | select(.name==\"$source_connection_name\") | .id'"
echo $tmp_cmd
cmd_src_conn_id=$(eval "$tmp_cmd")
echo "Source Connection $source_connection_name has ID: ${cmd_src_conn_id}"


echo "=== get source connection details                                                     =="
tmp_cmd="curl -s -X GET '$hostname/srcConnection/$cmd_src_conn_id' -b ./cookie.txt --header \"Accept: application/json\" | jq . > ./logs/pd33_apply_ingest_src_conn_3.json"
echo $tmp_cmd
eval $tmp_cmd

jq '.groups=[]' ./logs/pd33_apply_ingest_src_conn_3.json | jq '.entities=[]' | jq '.isAssigned=false' > ./logs/pd33_apply_ingest_src_conn_4.json


echo "=== time to save entity with source connection                                        =="
tmp_cmd="curl -s -X PUT '$hostname/srcConnection/apply/$cmd_ent_id' -b ./cookie.txt -d @./logs/pd33_apply_ingest_src_conn_4.json --header \"Content-Type: application/json\" | jq . > ./logs/pd33_apply_ingest_src_conn_5.json"
echo $tmp_cmd
eval $tmp_cmd


echo "=== Now update SQOOP properties                                   					=="
echo "=== update entity property record.layout                         					    =="
tmp_cmd="curl -s -X POST -b ./cookie.txt --header \"Content-Type: application/json\" --header \"Accept: application/json\" -d '{ \"externalData\": {}, \"name\": \"record.layout\", \"value\": \"$record_layout\" }' '$hostname/entity/v2/updateProperty/$cmd_ent_id' | jq . > ./logs/pd33_apply_ingest_src_conn_6.json"
echo $tmp_cmd
eval $tmp_cmd

echo "=== update entity property sqoop.append                         					    =="
tmp_cmd="curl -s -X POST -b ./cookie.txt --header \"Content-Type: application/json\" --header \"Accept: application/json\" -d '{ \"externalData\": {}, \"name\": \"sqoop.append\", \"value\": \"\" }' '$hostname/entity/v2/updateProperty/$cmd_ent_id' | jq . > ./logs/pd33_apply_ingest_src_conn_6.json"
echo $tmp_cmd
eval $tmp_cmd

echo "=== update entity property sqoop.mappers.count                  					    =="
tmp_cmd="curl -s -X POST -b ./cookie.txt --header \"Content-Type: application/json\" --header \"Accept: application/json\" -d '{ \"externalData\": {}, \"name\": \"conn.sqoop.mappers.count\", \"value\": \"$sqoop_mappers_count\" }' '$hostname/entity/v2/updateProperty/$cmd_ent_id' | jq . > ./logs/pd33_apply_ingest_src_conn_6.json"
echo $tmp_cmd
eval $tmp_cmd

echo "=== update entity property sqoop.as-parquetfile                  					    =="
tmp_cmd="curl -s -X POST -b ./cookie.txt --header \"Content-Type: application/json\" --header \"Accept: application/json\" -d '{ \"externalData\": {}, \"name\": \"sqoop.as-parquetfile\", \"value\": \"\" }' '$hostname/entity/v2/updateProperty/$cmd_ent_id' | jq . > ./logs/pd33_apply_ingest_src_conn_6.json"
echo $tmp_cmd
eval $tmp_cmd

echo "=== update entity property sqoop.check-column                  					    =="
tmp_cmd="curl -s -X POST -b ./cookie.txt --header \"Content-Type: application/json\" --header \"Accept: application/json\" -d '{ \"externalData\": {}, \"name\": \"sqoop.check-column\", \"value\": \"$sqoop_check_column\" }' '$hostname/entity/v2/updateProperty/$cmd_ent_id' | jq . > ./logs/pd33_apply_ingest_src_conn_6.json"
echo $tmp_cmd
eval $tmp_cmd

echo "=== update entity property sqoop.fields-terminated-by                  			    =="
tmp_cmd="curl -s -X POST -b ./cookie.txt --header \"Content-Type: application/json\" --header \"Accept: application/json\" -d '{ \"externalData\": {}, \"name\": \"sqoop.fields-terminated-by\", \"value\": \"$sqoop_fields_terminated_by\" }' '$hostname/entity/v2/updateProperty/$cmd_ent_id' | jq . > ./logs/pd33_apply_ingest_src_conn_6.json"
echo $tmp_cmd
eval $tmp_cmd

echo "=== update entity property sqoop.hive-drop-import-delims                  			=="
tmp_cmd="curl -s -X POST -b ./cookie.txt --header \"Content-Type: application/json\" --header \"Accept: application/json\" -d '{ \"externalData\": {}, \"name\": \"sqoop.hive-drop-import-delims\", \"value\": \"\" }' '$hostname/entity/v2/updateProperty/$cmd_ent_id' | jq . > ./logs/pd33_apply_ingest_src_conn_6.json"
echo $tmp_cmd
eval $tmp_cmd

echo "=== update entity property sqoop.incremental                  						=="
tmp_cmd="curl -s -X POST -b ./cookie.txt --header \"Content-Type: application/json\" --header \"Accept: application/json\" -d '{ \"externalData\": {}, \"name\": \"sqoop.incremental\", \"value\": \"$sqoop_incremental\" }' '$hostname/entity/v2/updateProperty/$cmd_ent_id' | jq . > ./logs/pd33_apply_ingest_src_conn_6.json"
echo $tmp_cmd
eval $tmp_cmd

echo "=== update entity property sqoop.last-value  	                						=="
tmp_cmd="curl -s -X POST -b ./cookie.txt --header \"Content-Type: application/json\" --header \"Accept: application/json\" -d '{ \"externalData\": {}, \"name\": \"sqoop.last-value\", \"value\": \"$sqoop_last_value\" }' '$hostname/entity/v2/updateProperty/$cmd_ent_id' | jq . > ./logs/pd33_apply_ingest_src_conn_6.json"
echo $tmp_cmd
eval $tmp_cmd


echo "=== update entity property sqoop.map-column-java 	               						=="
tmp_cmd="curl -s -X POST -b ./cookie.txt --header \"Content-Type: application/json\" --header \"Accept: application/json\" -d '{ \"externalData\": {}, \"name\": \"sqoop.map-column-java\", \"value\": \"$sqoop_map_column_java\" }' '$hostname/entity/v2/updateProperty/$cmd_ent_id' | jq . > ./logs/pd33_apply_ingest_src_conn_6.json"
echo $tmp_cmd
eval $tmp_cmd

echo "=== update entity property sqoop.query 	 	                						=="
tmp_cmd="curl -s -X POST -b ./cookie.txt --header \"Content-Type: application/json\" --header \"Accept: application/json\" -d '{ \"externalData\": {}, \"name\": \"sqoop.query\", \"value\": \"$sqoop_query\" }' '$hostname/entity/v2/updateProperty/$cmd_ent_id' | jq . > ./logs/pd33_apply_ingest_src_conn_6.json"
echo $tmp_cmd
eval $tmp_cmd


# # get to the actual entity id(s), pipe that into another json to be call later. We still need to put in the UTC ISO datestamp for loadTime.
# # entity_id coming back with double quotes in the beginning and end of string, need to strip
# echo "=== create json for entity load with entityID                                            =="
# tmp_cmd="jq .subList ./logs/pd33_apply_ingest_src_conn_7.json | jq .[].id | jq -R '.' | sed 's/^.\(.*\).$/\1/'"
# echo $tmp_cmd
# cmd_ent_id=($(eval "$tmp_cmd"))


echo "(LOG) $(date):: Source Creator - END"
echo "==========================================================================================="
echo "==========================================================================================="