#!/bin/sh
# Open Connector Script to find out the different reasons for bad & ugly records from a particular entity load.
# Running this script WILL NOT LOAD any entities. 
#
#       This script is provided as a template for Podium customer use.  It is not a supported component of the Podium product.
#       Carlton Lo
#       Podium Data
#       Sept 13, 2018
#
#	get_bad_ugly_record_reasons.sh
#       The script scan load log path from receiving dock in HDFS to get all the bad & ugly reasons.
#	Argument(s): 
#		1 - combined:: source/entity/partition

if (($#!=1)); then
	echo 'Usage: <combined source/entity/partition>'
        exit 216
fi

var_combined=$1
var_hdfs_path="$var_combined/log"

echo $var_combined
echo "============ Script: Start ============" 
echo "... ... Scanning HDFS path (${var_hdfs_path}) for bad & ugly reasons ... ..."

# Here we will scan receiving dock in HDFS for bad & ugly reasons
# yes, both bad & ugly reasons are in the same /log path.
hadoop fs -cat ${var_hdfs_path}/log_*.gz | zcat | cut -d$'\t' -f 2 | sort -u

echo "============ Script: End (exit error by-design) ==========="

# In normal situation open connector script is used to move data into loading dock and then podium will start to pickup by running profile, validation, then load into Hive.
# However in this case, we do not have (& want) to load any entity. Just want to list out the bad & ugly reasons. 
# So, here we force out and error (non-zero) exit.
exit -1

