#!/bin/bash

yum -y install bzr libtool make automake autoconf gcc gcc-c++
rm -rf /tmp/sysbench
bzr branch lp:sysbench /tmp/sysbench
curr_pwd=$(pwd)
cd /tmp/sysbench/
./autogen.sh
./configure --without-mysql
make
make install
cd ${curr_pwd}
sysbench --version
