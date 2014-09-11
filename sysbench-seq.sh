#!/bin/bash

# variables
larger_file_total_size=600G
benchmark_run_time=900

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

    for thd in 1 8
    do
        echo "-- Running benchmark with $thd threads"
        sysbench --test=fileio --file-num=64 --file-total-size=${total_file_size} \
            --file-test-mode=seqwr --file-io-mode=sync \
            --file-fsync-freq=0 --file-block-size=4K --max-requests=0 --max-time=${run_time} \
            --num-threads=${thd} --report-interval=10 run > ${total_file_size}-${thd}thd-run.log
    done
}

# prepare initial data set size to be used for both the tests below
prepare_benchmark ${larger_file_total_size}

# sleeping to let cache get emptied
sleep 120

run_benchmark ${larger_file_total_size} ${benchmark_run_time}

# cleanup the files created by the benchmark
cleanup_benchmark
