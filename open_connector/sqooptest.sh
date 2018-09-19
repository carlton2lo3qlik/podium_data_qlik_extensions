#!/bin/bash
#sqooptest.sh - imports the pd_field_profile_survey table from localhost into HDFS
 
#echo $password
#echo "1 is $1"
#echo "2 is $2"
#echo "3 is $3"
#echo "4 is $4"
#echo "5 is $5"
#echo "6 is $6"
#echo "7 is $7"
 
#/usr/bin/sqoop import --columns $4 --connect $6 --username $2 --password $password --table $3 -m $5 --enclosed-by '\"' --null-string "" --split-by $7 --target-dir $1 --append

echo "Input password for database user"
read password
partMDir="$2/$(date +%s)"

sqoop import --target-dir $1 --delete-target-dir --table 'podium_core.pd_bundle' --enclosed-by '\"' --connect 'jdbc:postgresql://ludwig.podiumdata.com:5432/podium_md_cs' --null-string ""  --password $password --username $2
