#!/bin/bash

# variables
larger_file_total_size=600G
smaller_file_total_size=256M
benchmark_run_time=1800
run_fsync_all_benchmark=yes
run_in_wb_cache_benchmark=yes

# helper functions
prepare_benchmark() {
	total_file_size=$1

	echo "-- Preparing dataset of size $total_file_size"
	sysbench --test=fileio --file-num=64 --file-total-size=${total_file_size} prepare > ${total_file_size}-prepare.log
}

cleanup_benchmark() {
	total_file_size=$1

	echo "-- Cleaning up dataset of size $total_file_size"
	sysbench --test=fileio --file-num=64 --file-total-size=${total_file_size} cleanup
}

run_benchmark() {
	total_file_size=$1
	run_time=$2
	cache=$3

	for thd in 1 8
	do
        	echo "-- Running benchmark with $thd threads"
		if [[ $run_fsync_all_benchmark == "yes" ]]
		then
        		sysbench --test=fileio --file-num=64 --file-total-size=${total_file_size} \
                		--file-test-mode=rndwr --file-io-mode=async --file-extra-flags=direct \
                		--file-fsync-all --file-block-size=16K --max-requests=0 --max-time=${run_time} \
                		--num-threads=${thd} --report-interval=10 run > ${cache}-${total_file_size}-${thd}thd-fsync_all-run.log
		fi

        	sysbench --test=fileio --file-num=64 --file-total-size=${total_file_size} \
                	--file-test-mode=rndwr --file-io-mode=async --file-extra-flags=direct \
                	--file-fsync-freq=0 --file-block-size=16K --max-requests=0 --max-time=${run_time} \
                	--num-threads=${thd} --report-interval=10 run > ${cache}-${total_file_size}-${thd}thd-fsync_none-run.log
	done
}

# prepare initial data set size to be used for both the tests below
prepare_benchmark $larger_file_total_size

# sleeping to let cache get emptied
sleep 120

# write back cache enabled
echo "---- Benchmarking with write back cache enabled"
echo "-- Enabling write back cache"
hpacucli controller slot=10 modify cacheratio=0/100

run_benchmark $larger_file_total_size $benchmark_run_time "wbc"

# sleeping to let cache get emptied
sleep 120

# write back cache disabled
echo
echo "---- Benchmarking with write back cache disabled"
echo "-- Disabling write back cache"
hpacucli controller slot=10 modify cacheratio=100/0

run_benchmark $larger_file_total_size $benchmark_run_time "no_wbc"

# cleaning up initial data set
cleanup_benchmark $larger_file_total_size

# write back cache enabled and total file size fits in controller cache
if [[ $run_in_wb_cache_benchmark == "yes" ]]
then
	prepare_benchmark $smaller_file_total_size

	# sleeping to let cache get emptied
	sleep 120

	echo "---- Benchmarking with write back cache enabled and dataset fits in cache"
	echo "-- Enabling write back cache"
	hpacucli controller slot=10 modify cacheratio=0/100

	run_benchmark $smaller_file_total_size $benchmark_run_time "wbc"

	cleanup_benchmark $smaller_file_total_size
fi

