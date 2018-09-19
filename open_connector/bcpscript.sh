#!/bin/bash
#
#       This script is provided as a template for Podium customer use.  It is not a supported component of the Podium product.
#       Christopher S. Ortega
#       Podium Data
#       June 21, 2017
#
#	bcpscript.sh - Creates a file in HDFS (loadingdock) for any table from any SQLServer database using BCP for the extract.
#       The script first creates a named pipe (mkfifo for the entity) and begins an HDFS put to loadingdock in background from that pipe
#       The script then launches BCP and uses the named pipe as its output file.  This effectively streams the data from SQLServer directly 
#         into HDFS without first landing it on the podium server. 
#	Arguments: 
#		1 - destination file: destination for resulting csv file
#		2 - source database username
#               3 - originalSourceName (e.g. dbo)
#               4 - tablename (e.g. policybenefit)
#               5 - resource_uri (e.g jdbc:sqlserver://pd-sqlserver-qa.podiumdata.com:1433;databaseName=xyz)
#               Note: The 3 variables below will be used to create the fully qualified name on the source (e.g. xyz.dbo.policybenefit)
#                            resource_uri,originalsourcename.tablename

if (($#!=5)); then
	echo 'Usage: <destination directory> <source username> <originalSourceName> <entity.name> <resource_uri>'
        exit
fi

# Connection details for the source database
echo "Input password for database user"
read password

loadingdock=$1
username=$2
originalsourcename=$3
tablename=$4
resource_uri=$5

# Sample resource uri = jdbc:sqlserver://pd-sqlserver-qa.podiumdata.com:1433;databaseName=xyz
# database is the 2nd field delimited by an equal sign, e.g. xyz
database=`echo $resource_uri | cut -d'=' -f2`
# hostname is the 3rd field delimited by a slash and then the first terminated by a colon, e.g. pd-sqlserver-qa.podiumdata.com
hostname=`echo $resource_uri | cut -d'/' -f3 | cut -d':' -f1`

# destination file is in the loading dock directory (by partition date) and named bcpfile.txt
# This is the file that will be created in loadingdock
destfile=$loadingdock'/bcpfile.txt'

# named pipe used is in the format /tmp/bcppipe.database.entity
pipename='/tmp/bcppipe.'$originalsourcename'.'$tablename

# Establish the pipe for this job
rm -f $pipename
mkfifo $pipename

# Run the put from the named pipe into loadingdock (run in the background)
hadoop fs -put $pipename $destfile &

# Use BCP to extract the SQLSever data.
# Note:  The same script can be used with any high-performance bulk extract by modifying this line...
/opt/mssql-tools/bin/bcp $database'.'$originalsourcename'.'$tablename out $pipename -U $username -P $password -S $hostname -c 

# The End
