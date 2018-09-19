#!/bin/sh
# This script will / should be run as a background "service". It will "look" for a temp file
# placed in /tmp by a trigger in Podiums postgres DB. This trigger will fire once a PREPARE job is in a 
# FINISHED state. Once completed, all new hcat entries created by "hive dml" will be updated in IMPALA
# allowing users to have immediate access to the "new" data produced by PREPARE.

# To start, simply type: nohup ./trigger_impala_invalidate_metadata.sh > triggerLog.txt 2>&1 &


while :
do
sleep 5
fdate=`date +%y%m%d%H%M`
if test -e /tmp/prepare_19100910; then
sudo mv /tmp/prepare_19100910 /tmp/prepare_19100910_$fdate
impala-shell -i clouderahadoop-dn0.usgovvirginia.cloudapp.usgovcloudapi.net -d default -k -s clouderaimpalaservice -q 'invalidate metadata;'

echo "FOUND /tmp/prepare_19100910 and invalidated metadata for IMPALA"
sudo rm -rf /tmp/prepare_19100910_$fdate
else
  echo "No watcher file found"
fi
done
