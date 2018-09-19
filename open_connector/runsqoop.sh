#!/bin/bash
read password
 
if (($#!=7)); then
  echo 'Usage: <destination directory> <database username> <database table> <table columns> <sqoop #threads> <database jdbc uri> <split by column>'
fi
 
partMDir="$2/$(date +%s)"
echo $password
echo $1
echo $2
echo $3
echo $4
echo $5
echo $6
echo $7
 
/usr/bin/sqoop import --columns $4 --connect $6 --username $2 --password $password --table $3 -m $5 --enclosed-by '\"' --null-string "" --split-by $7 --target-dir $1 --append
