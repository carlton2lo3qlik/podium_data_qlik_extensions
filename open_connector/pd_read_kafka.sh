# Change the following variable
KAFKA_HOME=/home/kafka2/kafka/downloads/kafka_2.10-0.10.2.0

pZookeeper=$1
pTopic=$2
pFromBeginning=$3
pLoadingDock=$4

vPipeNameUnique=$(($RANDOM*$RANDOM*RANDOM))

mkfifo /tmp/podium_kafka_stream_$vPipeNameUnique

#echo "$pZookeeper $pTopic $pFromBeginning" 

if [ "$pFromBeginning" = "YES" ] 
then

  $KAFKA_HOME/bin/kafka-console-consumer.sh --zookeeper $pZookeeper --topic $pTopic --from-beginning \
  >> /tmp/podium_kafka_stream_$vPipeNameUnique \
  | sleep 3 \
  | cat /tmp/podium_kafka_stream_$vPipeNameUnique \
  | hadoop fs -put - $pLoadingDock
 
  #cat /home/podium/brad_kafka/test > /tmp/podium_kafka_stream_$vPipeNameUnique | sleep 2 | cat /tmp/podium_kafka_stream_$vPipeNameUnique | hadoop fs -put - $pLoadingDock

else

  $KAFKA_HOME/bin/kafka-console-consumer.sh --zookeeper $pZookeeper --topic $pTopic --from-beginning \
  >> /tmp/podium_kafka_stream_$vPipeNameUnique \
  | sleep 3 \
  | cat /tmp/podium_kafka_stream_$vPipeNameUnique \
  | hadoop fs -put - $pLoadingDock
 
 #cat /home/podium/brad_kafka/test > /tmp/podium_kafka_stream_$vPipeNameUnique | sleep 2 |cat /tmp/podium_kafka_stream_$vPipeNameUnique | hadoop fs -put - $pLoadingDock

fi

rm -f podium_kafka_stream_$vPipeNameUnique


