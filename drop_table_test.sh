#!/bin/bash

results_file_prefix=$1

mysql_user=msandbox
mysql_pass=msandbox
mysql_socket=/tmp/mysql_sandbox5528.sock

test_db_name=test
test_start_time=$(date +%s)

date_format="+%Y-%m-%d %H:%M:%S"

vlog() {
        msg=$1
        date_time=$(date "+%Y-%m-%d %H:%M:%S")
        echo "[${date_time}] ${msg}" | tee -a benchmark_run_${results_file_prefix}.log
}

vlog "Creating test tables"

for i in $(seq 1 29)
do
	drop_table_name=drop_test_${i}
	mysql --user=${mysql_user} --password=${mysql_pass} --socket=${mysql_socket} ${test_db_name} -e "CREATE TABLE IF NOT EXISTS ${drop_table_name}(i int(11) not null auto_increment primary key)"

	for j in $(seq 1 1000)
	do
		mysql --user=${mysql_user} --password=${mysql_pass} --socket=${mysql_socket} ${test_db_name} -e "INSERT INTO ${drop_table_name} VALUES(NULL)"
	done
done

vlog "Starting to run sysbench benchmark"
sysbench --test=/work/binaries/sysbench-0.5/sysbench/tests/db/oltp.lua --oltp-tables-count=8 \
	--oltp-table-size=8000000 --mysql-table-engine=innodb --mysql-user=${mysql_user} \
	--mysql-password=${mysql_pass} --mysql-socket=${mysql_socket} --mysql-db=${test_db_name} \
	--max-time=930 --num-threads=8 --max-requests=0 --report-interval=1 run > sb_run_${results_file_prefix}.log &

sleep 30

for i in $(seq 1 29)
do
	drop_table_name=drop_test_${i}

	vlog "Dropping table ${drop_table_name}"
	mysql --user=${mysql_user} --password=${mysql_pass} --socket=${mysql_socket} ${test_db_name} -e "DROP TABLE ${drop_table_name}"
	vlog "Dropped table ${drop_table_name}"

	sleep 30
done

# wait for sysbench to complete
wait
