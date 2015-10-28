#!/bin/bash

yum -y install git libtool make automake autoconf gcc gcc-c++ libaio libaio-devel
rm -rf /tmp/sysbench
git clone https://github.com/akopytov/sysbench.git /tmp/sysbench
curr_pwd=$(pwd)
cd /tmp/sysbench/
./autogen.sh
./configure --without-mysql
make
make install
cd ${curr_pwd}
sysbench --version
