#!/bin/bash
###
### the purpose of this script is to gather podium env from client server
### is allows us to set baseline of the different software, lib installed support podium software.
###
error_time=$1

usage_msg() {
	echo "This script is to gather environment settings and PODIUM specific logs for issue resolution." 
	echo "Upon successful completion of execution, a tarball will be craeted in /tmp/ with the naming format of pd_config_YYYYMMDDHIMISS." 
	echo "Please upload this file to support@pdoiumdata.com and mention your ticket number (if its available)"
	echo -e "\nUsage:\n bash ./podium_env_collector.sh [arg: issue timstamp in \"YYYY-MM-DD HR:MI\"]"
	echo -e " [i.e.] #bash ./podium_env_collector.sh \"2018-07-01 10:28\" > ./podium_env_collector.out 2>&1 &\n"
}
# if less than one arguments supplied, display usage 
if [ $# -le 0 ]
then
	usage_msg
	exit 1
fi

echo "==========================================================================================="
echo "==========================================================================================="
echo "(LOG) $(date):: Collector - START"

echo "Cmd Arg 1 : ${error_time}"

echo "==========================================================================================="
echo "== 1. create dir to capture current config                                               =="
echo "==========================================================================================="
export currts=`date '+%Y%m%d%H%M%S'`;

mkdir /tmp/pd_config_${currts};

export cfg_dir=/tmp/pd_config_${currts};
export cfg_tar=pd_config_${currts}.gz;

echo "==========================================================================================="
echo "== 2. capture the Podium processes                                                       =="
echo "==========================================================================================="
ps -ef | grep Boot > ${cfg_dir}/podium_ps_ef_output_${currts}.txt

echo "==========================================================================================="
echo "== 3. identify the PODIUM_HOME(s)                                                        =="
echo "==========================================================================================="
### If there is more than one instance of Podium running this command will yield as many rows as instances
### Select the appropriate directory for use in the next step
ps -ef | grep Boot | cut -d'=' -f2 | sed 's/conf.*$//g' | grep -v Boot

echo "==========================================================================================="
echo "== 4. copy config files, access & gc logs to temp_dir                                    =="
echo "==========================================================================================="
for i in $(ps -ef | grep Boot | cut -d'=' -f2 | sed 's/conf.*$//g' | grep -v Boot); do
	export podium_prog_dir=$(echo $i | tr '/' '_')
	
	mkdir ${cfg_dir}/PODIUM_${podium_prog_dir} 

	echo "== 4.x processing PODIUM_HOME: ${i} "
	echo "==========================================================================================="	
	echo "=== 4.1 grep *.xml                                                                       =="
	find ${i} -name '*.xml' -print | xargs -I % cp --preserve=mode,timestamps % ${cfg_dir}/PODIUM_${podium_prog_dir}

	echo "=== 4.2 grep core_env.properties                                                         =="
	find ${i} -name core_env.properties | xargs -I % cp --preserve=mode,timestamps % ${cfg_dir}/PODIUM_${podium_prog_dir}

	echo "=== 4.3 grep setnev.sh                                                                   =="
	find ${i} -name setenv.sh | xargs -I % cp --preserve=mode,timestamps % ${cfg_dir}/PODIUM_${podium_prog_dir}

	echo "=== 4.4 grep startup.sh                                                                  =="
	find ${i} -name startup.sh | xargs -I % cp --preserve=mode,timestamps % ${cfg_dir}/PODIUM_${podium_prog_dir}

	echo "=== 4.5 grep cataline.properties                                                         =="
	find ${i} -name catalina.properties | xargs -I % cp --preserve=mode,timestamps % ${cfg_dir}/PODIUM_${podium_prog_dir}

	echo "=== 4.6 grep build_number.txt                                                            =="
	find ${i} -name build_number.txt | xargs -I % cp --preserve=mode,timestamps % ${cfg_dir}/PODIUM_${podium_prog_dir}

	echo "=== 4.7 grep localhost                                                                   =="
	cd ${i}; ls -ltr logs/localhost* | awk '{print $NF}' | tail -1 | xargs -I % cp % $cfg_dir/PODIUM_${podium_prog_dir}

	echo "=== 4.8 grep gc                                                                          =="
	cd ${i}; ls -ltr logs/gc.* | awk '{print $NF}' | tail -1 | xargs -I % cp % $cfg_dir/PODIUM_${podium_prog_dir}

	### Execute the following to collect an extract from catalina.out
	### assign error time up to the minute -- example
	### depending on the date format is configured inside catalina, it could be "Jun 15, 2018 9:47" OR "2018-06-15 09:47:55,049"

	#converts error time to a label for the catalina extract
	echo "=== 4.9 gather catalina.out                                                              =="
	catalina_label=`echo $error_time | sed 's/[ ,:]\+/_/g'`
	#echo $catalina_label

	# captures 1000 lines on either side of all occurrences of the error time in the catalina.out file
	#grep -C1000 "${error_time}" ${i}/logs/catalina.out > ${cfg_dir}/PODIUM_${podium_prog_dir}/catalina_${catalina_label}.out

	# get to the line where the timestamp is 1st captured and grep the next 500 lines
	grep -n "${error_time}" ${i}logs/catalina.out | head -1 | cut -d ":" -f 1 | xargs -I {} -t awk 'NR>{}' ${i}logs/catalina.out | head -500 > ${cfg_dir}/PODIUM_${podium_prog_dir}/catalina_${catalina_label}.out

	echo "=== 4.10 capture Podium restart                                                          =="
	grep -C50 "PODIUM Schema upgrade" ${i}logs/catalina.out | grep INFO > ${cfg_dir}/PODIUM_${podium_prog_dir}/podium_restarts_${currts}.txt

        podium_dump=$(ps -ef | grep Boot | grep -v grep | grep ${i} | awk '{print $2}')
	## The following command should have one number only
	## If it has more than one, inspect the output of: 
	##  ps -ef | grep Boot | grep -v grep 
	## and ensure that it is returning the relevant Podium instance 
	echo "=== 4.11 capture java thread dump PID (${podium_dump}) "

        ## kill -QUIT causes java to output a thread dump to catalina.out
       	kill -QUIT ${podium_dump}

        ## capture last 2mB of catalina.out
	tail -c 2M ${i}logs/catalina.out > ${cfg_dir}/PODIUM_${podium_prog_dir}/catalina_tail_${currts}.out
done

echo "==========================================================================================="
echo "== 5. list postgres processes                                                            =="
echo "==========================================================================================="
## If a postgres error is being investigated execute the following on the server where Postgres is running
## Note cfg_dir may need to be redefined if postgres is running on a separate machine 
## unless the directory is a shared
ps -ef | grep "postgres " > ${cfg_dir}/pg_processes_${currts}.txt

#echo "====================================================="
#echo "== 9. capture max_conn from postgres configuration =="
#echo "====================================================="
## this required access tp the POSTGRES installed path, most likely as POSTGRES OS user.
## pg_data_dir=`grep postmaster ${cfg_dir}/pg_processes_${currts}.txt | grep 9.6 | awk '{print $NF}'`
## grep max_conn $pg_data_dir/postgresql.conf > ${cfg_dir}/pg_max_conn_${currts}.txt

echo "==========================================================================================="
echo "== 6. capture top output                                                                 =="
echo "==========================================================================================="
for i in `seq 1 5`;
do
 	date >> ${cfg_dir}/top_output_${currts}.txt;
 	top -b -n 1 >> ${cfg_dir}/top_output_${currts}.txt;
 	echo "sleeping 5..." >> ${cfg_dir}/top_output_${currts}.txt;
 	sleep 5;
done    

echo "==========================================================================================="
echo "== 7.tar all info                                                                        =="
echo "==========================================================================================="
## tar the entire directory and attach it to your ticket in Freshdesk
tar -czvf /tmp/${cfg_tar} ${cfg_dir}

echo "(LOG) $(date):: Collector - END"
echo "PLEASE send /tmp/${cfg_tar} to Podium suport@podiumdata.com"
echo "==========================================================================================="
echo "==========================================================================================="
