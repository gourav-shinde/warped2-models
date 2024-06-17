#!/bin/bash

cd /home/gaurav/workspace/warped2
make clean
autoreconf -i
# ./configure --with-mpi-includedir=/usr/lib/x86_64-linux-gnu/openmpi/include --prefix=/home/gaurav/workspace/warped2/build --with-unified-queue --enable-debug
# ./configure --with-mpi-includedir=/usr/lib/x86_64-linux-gnu/openmpi/include --prefix=/home/gaurav/workspace/warped2/build --with-unified-queue 
./configure --with-mpi-includedir=/usr/lib/x86_64-linux-gnu/openmpi/include --prefix=/home/gaurav/workspace/warped2/build
make -j 8 install

cd /home/gaurav/workspace/warped2-models/
make clean
autoreconf -i 
./configure --with-warped=/home/gaurav/workspace/warped2/build CXXFLAGS='-g -O3 -std=c++11' CXX=mpicxx
make -j 8

