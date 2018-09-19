
export LIB_JARS=/usr/lib/tdch/1.4/lib/teradata-connector-1.4.1.jar,/usr/lib/tdch/1.4/lib/terajdbc4.jar,/usr/lib/tdch/1.4/lib/tdgssconfig.jar

hadoop jar /usr/lib/tdch/1.4/lib/teradata-connector-1.4.1.jar com.teradata.hadoop.tool.TeradataExportTool -url jdbc:teradata://teradata2.corp.podiumdata.com/database=podium -username dbc -password dbc -classname com.teradata.jdbc.TeraDriver -fileformat textfile -jobtype hdfs -method split.by.hash -targetpaths /user/podium/tdch_test -nummappers 2 -sourcetable consumer_complaints
