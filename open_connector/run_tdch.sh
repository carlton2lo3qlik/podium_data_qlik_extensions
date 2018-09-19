
export LIB_JARS=/usr/lib/tdch/1.4/lib/teradata-connector-1.4.1.jar,/usr/lib/tdch/1.4/lib/terajdbc4.jar,/usr/lib/tdch/1.4/lib/tdgssconfig.jar

sudo hadoop jar /usr/lib/tdch/1.4/lib/teradata-connector-1.4.1.jar com.teradata.hadoop.tool.TeradataExportTool -libjars ${LIB_JARS} -conf teradata-export-properties.xml  -url jdbc:teradata://teradata2.corp.podiumdata.com/database=podium -username dbc -password dbc -jobtype hdfs -sourcepaths 'hdfs://bambi.podiumdata.com:8020/podiumDemo_3/receiving/Consumer_Sentiment/Sentiment_Daily/20180111124639/good/good-m-00000' -targettable sentiment_daily -separator $'\t' -method internal.fastload
