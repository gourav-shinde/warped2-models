#!/bin/bash

cd /home/gaurav/workspace/warped2
make clean
autoreconf -i
# ./configure --with-mpi-includedir=/usr/include/x86_64-linux-gnu/mpich --with-mpi-libdir=/usr/lib/x86_64-linux-gnu/mpich --prefix=/home/gaurav/workspace/warped2/build --with-unified-queue --enable-debug
./configure --with-mpi-includedir=/usr/include/x86_64-linux-gnu/mpich --with-mpi-libdir=/usr/lib/x86_64-linux-gnu/mpich --prefix=/home/gaurav/workspace/warped2/build --with-unified-queue 
# ./configure --with-mpi-includedir=/usr/include/x86_64-linux-gnu/mpich --with-mpi-libdir=/usr/lib/x86_64-linux-gnu/mpich --prefix=/home/gaurav/workspace/warped2/build
make
make install

cd /home/gaurav/workspace/warped2-models/
make clean
autoreconf -i && ./configure --with-warped=/home/gaurav/workspace/warped2/build && make
