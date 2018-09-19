#!/bin/bash
#
# 2018/06/20
# load_data_schema_evolution.sh
#

### Make Changes Here
hostname="http://ludwig.podiumdata.com:8085/podium_cs312";

sourcename="None Specified";
sourceflag="False";
entityname="None Specified";
entityflag="False";

execname=`basename $0`;

curr_date=`date '+%Y%m%d'`;


USAGE="USAGE:\n	$execname -s sourcename -e entityname
	Both -s sourcename and -e entityname must be provided"
	
while getopts :s:e: option
do 
	case "$option" in
		s) sourceflag="True"; sourcename="$OPTARG";;
		e) entityflag="True"; entityname="$OPTARG";;
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

echo;echo;echo "$execname is being executed with the following parameters:";
echo "    hostname   = $hostname";
echo "    sourcename = $sourcename";
echo "    entityname = $entityname";
echo; echo; echo;

# establish session for API calls

## Set variables
### Make Changes Here
cookiefile="/tmp/schema_evolution/podium_cookie_${currts}.txt";
pd_user="podium"; # echo $pd_user;
pd_pass='nvs2014!'; # echo $pd_pass;

## Establish session
### Make Changes Here
connect_log="/tmp/schema_evolution/podium_connect.log";
rm -f ${connect_log}

curl -X POST ''"${hostname}"'/j_spring_security_check?j_username='"${pd_user}"'&j_password='"${pd_pass}"'' -v -w "%{http_connect}" -c $cookiefile > /tmp/schema_evolution/podium_connect.log 2>&1

error_text=`grep -i location ${connect_log}`;

if [[ -z "$error_text" || $error_text = *"error"* ]]
then 
	echo "Cannot Connect to ${hostname}"; 
	exit 1;
fi

## Test Connection
## curl -X GET ''"${hostname}"'/propDef/getAll' -w "%{http_code}" -b $cookiefile -v



get_Source_Entity_IDs () {
## Get Source and Entity ID's

	curr_ts=`date '+%Y%m%d%H%M%S'`;
	
	out_filename="/tmp/schema_evolution/getEntitiesByCrit_${sourcename}_${entityname}_${curr_ts}.txt";

	curl -X GET ''"${hostname}"'/entity/v1/getEntitiesByCrit?objType=EXTERNAL&srcName='"${sourcename}"'&entityName='"${entityname}"''  -w "%{http_code}" -b ${cookiefile} > ${out_filename}

	for i in $( sed -e 's/\[{/\^^^/g' -e 's/},{/\^^^/g' -e 's/}],*/\^^^/g' ${out_filename} | \
				perl -ne  '@values = split /\^\^\^/,$_; foreach my $value (@values){ print $value . "\n"; }' | \
				perl -ne '@values = split /,/,$_; foreach my $value (@values){ print $value . "\n"; }' | \
				grep -v '^ *$' | grep 'id\|parentSourceId' )
	do

		lhs=`echo $i | awk -F':' '{print $1}' | sed 's/"//g'`;
		rhs=`echo $i | awk -F':' '{print $2}' | sed 's/"//g'`;
		if [[ $lhs = "id" ]]
		then 
			entity_id=$rhs;
		elif [[ $lhs = "parentSourceId" ]]
		then 
			source_id=$rhs;
		fi
	
	done
	
	echo "source_id: $source_id -- entity_id: $entity_id";
}


load_Data_For_Entity () {
## Load Data For Entity

	curr_ts=`date '+%Y%m%d%H%M%S'`;
	
	### Make Changes Here
	job_id=`java -cp /usr/local/podium/apache-tomcat-7.0.73_cs312/lib/PodiumAPIClient.jar:/usr/local/podium/apache-tomcat-7.0.73_cs312/lib/podium.jar com.podiumdata.tools.apiclient.PodiumAPIClient LoadData podium '#0{SI+N1xR0xF2wqNPsHxih6w==}' ${hostname} ${sourcename} ${entityname}`;
	
	job_status="RUNNING";
	
	while [ ${job_status} = "RUNNING" ]; 
	do 
		date; 
		### Make Changes Here
		job_status=`java -cp /usr/local/podium/apache-tomcat-7.0.73_cs312/lib/PodiumAPIClient.jar:/PATH/TO/PODIUM/lib/podium.jar com.podiumdata.tools.apiclient.PodiumAPIClient GetLoadLogs  podium '#0{SI+N1xR0xF2wqNPsHxih6w==}' ${hostname} ${job_id}`;
	 	echo "job_id: ${job_id}"; 
	 	echo "job_status: ${job_status}"; 
	 	sleep 3; 
	done
	
	### Make Changes Here
	out_filename="/tmp/schema_evolution/getloadLogs_${curr_ts}.txt";
	
	## Capture Log Data after completion
	curl -H GET ''"${hostname}"'/entity/v1/loadLogs/'"${entity_id}"'/?count=1' -w "%{http_code}"  -b ${cookiefile} > ${out_filename}
	
	completion_status=`perl -n log_status_parser ${out_filename}`; 
}





get_Source_Entity_IDs;
load_Data_For_Entity;

if [ $completion_status = "FAILED_SCHEMA_CHANGE" ]
then
	echo "Load completed with the following status: ${completion_status}";
	echo "Proceeding with Schema Modification";

	# Get Entity Definition
	### Make Changes Here
	entity_def_file="/tmp/schema_evolution/entity_${entity_id}_def_${curr_ts}.txt";
	curl -H GET ''"${hostname}"'/entity/v1/byId/'"${entity_id}"'' -w "%{http_code}" -w "%{http_code}"  -b ${cookiefile} > ${entity_def_file}

	# Get Detailed Entity Definition - Contains Group Inforamtion
	### Make Changes Here
	entity_dtl_def_file="/tmp/schema_evolution/entity_${entity_id}_dtl_def_${curr_ts}.txt";
	curl -H GET ''"${hostname}"'/entity/v1/getEntityDetailedInfo/'"${entity_id}"'' -w "%{http_code}" -w "%{http_code}"  -b ${cookiefile} > ${entity_dtl_def_file}
	
	source_groups=`cat ${entity_dtl_def_file} | perl -pe 's/^.*?("groups":\[[^\]]+\]).+$/\1/'`;
	
	echo "Will assign the following groups: ${source_groups}";

	# Update Name of Existing Entity whose schema has changed
	new_entity_name="${entityname}_${curr_date}";
	echo "Changing Entity Name from: ${entityname} to: ${new_entity_name}";

	### Make Changes Here
	mod_entity_def_file="/tmp/schema_evolution/mod_entity_${entity_id}_def_${curr_ts}.txt";
	
	sed -e 's/^\[//' -e "s/\"${entityname}\"/\"${new_entity_name}\"/g" -e 's/\][[:digit:]]\+$//' ${entity_def_file} > ${mod_entity_def_file};
	
	curl  -X PUT -H "Content-Type: application/json" ''"${hostname}"'/entity/v1/update' -d @"${mod_entity_def_file}"  -w "%{http_code}" -b ${cookiefile};

	# Redefine Object to Podium
	# Get Entities Available in the source
	
	### Make Changes Here
	editSource_file="/tmp/schema_evolution/editSource_${source_id}_${curr_ts}.txt";
	curl -H GET ''"${hostname}"'/discovery/editSource/'"${source_id}"'' -w "%{http_code}" -b ${cookiefile} > ${editSource_file};

#	entityname="test_trigger";

	### Make Changes Here
	mod_editSource_file="/tmp/schema_evolution/mod_editSource_${source_id}_${curr_ts}.txt";
	cat ${editSource_file} | perl -pe 's/(^.*password.*?)false/\1true/' | perl -pe "s/(^.*\"${entityname}\".*?)false/\1true/" | sed -e 's/[[:digit:]]\+$//' > ${mod_editSource_file};

	# Get Fields available in the Entity 

	### Make Changes Here
	findFieldsBySources_file="/tmp/schema_evolution/findFieldsBySources_${source_id}_${curr_ts}.txt";
	curl -H "Content-Type: application/json" -X POST ''"${hostname}"'/discovery/findFieldsBySources' -d @"${mod_editSource_file}" -w "%{http_code}" -b ${cookiefile} > ${findFieldsBySources_file};
	
	# Modify Fields to "checked = true"; Add groups as they were assigned to the existing entity

	### Make Changes Here
	mod_findFieldsBySources_file="/tmp/schema_evolution/mod_findFieldsBySources_${source_id}_${curr_ts}.txt";
	sed -e 's/"checked":false,"internalDataType"/"checked":true,"internalDataType"/g' -e "s/\"groups\":\[\]/${source_groups}/" ${findFieldsBySources_file} > ${mod_findFieldsBySources_file}

	# Redefine Entity to Podium with new definition

	curl -H "Content-Type: application/json"  -X PUT ''"${hostname}"'/discovery/saveSourceWithMoreEntities' -d @"${mod_findFieldsBySources_file}" -w "%{http_code}" -b ${cookiefile};

######
## ATTEMPT LOAD of Redefined Entity 
######
	
	get_Source_Entity_IDs;
	load_Data_For_Entity;

	echo "***RELOAD*** completed with the following status: ${completion_status}";
	
		 
######
else 
	echo "Load completed with the following status: ${completion_status}";
	echo "Exiting";
fi

exit;

