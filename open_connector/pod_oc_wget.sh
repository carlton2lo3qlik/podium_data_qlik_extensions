#!/bin/sh
# Open Connector Script to do an FTP from a mainframe FTP server (or any) and load to loadingdock
# FOR EXAMPLE: wget --ftp-user WDBA --ftp-password 1oyPBN97 ftp://10.50.4.1/DB26CUST.CNTL.CUSDBAS1.CUSSCUST
#
#       This script is provided as a template for Podium customer use.  It is not a supported component of the Podium product.
#       Christopher S. Ortega
#       Podium Data
#       August 31, 2018
#
#       pod_oc_wget.sh - Creates a file in HDFS (loadingdock) for any table from an FTP Server via wget.
#       The script first creates a named pipe (mkfifo for the entity) and begins an HDFS put to loadingdock in background from that pipe
#       into HDFS without first landing it on the podium server.
#       Arguments:
#               1 - ftp user: the user account for FTP (e.g. WDBA)
#               2 - ftp password: the FTP password for the user above
#               3 - ftp server: e.g. ftp://10.50.4.1
#               4 - ftp file: (e.g. DB26CUST.CNTL.CUSDBAS1.CUSSCUST)
#               5 - loadingdocklocation (from Podium)
#
################################# Modification History #####################################################
# Modified September 5, 2018 - Don't use src.file.glob for named pipe.  It can contains wildcard characters.
#                              Replaced with sourcename and entityname
############################################################################################################
set -e
var_ftp_user=$1
var_ftp_passw=$2
var_ftp_server=$3
var_ftp_file=$4
loadingdock=$5

decrypt_ftp_passw=`java -cp /usr/local/podium/podium/lib/EncryptDecrypt.jar:/usr/local/podium/apache-tomcat-7.0.72/webapps/podium/WEB-INF/lib/utils-3.3.jar com.brian.EncryptDecrypt decrypt "${var_ftp_passw}"`
echo $decrypt_ftp_passw

set -x

if (($#!=5)); then
        echo 'Usage: <ftp user> <ftp password> <ftp server> <ftp filename> <resource_uri/loadingdocklocation>'
        exit 216
fi

####### 2018-09-05:  Wildcard fix - insert these lines ######
p_sourcename=`echo ${loadingdock} | cut -d \/ -f4`
p_entityname=`echo ${loadingdock} | cut -d \/ -f5`
####### End Insert ######
var_epoch_time=`date +'%s'`

# destination file is in the loading dock directory (by partition date) and named as the ftp file.
# This is the file that will be created in loadingdock
destfile=$loadingdock'/'$var_ftp_file

# named pipe used is in the format /tmp/bcppipe.database.entity
######## 2018-09-05:  Wildcard fix - replace line below with the one that follows ######
#pipename='/tmp/pod_oc_wget.'$var_ftp_user'.'$var_ftp_file'.'$var_epoch_time
pipename='/tmp/pod_oc_wget.'$p_sourcename'.'$p_entityname'.'$var_epoch_time
######## End Replacement ######

# Establish the pipe for this job
rm -f $pipename
mkfifo $pipename

# Run the put from the named pipe into loadingdock (run in the background)
hadoop fs -put $pipename $destfile &

# Use wget to extract the data.
#/opt/mssql-tools/bin/bcp $database'.'$originalsourcename'.'$tablename out $pipename -U $username -P $password -S $hostname -c
###wget --ftp-user $var_ftp_user  --ftp-password $var_ftp_passw $var_ftp_server$var_ftp_file -O $pipename
wget --ftp-user $var_ftp_user  --ftp-password $decrypt_ftp_passw $var_ftp_server$var_ftp_file -O $pipename

rm -f $pipename
# The End

