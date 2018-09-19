set -x
LOADINGDOCK=$1 #HDFS destination for the resulting file
KAFKA_TOPIC=$2 #Kafka topic to listen to
ZOOKEEPER=$3 #Zookeeper Kafka URI
BOOTSTRAP_SERVER=$4 #Karka service
TIME_INTERVAL=$5 #Time interval in seconds during which we'll listen to Kafka

KAFKA_PATH=/usr/bin



fdate=`date +%y%m%d%H%M%S`
fname="/tmp/kafka_ingest_$fdate"
$KAFKA_PATH/kafka-console-consumer --zookeeper $ZOOKEEPER --bootstrap-server $BOOTSTRAP_SERVER  --topic $KAFKA_TOPIC > $fname &
sleep $TIME_INTERVAL
kill -SIGHUP %1
echo "Ingesting data from $KAFKA_TOPIC"
hadoop fs -put $fname $1
