#!/bin/bash

# variables
file_total_size=100G
io_request_size=16K
benchmark_run_time=1800
run_fsync_all_benchmark=no

# helper functions
prepare_benchmark() {
    echo "-- Preparing dataset of size $file_total_size"
    sysbench --test=fileio --file-num=64 --file-total-size=${file_total_size} prepare > ${file_total_size}-prepare.log
}

cleanup_benchmark() {
    echo "-- Cleaning up dataset of size $file_total_size"
    sysbench --test=fileio --file-num=64 --file-total-size=${file_total_size} cleanup
}

run_benchmark() {
    for thd in 1 8
    do
        echo "-- Running benchmark with $thd threads"
        if [[ $run_fsync_all_benchmark == "yes" ]]
        then
            sysbench --test=fileio --file-num=64 --file-total-size=${file_total_size} \
                --file-test-mode=rndrw --file-io-mode=async --file-extra-flags=direct \
                --file-fsync-all --file-block-size=${io_request_size} --max-requests=0 --max-time=${benchmark_run_time} \
                --num-threads=${thd} --report-interval=10 run > ${file_total_size}-${thd}thd-fsync_all-run.log
        fi

        sysbench --test=fileio --file-num=64 --file-total-size=${file_total_size} \
            --file-test-mode=rndrw --file-io-mode=async --file-extra-flags=direct \
            --file-fsync-freq=0 --file-block-size=${io_request_size} --max-requests=0 --max-time=${benchmark_run_time} \
            --num-threads=${thd} --report-interval=10 run > ${file_total_size}-${thd}thd-run.log
    done
}

# prepare initial data set size to be used for both the tests below
prepare_benchmark

# sleeping to let cache get emptied
sleep 120

echo "---- Benchmarking with total file size of ${file_total_size}"
run_benchmark

# cleaning up initial data set
cleanup_benchmark
