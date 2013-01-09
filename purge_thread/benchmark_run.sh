#!/bin/bash

# General config
sandbox_dir=/work/sandboxes/msb_ps_5_5_28
mysql_datadir=/work/benchmarks/mysql_datadirs/sysbench_15g
mysql_params="--query_cache_size=0 --query_cache_type=0 --innodb_file_per_table=1 --innodb_buffer_pool_size=20G --innodb_flush_method=O_DIRECT --innodb_flush_log_at_trx_commit=0"
mysql_connection_params="--socket=/tmp/mysql_sandbox5528.sock --user=msandbox --password=msandbox"

# Sysbench config
sb_mysql_options="--mysql-user=msandbox --mysql-password=msandbox --mysql-socket=/tmp/mysql_sandbox5528.sock --mysql-table-engine=innodb --mysql-db=test"
sb_oltp_options="--test=/work/binaries/sysbench-0.5/sysbench/tests/db/oltp.lua --oltp-tables-count=8 --oltp-table-size=8000000"

for log_file_size in 2G 1G 512M 256M 128M
do
    for purge_threads in 0 1
    do
        echo "---- Starting Benchmark run for log_file_size=${log_file_size} and purge_threads=${purge_threads}"

        # remove InnoDB log files
        echo "-- Removing InnoDB log files"
        (cd $mysql_datadir; rm -f ib_logfile0 ib_logfile1)

        # start the sandbox
        echo "-- Starting MySQL sandbox located in ${sandbox_dir}"
        (cd $sandbox_dir; ./start ${mysql_params} --innodb_log_file_size=${log_file_size} --innodb_purge_threads=${purge_threads} --datadir=${mysql_datadir})

        # test if mysqld has started
        mysqld_started=$(mysqladmin ${mysql_connection_params} ping 2> /dev/null)
        while [[ "$mysqld_started" != "mysqld is alive" ]]
        do
            sleep 5
            mysqld_started=$(mysqladmin ${mysql_connection_params} ping 2> /dev/null)
        done

        echo "-- MySQL sandbox started"

        # warm up the bufferpool
        echo "-- Warming up the InnoDB bufferpool"
        for t in $(seq 1 8)
        do 
            mysql ${mysql_connection_params} -A test -e "select * from sbtest${t}" > /dev/null
        done

        echo "-- InnoDB bufferpool warmed up"

        results_file_prefix="log_size_${log_file_size}-purge_thread_${purge_threads}"

        # start gathering InnoDB stats
        echo "-- Started gathering InnoDB stats (Innodb_history_list_length, Innodb_lsn_current, Innodb_buffer_pool_pages_flushed)"
        timeout 910s mysqladmin ${mysql_connection_params} -i 1 extended-status | egrep --line-buffered "Innodb_history_list_length|Innodb_lsn_current" > history_lsn-${results_file_prefix}.log &

        other_stats="Innodb_master_thread_1_second_loops|Innodb_master_thread_10_second_loops|Innodb_master_thread_main_flush_loops|Innodb_buffer_pool_pages_flushed"
        timeout 910s mysqladmin ${mysql_connection_params} -r -i 1 extended-status | egrep --line-buffered "${other_stats}" > other_stats-${results_file_prefix}.log &

        # run the sysbench benchmark
        echo "-- Running sysbench now"
        sysbench ${sb_oltp_options} ${sb_mysql_options} --max-time=900 --num-threads=8 --max-requests=0 --report-interval=1 run > sb-${results_file_prefix}.log

        # Wait for background stats gathering jobs to finish
        wait

        # Wait for InnoDB dirty pages to become zero and then stop MySQL 
        echo "-- Waiting for count of InnoDB dirty pages to become zero"
        num_innodb_dirty_pages=$(mysqladmin ${mysql_connection_params} extended-status | grep Innodb_buffer_pool_pages_dirty | awk '{print $4}')
        while (( $num_innodb_dirty_pages > 0 ))
        do
            sleep 10
            num_innodb_dirty_pages=$(mysqladmin ${mysql_connection_params} extended-status | grep Innodb_buffer_pool_pages_dirty | awk '{print $4}')
        done

        echo "-- Stopping MySQL now"
        (cd $sandbox_dir; ./stop; sleep 60)
        
        echo "-- Benchmark completed"
        echo
    done
done
