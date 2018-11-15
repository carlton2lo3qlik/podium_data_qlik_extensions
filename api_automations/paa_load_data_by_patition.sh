#!/bin/bash
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
hostname="http://ludwig.podiumdata.com:8680/podium_34";
hiveconnection="jdbc:hive2://bambi.corp.podiumdata.com:10000/default";

sourcename="None Specified";
sourceflag="False";
entityname="None Specified";
entityflag="False";
partfieldname="None Specified";
partfieldflag="False";
partfieldformat="None Specified";
partfieldformatflag="False";

execname=`basename $0`;

curr_date=`date '+%Y%m%d'`;
curr_ts=`date '+%Y%m%d%H%M%S'`;

USAGE="USAGE:\n	$execname -s sourcename -e entityname [-p partition_field_name -f partition_field_format]
	Both -s sourcename and -e entityname must be provided
	Loading by Date Partition
		If \"-p partition_field_name\" is provided the script will select the distinct values from that field and attempt to partition the data in Podium using it. 
		Otherwise All Data will be loaded into a single partition
                \"-f partition_field_format\" accepts these 4 types;
                   1. \"Timestamp\"
                   2. \"BigInt\" as Unix Timestamp (aka Epoch)
                   3. Varchar (\"YYYYMM\")
                   4. Varchar (\"YYYYMMDD\")"
	
while getopts :s:e:p:f: option
do 
	case "$option" in
		s) sourceflag="True"; sourcename="$OPTARG";;
		e) entityflag="True"; entityname="$OPTARG";;
		p) partfieldflag="True"; partfieldname="$OPTARG";;
                f) partfieldformatflag="True"; partfieldformat="$OPTARG";;
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

if [ $partfieldformatflag = "True" ] && [ $partfieldformat = "None Specified" ]
then
        echo;echo;echo -e "$USAGE";echo;echo;
        exit 1
elif [ $partfieldformatflag = "True" ] && [ $partfieldformat != "None Specified" ]
then
        part_message="Data will be loaded by partition using format ${partfieldformat}";
else
        part_message="All Data will be loaded without partitioning format";
fi


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

echo "========================================================================================="
echo "=========================== BEGIN $(date) ==============================================="
echo "=== get entityID by searching Source & Entity name ======================================"
tmp_cmd="curl -s -X GET --header 'Accept: application/json' '$hostname/entity/v1/getEntitiesByCrit?entityName=$entityname&srcName=$sourcename&objType=EXTERNAL' -b $cookiefile | jq .[].id"
echo "    $tmp_cmd"
cmd_ent_id=$(eval "$tmp_cmd")
echo "    $cmd_ent_id"


echo "=== get src.file.glob ==================================================================="
tmp_cmd="curl -s -X GET --header 'Accept: application/json' '$hostname/entity/v1/getProperty/$cmd_ent_id/src.file.glob' -b $cookiefile | sed 's/^.\(.*\).$/\1/'"
echo "    $tmp_cmd"
cmd_src_file_glob=$(eval $tmp_cmd)

echo;echo;echo "$execname is being executed with the following parameters:";
echo "    hostname      = $hostname";
echo "    sourcename    = $sourcename";
echo "    entityname    = $entityname";
echo "    curr_ts       = $curr_ts";
echo "    partfieldname = $partfieldname";
echo "    partfieldformat = $partfieldformat";
echo "    src.file.glob = $cmd_src_file_glob";
echo "    ${part_message}";
echo; echo; echo;


error_text=`grep -i location ${connect_log}`;

if [[ -z "$error_text" || $error_text = *"error"* ]]
then 
	echo "Cannot Connect to ${hostname}"; 
	exit 1;
fi

get_Partition_Dates () {
	partition_field_name=$partfieldname;

	q_sourcename=$(eval "echo $sourcename | sed 's/^...//'")

	# pull out the database & table from the SELECT statement
	echo "    src.file.glob = $cmd_src_file_glob";
	tmp_cmd="echo '$cmd_src_file_glob' | awk -F 'FROM' '{print \$2}'"
	echo $tmp_cmd
	src_file_glob_src_ent=$(eval "$tmp_cmd")
        echo "    src.file.glob.source.entity = $src_file_glob_src_ent";

	# there are 4 different partition formats

	# BigInt            	select close_date, date_format(cast(close_date/1000 as TIMESTAMP), 'yyyyMMddHHmmss') from podium_oracle_xxx.ally_load_by_part_bigint;
	# Timestamp        	select close_date, date_format(close_date, 'yyyyMMddHHmmss') from podium_oracle_xxx.ally_load_by_part_timestamp;
	# YYYYMM    		select close_date, concat(close_date,'01000000') from podium_oracle_xxx.ally_load_by_part_yyyymm;
	# YYYYMMDD   		select close_date, concat(close_date,'000000') from podium_oracle_xxx.ally_load_by_part_yyyymmdd;
	if [ $partfieldformat = "BigInt" ]
	then 
		part_select_query="select distinct(date_format(cast(${partfieldname}/1000 as TIMESTAMP), 'yyyyMMddHHmmss')) from ${src_file_glob_src_ent};"
		part_where_clause="WHERE date_format(cast(${partfieldname}/1000 as TIMESTAMP), '\''yyyyMMddHHmmss'\'')"
	elif [ $partfieldformat = "Timestamp" ]
	then 
		part_select_query="select distinct(date_format(${partfieldname}, 'yyyyMMddHHmmss')) from ${src_file_glob_src_ent}"
                part_where_clause="WHERE date_format(${partfieldname}, '\''yyyyMMddHHmmss'\'')"
	elif [ $partfieldformat = "YYYYMM" ]
        then
                part_select_query="select distinct(concat(${partfieldname},'01000000')) from ${src_file_glob_src_ent}"
                part_where_clause="WHERE concat(${partfieldname},'\''01000000'\'')"
	elif [ $partfieldformat = "YYYYMMDD" ]
        then
                part_select_query="select distinct(concat(${partfieldname},'000000')) from ${src_file_glob_src_ent}"
                part_where_clause="WHERE concat(${partfieldname},'\''000000'\'')"
	else
		echo "*** Invalid Partition Format, must be in: BigInt, Timestamp, YYYYMM, YYYYMMDD"
		exit 1;
	fi	

	part_date_sql="./logs/${sourcename}_${entityname}_part_dates_${curr_ts}.sql";
	
	echo ${part_select_query} > ${part_date_sql};

	part_date_file="./logs/${sourcename}_${entityname}_part_dates_${curr_ts}.dat";
	
	# get the distinct values from partition column
	beeline -u ${hiveconnection} --showHeader=false --outputformat=csv2 --silent=true --showWarnings=false --verbose=false -f ${part_date_sql} | sed -e 's/ //g' | sed -e 's/null//g' | sed -e 's/null//g' | sed -e 's/\r//g'  > ${part_date_file}

	# loop thru each distinct values and use it as partition value in separate load
	count=0;
	while  IFS='' read -r line || [[ ! -z "$line" ]]; do

		tmp_cmd="echo $line | awk '{print length}'"
                echo "    $tmp_cmd"
		line_len=$(eval "$tmp_cmd")
		let count++;
                echo "================================================================================="
		echo "Found partition values: Number ${count}: --$line--";
		echo "Value length: ${line_len}"	
		echo "================================================================================="
	
		if [ $line_len -gt 0 ]
		then
	
	        	#for some clients, we need to pass schema_name.table_name to conn.sqoop.table.name
	        	echo "=== get entityID by searching Source & Entity name =========================="
        		tmp_cmd="curl -s -X GET --header 'Accept: application/json' '$hostname/entity/v1/getEntitiesByCrit?entityName=$entityname&srcName=$sourcename&objType=EXTERNAL' -b $cookiefile | jq .[].id"
        		echo "    $tmp_cmd"
        		cmd_ent_id=$(eval "$tmp_cmd")
        		echo "    $cmd_ent_id"
	
			echo "=== update src.file.glob with WHERE clause      	                         =="
			# fin_cmd_src_file_glob="${cmd_src_file_glob} WHERE date_format(cast(${partfieldname}/1000 as TIMESTAMP), '\''yyyyMMddHHmmss'\'') = '\''${line}'\''"
			fin_cmd_src_file_glob="${cmd_src_file_glob} ${part_where_clause} = '\''${line}'\''"
			tmp_cmd="curl -s -X POST -b $cookiefile --header \"Content-Type: application/json\" --header \"Accept: application/json\" -d '{ \"externalData\": {}, \"name\": \"src.file.glob\", \"value\": \"$fin_cmd_src_file_glob\" }' '$hostname/entity/v2/updateProperty/$cmd_ent_id' | jq . > ./logs/load_update_sfg_${sourcename}_${entityname}_${load_time}.json"
			echo $tmp_cmd
			eval $tmp_cmd	
	
			echo "=== data load request payload ==============================================="
			part_date="$(echo $line | awk '{ print substr( $0, 1, 4) }')-$(echo $line | awk '{ print substr( $0, 5, 2) }')-$(echo $line | awk '{ print substr( $0, 7, 2) }')"
			part_hr="$(echo $line | awk '{ print substr( $0, 9, 2) }')"
                	part_min="$(echo $line | awk '{ print substr( $0, 11, 2) }')"
                	part_ss="$(echo $line | awk '{ print substr( $0, 13, 2) }')"
			part_timezone="$(eval "date +%Z")"

			# we need to convert partition time from load server timezone to GMT (Zulu) since that is what Podium is expecting
			# need to get the correct timezone offset, specially do it against EST and EDT.
			tmp_cmd="date -d ${part_date}T${part_hr}:${part_min}:${part_ss} -R | cut -d' ' -f 6"
			echo $tmp_cmd
			time_offset="$(eval "$tmp_cmd")"
                        load_time="${part_date}T${part_hr}:${part_min}:${part_ss}${time_offset}"

			### expecting something like {loadTime: "2018-10-18T14:42:34.000Z", entityId: 3785}
                	echo "    $line --> {loadTime: \"${load_time}\", entityId: ${cmd_ent_id}}"

			echo "=== here we send in the API request to load ================================="
			tmp_cmd="curl -s -X PUT --header 'Content-Type: application/json' --header 'Accept: application/json' -d '{\"loadTime\":\"${load_time}\", \"entityId\":$cmd_ent_id}' '$hostname/entity/v1/loadDataForEntity/true' -b $cookiefile | jq . > ./logs/load_${sourcename}_${entityname}_${load_time}.json"
			echo "    $tmp_cmd"
			cmd_output=$(eval "$tmp_cmd")
		else
			echo "=== EMPTY RESULTS: SKIP                                                    =="
		fi

	done < ${part_date_file}
}

get_Partition_Dates;

#reset the src.file.glob to back 
echo "=== reset src.file.glob with                                     =="
tmp_cmd="curl -s -X POST -b $cookiefile --header \"Content-Type: application/json\" --header \"Accept: application/json\" -d '{ \"externalData\": {}, \"name\": \"src.file.glob\", \"value\": \"$cmd_src_file_glob\" }' '$hostname/entity/v2/updateProperty/$cmd_ent_id' | jq . > ./logs/load_reset_sfg_${sourcename}_${entityname}_${load_time}.json"
echo $tmp_cmd
eval $tmp_cmd
echo "=========================== END $(date) =================================================="
echo "=========================================================================================="

exit 0;
