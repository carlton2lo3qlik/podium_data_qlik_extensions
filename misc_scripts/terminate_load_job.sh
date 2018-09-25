#!/bin/sh
# This script will take in source name and entity name as inputs and terminate any load with RUNNING status. 
# It is meant to be execute when load job hangs.
#
#       This script is provided as a template for Podium customer use.  It is not a supported component of the Podium product.
#       Carlton Lo
#       Podium Data
#       Sept 24, 2018
#
#       terminate_load_job.sh <source name> <entity name>
#       Arguments:
#               1 Source Name 
#               2 Entity Name
#
################################# Modification History #####################################################
# Modified September 5, 2018 - 
############################################################################################################
set -e

############################################################################################################
# set variables
############################################################################################################
var_src_name=$1
var_ent_name=$2
#j_user="clouderaservice@inhouse.opers.org"
#j_password="#0{PbigzHTYIa1Jqy1VaHQoNQ==}"
#podium_url="http://podium.inhouse.opers.org:8080/podium"
cookie_date=$(date '+%Y_%m_%d_%H%M%S')
cookiename="/tmp/cookie_term_load_job_${cookie_date}.txt"

j_user="podium"
j_password="nvs2014!"
podium_url="http://ludwig.podiumdata.com:8180/podium"

#set -x

if (($#!=2)); then
        echo 'Usage: terminate_load_job.sh <source name> <entity name>'
        exit 216
fi

############################################################################################################
# The Start
############################################################################################################
echo "======================================================================================================"
echo "(LOG) $(date '+%Y-%m-%d %H:%M:%S'):: Terminate Load Job - START"
echo "	Source Name:: $var_src_name"
echo "	Entity Name:: $var_ent_name"
echo "	Podium URL::  $podium_url"
echo "	Cookie File:: $cookiename"


############################################################################################################
# create cookie
############################################################################################################
cmd="curl -s -c $cookiename --data 'j_username=$j_user&j_password=$j_password' '$podium_url/j_spring_security_check'"
echo "$(date '+%Y-%m-%d %H:%M:%S') -- Create Cookie -- $cmd"
eval $cmd

############################################################################################################
# get entityID by source & entity name
############################################################################################################
cmd="curl -s -b ${cookiename} -X GET '${podium_url}/entity/v1/getEntitiesByCrit?srcName=${var_src_name}&entityName=${var_ent_name}' | jq .[].id"
echo "$(date '+%Y-%m-%d %H:%M:%S') -- Get EntityID -- $cmd"
ent_id=$(eval "$cmd")
echo "entityID:: ${ent_id}"

set +e
############################################################################################################
# get logID / job_id with status of RUNNING
############################################################################################################
cmd="curl -s -b ${cookiename} -X GET '${podium_url}/entity/v1/loadLogs/${ent_id}?count=500&sortAttr=loadTime&sortDir=DESC' | jq '.subList[] | select(.status==\"RUNNING\") | .id'"
echo "$(date '+%Y-%m-%d %H:%M:%S') -- Get LogID -- $cmd"
log_id=$(eval "$cmd")
echo "logID:: ${log_id}"

set -e
if [ -z "$log_id" ]
then
	echo "$(date '+%Y-%m-%d %H:%M:%S') -- NO RUNNING JOB FOUND for Entity::${var_ent_name} ID::${ent_id} in Source::${var_src_name} !"
else
	#http://ludwig.podiumdata.com:8180/podium/entity/updateLoadLogsStatus/705/TERMINATION_REQUESTED
	############################################################################################################
	# send in termination request
	############################################################################################################
	cmd="curl -s -b ${cookiename} -X PUT '${podium_url}/entity/updateLoadLogsStatus/${log_id}/TERMINATION_REQUESTED'"
	echo "$(date '+%Y-%m-%d %H:%M:%S') -- submit Termination Request -- $cmd"
	cmd_output=$(eval "$cmd")
	echo "term output:: ${cmd_output}"
fi

############################################################################################################
# The End
############################################################################################################
echo "(LOG) $(date '+%Y-%m-%d %H:%M:%S'):: Terminate Load Job - END"
echo "======================================================================================================"