
set -x
beeline -u jdbc:hive2://bambi.podiumdata.com:10000 -e "drop table if exists ${1}_txt"

beeline -u jdbc:hive2://bambi.podiumdata.com:10000 -e "create table ${1}_txt  LOCATION '$2' as select * from ${3}.${1}"
