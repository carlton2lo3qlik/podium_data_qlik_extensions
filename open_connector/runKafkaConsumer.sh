#!/bin/bash
cd /root/fido_json/jkconsumer/
#java -cp "kafka_consumer.jar:commons-cli-1.4.jar:podium_cloudera-cdh5.jar:kafka-clients-1.0.0.jar:./cluster_config" com.podiumdata.consumer.ConsumerDriver --server thumper.podiumdata.com:9092 --topic fidojson --pollingInterval 5000 --processingDuration 60000 --filePath hdfs://bambi.podiumdata.com:8020/temp/json.out

java -cp "kafka_consumer.jar:commons-cli-1.4.jar:podium_cloudera-cdh5.jar:kafka-clients-1.0.0.jar:./cluster_config" com.podiumdata.consumer.ConsumerDriver --server $1 --topic $2 --pollingInterval $3 --processingDuration $4 --filePath file:///tmp/json.out 

#'hdfs://bambi.podiumdata.com:8020/'$6

hadoop fs -put /tmp/json.out $6
