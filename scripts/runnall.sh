#!/bin/bash
# Allows batch runs of simulations. Saves results to log files
folder=$1
for config in config/$1/* ; do
    echo $config
    ./configSimulate.sh $config
done
