#!/bin/bash

qps_filename=qps.txt
hist_filename=hist_len.txt
lsn_filename=lsn_current.txt
pages_flushed_filename=pages_flushed.txt
tmp_output_filename="__tmp.txt" # Temp file to hold intermediate results

rm -f $qps_filename $hist_filename $lsn_filename $pages_flushed_filename $tmp_output_filename
touch $qps_filename $hist_filename $lsn_filename $pages_flushed_filename $tmp_output_filename

echo "---- Starting report generation"

for log_file_size in 2G 1G 512M 256M 128M
do
    for purge_threads in 0 1
    do
        echo "-- Generating report for innodb_log_file_size=${log_file_size} and innodb_purge_threads=${purge_threads}"

        # Filter QPS info
        sb_filename="sb-log_size_${log_file_size}-purge_thread_${purge_threads}.log"
        echo "Log_size_${log_file_size}-Purge_threads_${purge_threads}" > $tmp_output_filename
        cat $sb_filename | grep "reads/s:" | sed 's/\,//g' | awk '{printf("%.2f\n", $8+$10)}' >> $tmp_output_filename

        # Append the QPS info to the QPS log file
        paste $qps_filename $tmp_output_filename > ${qps_filename}.tmp
        mv ${qps_filename}.tmp $qps_filename

        # Filter history_list_length info
        hist_lsn_filename="history_lsn-log_size_${log_file_size}-purge_thread_${purge_threads}.log"
        echo "Log_size_${log_file_size}-Purge_threads_${purge_threads}" > $tmp_output_filename
        cat $hist_lsn_filename | grep "Innodb_history_list_length" | awk '{print $4}' >> $tmp_output_filename

        # Append the history_list_length info to the log file
        paste $hist_filename $tmp_output_filename > ${hist_filename}.tmp
        mv ${hist_filename}.tmp $hist_filename

        # Filter LSN info 
        echo "Log_size_${log_file_size}-Purge_threads_${purge_threads}" > $tmp_output_filename
        cat $hist_lsn_filename | grep "Innodb_lsn_current" | awk '{print $4}' >> $tmp_output_filename

        # Append the LSN info to the log file
        paste $lsn_filename $tmp_output_filename > ${lsn_filename}.tmp
        mv ${lsn_filename}.tmp $lsn_filename

        # Filter the bufferpool pages flushed info
        other_stats_filename="other_stats-log_size_${log_file_size}-purge_thread_${purge_threads}.log"
        echo "Log_size_${log_file_size}-Purge_threads_${purge_threads}" > $tmp_output_filename
        cat $other_stats_filename | grep "Innodb_buffer_pool_pages_flushed" | awk '{print $4}' >> $tmp_output_filename

        # Append the bufferpool pages flushed info to the log file
        paste $pages_flushed_filename $tmp_output_filename > ${pages_flushed_filename}.tmp
        mv ${pages_flushed_filename}.tmp $pages_flushed_filename
    done
done

rm -f $tmp_output_filename

echo "-- Report written to files: $qps_filename, $hist_filename, $lsn_filename, $pages_flushed_filename"
echo
