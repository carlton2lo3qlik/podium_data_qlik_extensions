#!/bin/sh
# This script will take in prepare workflow name as inputs and terminate any load with RUNNING status. 
# It is meant to be execute when job hangs.
#
#       This script is provided as a template for Podium customer use.  It is not a supported component of the Podium product.
#       Carlton Lo
#       Podium Data
#       Sept 26, 2018
#
#       terminate_prepare_workflow.sh <prepare workflow name>
#       Arguments:
#               1 Source Name 
#
################################# Modification History #####################################################
# Modified September 5, 2018 - 
############################################################################################################
set -e

############################################################################################################
# set variables
############################################################################################################
var_pwf_name=$1
j_user="clouderaservice@inhouse.opers.org"
j_password="#0{PbigzHTYIa1Jqy1VaHQoNQ==}"
podium_url="http://podium.inhouse.opers.org:8080/podium"
cookie_date=$(date '+%Y_%m_%d_%H%M%S')
cookiename="/tmp/cookie_term_prepare_workflow_${cookie_date}.txt"

#set -x

if (($#!=1)); then
        echo 'Usage: terminate_prepare_workflow.sh <prepare workflow name>'
        exit 216
fi

############################################################################################################
# The Start
############################################################################################################
echo "======================================================================================================"
echo "(LOG) $(date '+%Y-%m-%d %H:%M:%S'):: Terminate Load Job - START"
echo "	Prepare WorkFlow Name:: $var_pwf_name"
echo "	Podium URL::  $podium_url"
echo "	Cookie File:: $cookiename"


############################################################################################################
# create cookie
############################################################################################################
cmd="curl -s -c $cookiename --data 'j_username=$j_user&j_password=$j_password' '$podium_url/j_spring_security_check'"
echo "$(date '+%Y-%m-%d %H:%M:%S') -- Create Cookie -- $cmd"
eval $cmd


############################################################################################################
# get WorkFlow ID by name
#curl -s -b /tmp/test_cookie.txt -X GET 'http://ludwig.podiumdata.com:8680/podium/transformation/loadAllDataflows/10/clo_test_df?count=100&start=0&sortAttr=name&sortDir=DESC' | jq '.subList[] | select(.name=="clo_test_df") | .id'
############################################################################################################
cmd="curl -s -b ${cookiename} -X GET '${podium_url}/transformation/loadAllDataflows/10/${var_pwf_name}?count=100&start=0&sortAttr=name&sortDir=DESC' | jq '.subList[] | select(.name==\"${var_pwf_name}\") | .id'"
echo "$(date '+%Y-%m-%d %H:%M:%S') -- Get WorkFlow ID -- $cmd"
pwf_id=$(eval "$cmd")
echo "WorkFlow ID:: ${pwf_id}"

set +e
############################################################################################################
# get logID / job_id with status of RUNNING
# curl -s -b /tmp/test_cookie.txt -X GET 'http://ludwig.podiumdata.com:8680/podium/transformation/loadAllWorkOrders/3455/?count=100&start=0&sortAttr=loadTime&sortDir=DESC' | jq '.subList[] | select(.status=="RUNNING") | .id'
############################################################################################################
cmd="curl -s -b ${cookiename} -X GET '${podium_url}/transformation/loadAllWorkOrders/${pwf_id}/?count=100&start=0&sortAttr=loadTime&sortDir=DESC' | jq '.subList[] | select(.status==\"RUNNING\") | .id'"
echo "$(date '+%Y-%m-%d %H:%M:%S') -- Get LogID -- $cmd"
log_id=$(eval "$cmd")
echo "logID:: ${log_id}"

set -e
if [ -z "$log_id" ]
then
	echo "$(date '+%Y-%m-%d %H:%M:%S') -- NO RUNNING JOB FOUND for WorkFlow::${var_pwf_name} ID::${pwf_id} !"
else
	############################################################################################################
	# send in termination request
	############################################################################################################
	cmd="curl -s -b ${cookiename} -X PUT '${podium_url}/transformation/updatePrepareLogsStatus/${log_id}/TERMINATION_REQUESTED'"
	echo "$(date '+%Y-%m-%d %H:%M:%S') -- submit Termination Request -- $cmd"
	cmd_output=$(eval "$cmd")
	echo "term output:: ${cmd_output}"
fi

############################################################################################################
# The End
############################################################################################################
echo "(LOG) $(date '+%Y-%m-%d %H:%M:%S'):: Terminate Load Job - END"
echo "======================================================================================================"