#!/bin/bash
#sqooptest.sh - imports the pd_field_profile_survey table from localhost into HDFS

#arguments:
if (($#!=7)); then
  echo 'Usage: <destination directory> <database username> <database table> <table columns> <sqoop #threads> <database jdbc uri> <split by column>'
fi
 
echo "Input password for database user"
read password
partMDir="$2/$(date +%s)"

#echo "columns: $4" > /tmp/sqoopdebug
#echo "connect: $6" >> /tmp/sqoopdebug
#echo "username: $2" >> /tmp/sqoopdebug
#echo "password: $password" >> /tmp/sqoopdebug
#echo "table: $3" >> /tmp/sqoopdebug
#echo "threads: $5" >> /tmp/sqoopdebug
#echo "split: $7" >> /tmp/sqoopdebug
#echo "target dir: $1" >> /tmp/sqoopdebug
#echo "/usr/bin/sqoop import --columns $4 --connect $6 --username $2 --password $password --table $3 -m $5 --enclosed-by '\"' --null-string "" --split-by $7 --target-dir $1 --append" >> /tmp/sqoopdebug

/usr/bin/sqoop import --columns $4 --connect $6 --username $2 --password $password --table $3 -m $5 --enclosed-by '\"' --null-string "" --split-by $7 --target-dir $1 --append
