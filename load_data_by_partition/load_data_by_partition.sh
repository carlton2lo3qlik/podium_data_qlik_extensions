#!/bin/bash
#
# 2018/08/27
# load_data_by_partition.sh
#

#######
## 
## 3.3   -- http://ludwig.podiumdata.com:8180/podium/
## Source Name: podium_core_johnr_training Entity Name: pd_field_pc_rel
##
#######
## 
## The script will load data from a specified table 
## In the event that the goal of the ingest is to partition the source data by date
## This script can be used to extract data from the source table by date.
## 
## The target partition is determined by querying a date or timestamp field on the source table
## 
#######

##3.3
hostname="http://ludwig.podiumdata.com:8180/podium";
##3.3
apiclientlocation="/usr/local/podium/podium_33/podium/lib";
##3.3
podiumjarlocation="/usr/local/podium/podium_33/podium/lib";
##3.3
hiveconnection="jdbc:hive2://bambi.corp.podiumdata.com:10000/default";

sourcename="None Specified";
sourceflag="False";
entityname="None Specified";
entityflag="False";
partfieldname="None Specified";
partfieldflag="False";

execname=`basename $0`;

curr_date=`date '+%Y%m%d'`;
curr_ts=`date '+%Y%m%d%H%M%S'`;

USAGE="USAGE:\n	$execname -s sourcename -e entityname [-p partition_field_name]
	Both -s sourcename and -e entityname must be provided
	Loading by Date Partition
		If \"-p partition_field_name\" is provided the script will select the distinct values from that field and attempt to partition the data in Podium using it. 
		Otherwise All Data will be loaded into a single partition"
	
while getopts :s:e:p: option
do 
	case "$option" in
		s) sourceflag="True"; sourcename="$OPTARG";;
		e) entityflag="True"; entityname="$OPTARG";;
		p) partfieldflag="True"; partfieldname="$OPTARG";;
		:) echo "Option -$OPTARG requires an argument."; echo; echo -e "$USAGE" >&2; exit 1;;
		\?) echo "Invalid option: -$OPTARG"; echo; echo -e "$USAGE" >&2; exit 1;;
	esac
done

if [ $sourceflag = "False" ] || [ $sourcename = "None Specified" ]
then
	echo;echo;echo -e "$USAGE";echo;echo;
	exit 1
fi 

if [ $entityflag = "False" ] || [ $entityname = "None Specified" ]
then
	echo;echo;echo -e "$USAGE";echo;echo;
	exit 1
fi 

if [ $partfieldflag = "True" ] && [ $partfieldname = "None Specified" ]
then
	echo;echo;echo -e "$USAGE";echo;echo;
	exit 1
elif [ $partfieldflag = "True" ] && [ $partfieldname != "None Specified" ]
then
	part_message="Data will be loaded by partition on ${partfieldname}";
else	
	part_message="All Data will be loaded without partitioning";
fi 

echo;echo;echo "$execname is being executed with the following parameters:";
echo "    hostname      = $hostname";
echo "    sourcename    = $sourcename";
echo "    entityname    = $entityname";
echo "    curr_ts       = $curr_ts";
echo "    partfieldname = $partfieldname";
echo "    ${part_message}";
echo; echo; echo;

# establish session for API calls
## Set variables
### Make Changes Here
cookiefile="./logs/podium_cookie_${curr_ts}.txt";
pd_user="podium"; # echo $pd_user;
pd_pass='nvs2014!'; # echo $pd_pass;

## Establish session
### Make Changes Here
connect_log="./logs/podium_connect.log";
rm -f ${connect_log}

curl -X POST ''"${hostname}"'/j_spring_security_check?j_username='"${pd_user}"'&j_password='"${pd_pass}"'' -v -w "%{http_connect}" -c $cookiefile > ${connect_log} 2>&1


error_text=`grep -i location ${connect_log}`;

if [[ -z "$error_text" || $error_text = *"error"* ]]
then 
	echo "Cannot Connect to ${hostname}"; 
	exit 1;
fi

get_Partition_Dates () {
#	beeline -u $hivedbname --showHeader=false --outputformat=csv2 --silent=true --showWarnings=false --verbose=false -f ${alter_stmt_file};
#	beeline -u $hiveconnection --showHeader=false --outputformat=csv2 --silent=true --showWarnings=false --verbose=false -e 'select * from johnr_podium_test.test_cdc' 

#	sourcename="johnr_podium_test";
#	entityname="test_cdc";
	partition_field_name=$partfieldname;

	part_select_query="select distinct(${partition_field_name}) from ${sourcename}.${entityname};"
#       part_select_query="select distinct(to_char(${partition_field_name}, 'YYYYMMDD HH24:MI:SS.MS')) from ${sourcename}.${entityname};"
	part_date_sql="./logs/${sourcename}_${entityname}_part_dates_${curr_ts}.sql";
	
	echo ${part_select_query} > ${part_date_sql};

	part_date_file="./logs/${sourcename}_${entityname}_part_dates_${curr_ts}.dat";
	
	beeline -u ${hiveconnection} --showHeader=false --outputformat=csv2 --silent=true --showWarnings=false --verbose=false -f ${part_date_sql} | grep -v '^ *$' > ${part_date_file}

	count=0;
	while  IFS='' read -r line || [[ -n "$line" ]]; do

		let count++;
                echo "================================================================================="
		echo "Found partition values: Number ${count}: $line";
		echo "================================================================================="
		
	        #for some clients, we need to pass schema_name.table_name to conn.sqoop.table.name
	        echo "    === get entityID by searching Source & Entity name =========================="
        	tmp_cmd="curl -s -X GET --header 'Accept: application/json' '$hostname/entity/v1/getEntitiesByCrit?entityName=$entityname&srcName=$sourcename&objType=EXTERNAL' -b $cookiefile | jq .[].id"
        	echo "    $tmp_cmd"
        	cmd_ent_id=$(eval "$tmp_cmd")
        	echo "    $cmd_ent_id"

        	# get the src.file.glob before append WHERE clause
        	echo "    === get src.file.glob ======================================================="
        	tmp_cmd="curl -s -X GET --header 'Accept: application/json' '$hostname/entity/v1/getProperty/$cmd_ent_id/src.file.glob' -b $cookiefile" 
        	echo "    $tmp_cmd"
        	cmd_src_file_glob=$(eval $tmp_cmd)
        	#echo $cmd_src_file_glob
        	new_cmd_src_file_glob="$(echo $cmd_src_file_glob | sed 's/\\//g' | sed 's/\"//g')"
        	#echo $new_cmd_src_file_glob
        	fin_cmd_src_file_glob="$(echo $new_cmd_src_file_glob " WHERE ${partition_field_name} = \"$line\"")"
        	echo "    $fin_cmd_src_file_glob"
		
		#date -d "$line";
		
		echo "    === data load request payload ==============================================="
		part_date="$(echo $line | cut -d ' ' -f 1)"
		part_time="$(echo $line | cut -d ' ' -f 2)"
		echo "    $part_date --> {"loadTime":"${part_date}T${part_time}Z","entityId":3304}"

		echo "    === here we send in the API request to load ================================="
		tmp_cmd="curl -s -X PUT --header 'Content-Type: application/json' --header 'Accept: application/json' -d '{\"loadTime\":\"${part_date}T${part_time}Z\", \"entityId\":$cmd_ent_id}' '$hostname/entity/v1/loadDataForEntity/true' -b $cookiefile | jq . > ./logs/load_${sourcename}_${entityname}_${part_date}_${part_time}.json"
		echo "    $tmp_cmd"
		cmd_output=$(eval "$tmp_cmd")

	done < ${part_date_file}
}


get_Partition_Dates;

exit 0;

