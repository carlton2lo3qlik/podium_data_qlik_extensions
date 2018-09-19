
export LIB_JARS=/usr/lib/tdch/1.4/lib/teradata-connector-1.4.1.jar,/usr/lib/tdch/1.4/lib/terajdbc4.jar,/usr/lib/tdch/1.4/lib/tdgssconfig.jar

hadoop fs -rmr $1

hadoop jar /usr/lib/tdch/1.4/lib/teradata-connector-1.4.1.jar com.teradata.hadoop.tool.TeradataImportTool -url jdbc:teradata://$2/database=$3 -username $4 -password $5 -classname com.teradata.jdbc.TeraDriver -fileformat textfile -jobtype hdfs -method split.by.hash -targetpaths $1 -nummappers 2 -sourcetable $6
