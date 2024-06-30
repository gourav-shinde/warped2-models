#!/bin/bash
# Allows batch runs of simulations. Saves results to log files

export ROOTPATH="/home/shindegy"

# run if user hits control-c
function control_c() {
    echo -en "*** Ouch! Exiting ***\n"
    exit $?
}


# Install WARPED-2 and build WARPED-2 models
# build <rootPath> <gitBranch> <mpiIncludePath> <mpiLibraryPath> <additionalFlags>
function build {
    rootPath=$1
    export gitBranch=$2
    export mpiIncludePath=/usr/lib/x86_64-linux-gnu/openmpi/include
    additionalFlags=$3

    garbageSearch="cincinnati"

    if [ "$additionalFlags" != "" ]
    then
        echo -e "\nInstalling WARPED2:$gitBranch with additional flag(s) $additionalFlags"
    else
        echo -e "\nInstalling WARPED2:$gitBranch"
    fi

    cd $rootPath/warped2/
    git restore *
    git checkout $gitBranch
    git pull
    autoreconf -i | grep $garbageSearch
    ./configure --with-mpi-includedir=$mpiIncludePath \
        --prefix=$rootPath/installation/ \
        $additionalFlags CXXFLAGS='-g -O3'| grep $garbageSearch
    make -s clean all | grep $garbageSearch
    make -j 8 install | grep $garbageSearch

    echo -e "Building WARPED2-MODELS"

    cd $rootPath/warped2-models/
    autoreconf -i | grep $garbageSearch
    ./configure --with-warped=$rootPath/installation/ CXXFLAGS='-g -O3' CXX=mpicxx | grep $garbageSearch
    make -j 8 | grep $garbageSearch

    cd $rootPath/warped2-models/scripts/

    buildCmd="build $rootPath $gitBranch \"$additionalFlags\""
    echo $buildCmd >> $errlogFile

    sleep 10
}

# Install WARPED-2 and build WARPED-2 models for LadderQ, Unsorted Bottom and Lockfree
# buildLadder <rootPath> <gitBranch> <mpiIncludePath> <mpiLibraryPath> <additionalFlags> <bottomSize>
function buildLadder {
    rootPath=$1
    gitBranch=$2
    mpiIncludePath=$3
    mpiLibraryPath=$4
    additionalFlags=$5
    bottomSize=$6

    garbageSearch="cincinnati"

    if [ "$additionalFlags" != "" ]
    then
        echo -e "\nInstalling LadderQueue / Unsorted Bottom with flag(s) $additionalFlags"
    else
        echo -e "\nInstalling Lockfree Unsorted Bottom"
    fi

    echo -e "Bottom Size = $bottomSize"

    cd $rootPath/warped2/
    git checkout src/LadderQueue.hpp
    git checkout $gitBranch
    git pull
    sed -i '/#define THRESHOLD/c\#define THRESHOLD '$bottomSize'' src/LadderQueue.hpp
    autoreconf -i | grep $garbageSearch
    ./configure --with-mpi-includedir=$mpiIncludePath \
        --with-mpi-libdir=$mpiLibraryPath --prefix=$rootPath/installation/ \
        $additionalFlags | grep $garbageSearch
    make -s clean all | grep $garbageSearch
    make install | grep $garbageSearch
    git checkout src/LadderQueue.hpp

    echo -e "Building WARPED2-MODELS"

    cd $rootPath/warped2-models/
    autoreconf -i | grep $garbageSearch
    ./configure --with-warped=$rootPath/installation/ | grep $garbageSearch
    make -s clean all | grep $garbageSearch

    cd $rootPath/warped2-models/scripts/

    buildCmd="buildLadder $rootPath $gitBranch $mpiIncludePath $mpiLibraryPath \"$additionalFlags\" $bottomSize"
    echo $buildCmd >> $errlogFile

    sleep 10
}

# Run simulations for STL MultiSet, Splay, LadderQ, Unsorted Bottom (Locked and Lockfree)
# runScheduleQ  <testCycles> <timeoutPeriod> <model> <modelCmd>
#               <maxSimTime> <workerThreads> <scheduleQType>
#               <scheduleQCount> <isLpMigrationOn> <gvtMethod>
#               <gvtPeriod> <stateSavePeriod>
function runScheduleQ {
    testCycles=$1
    timeoutPeriod=$2
    model=$3
    modelCmd=$4
    maxSimTime=${5}
    workerThreads=${6}
    scheduleQCount=${7}
    gvtMethod=${8}
    gvtPeriod=${9}
    stateSavePeriod=${10}
    branch=${gitBranch}

    logFile="logs/scheduleq.csv"

    header="branch,Model,Model_Command,Max_Simulation_Time,Worker_Thread_Count,Schedule_Queue_Type,\
            Schedule_Queue_Count,is_LP_Migration_ON,GVT_Method,State_Save_Period,\
            Simulation_Runtime_(secs.),Number_of_Objects,Local_Positive_Events_Sent,\
            Remote_Positive_Events_Sent,Local_Negative_Events_Sent,Remote_Negative_Events_Sent,\
            Primary_Rollbacks,Secondary_Rollbacks,Coast_Forwarded_Events,Cancelled_Events,\
            Events_Processed,Events_Committed,Events_for_Starved_Objects,\
            Sched_Event_Swaps_Success,Sched_Event_Swaps_Failed,Average_Memory_Usage_(MB)"

    headerRefined=`echo $header | sed -e 's/\t//g' -e 's/ //g'`

    if grep --quiet --no-messages $headerRefined $logFile
    then
        echo -e "\nData will now be recorded in $logFile"
    else
        echo -e "\nNew logfile $logFile created"
        echo $headerRefined >> $logFile
    fi

    for ((iteration=1; iteration <= $testCycles; iteration++))
    do
        cd ../models/$model/
        outMsg="\n($iteration/$testCycles) $modelCmd : $workerThreads threads, \
                $scheduleQCount , is LP migration on: $isLpMigrationOn, \
                GVT: $gvtMethod-$gvtPeriod, state saving period: $stateSavePeriod, \
                max sim time: $maxSimTime"
        echo -e $outMsg

        tmpFile=`tempfile`
        echo -e "non unified $sceduleQCount"
        runCommand="$modelCmd \
                    --max-sim-time $maxSimTime \
                    --time-warp-worker-threads $workerThreads \
                    --time-warp-scheduler-count $scheduleQCount \
                    --time-warp-gvt-calculation-method $gvtMethod \
                    --time-warp-gvt-calculation-period $gvtPeriod  \
                    --time-warp-state-saving-period $stateSavePeriod \
                    --time-warp-statistics-file $tmpFile"

        timeout $timeoutPeriod bash -c "$runCommand" | grep -e "Simulation completed in " -e "Type of Schedule queue: "

        statsRaw=`cat $tmpFile | grep "Total,"`
        rm $tmpFile
        cd ../../scripts/

        if [ "$statsRaw" != "" ]
        then
            # Parse stats
            # Write to log file
            totalStats="$branch,$model,"$modelCmd",$maxSimTime,$workerThreads,"multiset",\
                        $scheduleQCount,$isLpMigrationOn,$gvtMethod,$gvtPeriod,\
                        $stateSavePeriod,$statsRaw"
            statsRefined=`echo $totalStats | sed -e 's/Total,//g' -e 's/\t//g' -e 's/ //g'`
            echo $statsRefined >> $logFile
        else
            errMsg="runScheduleQ 1 $timeoutPeriod $model \"$modelCmd \" $maxSimTime \
                    $workerThreads \ $scheduleQCount $isLpMigrationOn \
                    $gvtMethod $gvtPeriod $stateSavePeriod"
            errMsgRefined=`echo $errMsg | sed -e 's/\t//g'`
            echo $errMsgRefined >> $errlogFile
        fi

        sleep 10
    done
}



# Run simulations for STL MultiSet, Splay, LadderQ, Unsorted Bottom (Locked and Lockfree)
# runScheduleQ  <testCycles> <timeoutPeriod> <model> <modelCmd>
#               <maxSimTime> <workerThreads> <scheduleQType>
#               <scheduleQCount> <isLpMigrationOn> <gvtMethod>
#               <gvtPeriod> <stateSavePeriod>
function runUnifiedQ {
    testCycles=$1
    timeoutPeriod=$2
    model=$3
    modelCmd=$4
    maxSimTime=${5}
    workerThreads=${6}
    gvtPeriod=${7}
    stateSavePeriod=${8}
    branch=$(gitBranch)

    logFile="logs/scheduleq.csv"

    header="branch,Model,Model_Command,Max_Simulation_Time,Worker_Thread_Count,Schedule_Queue_Type,\
            Schedule_Queue_Count,is_LP_Migration_ON,GVT_Method,State_Save_Period,\
            Simulation_Runtime_(secs.),Number_of_Objects,Local_Positive_Events_Sent,\
            Remote_Positive_Events_Sent,Local_Negative_Events_Sent,Remote_Negative_Events_Sent,\
            Primary_Rollbacks,Secondary_Rollbacks,Coast_Forwarded_Events,Cancelled_Events,\
            Events_Processed,Events_Committed,Events_for_Starved_Objects,\
            Sched_Event_Swaps_Success,Sched_Event_Swaps_Failed,Average_Memory_Usage_(MB)"

    headerRefined=`echo $header | sed -e 's/\t//g' -e 's/ //g'`

    if grep --quiet --no-messages $headerRefined $logFile
    then
        echo -e "\nData will now be recorded in $logFile"
    else
        echo -e "\nNew logfile $logFile created"
        echo $headerRefined >> $logFile
    fi

    for ((iteration=1; iteration <= $testCycles; iteration++))
    do
        cd ../models/$model/
        outMsg="\n($iteration/$testCycles) $modelCmd : $workerThreads threads, \
                $workerThread , is LP migration on: $isLpMigrationOn, \
                GVT: $gvtMethod-$gvtPeriod, state saving period: $stateSavePeriod, \
                max sim time: $maxSimTime"
        echo -e $outMsg

        tmpFile=`tempfile`
        
        runCommand="$modelCmd \
                --max-sim-time $maxSimTime \
                --time-warp-worker-threads $workerThreads \
                --time-warp-gvt-calculation-period $gvtPeriod  \
                --time-warp-state-saving-period $stateSavePeriod \
                --time-warp-statistics-file $tmpFile"
        timeout $timeoutPeriod bash -c "$runCommand" | grep -e "Simulation completed in " -e "Type of Schedule queue: "

        statsRaw=`cat $tmpFile | grep "Total,"`
        rm $tmpFile
        cd ../../scripts/

        if [ "$statsRaw" != "" ]
        then
            # Parse stats
            # Write to log file
            totalStats="$branch,$model,"$modelCmd",$maxSimTime,$workerThreads, "multiset",\
                        $workerThreads,$isLpMigrationOn,$gvtMethod,$gvtPeriod,\
                        $stateSavePeriod,$statsRaw"
            
            statsRefined=`echo $totalStats | sed -e 's/Total,//g' -e 's/\t//g' -e 's/ //g'`
            echo $statsRefined >> $logFile
        else
            errMsg="runUnifiedQ 1 $timeoutPeriod $model \"$modelCmd\" $maxSimTime \
                    $workerThreads \"$scheduleQType\" $workerThreads $isLpMigrationOn \
                    $gvtMethod $gvtPeriod $stateSavePeriod"
            errMsgRefined=`echo $errMsg | sed -e 's/\t//g'`
            echo $errMsgRefined >> $errlogFile
        fi

        sleep 10
    done
}

# Run bulk simulations for stl-multiset, splay-tree, ladder-queue, unsorted-bottom and lockfree
# permuteConfigScheduleQ  <testCycles> <timeoutPeriod> <model> <modelCmd>
#           <arrMaxSimTime> <arrWorkerThreads> <scheduleQType> <arrScheduleQCount>
#           <arrLpMigration> <arrGvtMethod> <arrGvtPeriod> <stateSavePeriod>
function permuteConfigScheduleQ() {
    #print all arguments
    echo -e "permuteConfigScheduleQ: $@"
    echo -e "1 : $1"
    echo -e "2 : $2"
    echo -e "3 : $3"
    echo -e "4 : $4"
    echo -e "5 : $5"
    echo -e "6 : $6"
    echo -e "7 : $7"
    echo -e "8 : $8"
    echo -e "9 : $9" 
    testCycles=$1
    timeoutPeriod=$2
    model=$3
    modelCmd=$4
    local -n arrMaxSimTime=${5}
    local -n arrWorkerThreads=${6}
    local -n arrScheduleQCount=${6}
    local -n arrGvtMethod=${8}
    local -n arrGvtPeriod=${9}
    local -n arrStateSavePeriod=${10}

    outMsg="\warped : $modelCmd : max sim time: $arrMaxSimTime, : worker threads: $arrWorkerThreads, \
             schedule queue count: $arrScheduleQCount, \
            GVT: $arrGvtMethod-$arrGvtPeriod, state saving period: $arrStateSavePeriod"
    echo -e $outMsg

    for gvtMethod in "${arrGvtMethod[@]}"
    do
        for gvtPeriod in "${arrGvtPeriod[@]}"
        do
            for stateSavePeriod in "${arrStateSavePeriod[@]}"
            do
                for maxSimTime in "${arrMaxSimTime[@]}"
                do 
                    for workerThreads in "${arrWorkerThreads[@]}"
                    do
                        echo -e "hmm went to last loop"
                        runScheduleQ    $testCycles $timeoutPeriod $model "$modelCmd" \
                                        $maxSimTime $workerThreads \
                                        $workerThreads $gvtMethod \
                                        $gvtPeriod $stateSavePeriod
                        #workerThreads =schedule queue count
                    done
                done
            done
        done
    done
}


function permuteConfigUnifiedQ() {
    #print all arguments
    echo -e "permuteConfigScheduleQ: $@"
    echo -e "1 : $1"
    echo -e "2 : $2"
    echo -e "3 : $3"
    echo -e "4 : $4"
    echo -e "5 : $5"
    echo -e "6 : $6"
    echo -e "7 : $7"
    echo -e "8 : $8"
    echo -e "9 : $9" 
    testCycles=$1
    timeoutPeriod=$2
    model=$3
    modelCmd=$4
    local -n arrMaxSimTime=${5}
    local -n arrWorkerThreads=${6}
    local -n arrGvtMethod=${7}
    local -n arrGvtPeriod=${8}
    local -n arrStateSavePeriod=${9}

    outMsg="\warped : $modelCmd : max sim time: $arrMaxSimTime, : worker threads: $arrWorkerThreads, \
            GVT: $arrGvtMethod-$arrGvtPeriod, state saving period: $arrStateSavePeriod"
    echo -e $outMsg

    for gvtMethod in "${arrGvtMethod[@]}"
    do
        for gvtPeriod in "${arrGvtPeriod[@]}"
        do
            for stateSavePeriod in "${arrStateSavePeriod[@]}"
            do
                for maxSimTime in "${arrMaxSimTime[@]}"
                do 
                    for workerThreads in "${arrWorkerThreads[@]}"
                    do
                        echo -e "hmm went to last unified loop"
                        runUnifiedQ    $testCycles $timeoutPeriod $model "$modelCmd" \
                                        $maxSimTime $workerThreads \
                                        $gvtPeriod $stateSavePeriod
                        #workerThreads =schedule queue count
                    done
                done
            done
        done
    done
}



# Run sequential simulation
# runSequential <timeoutPeriod> <model> <modelCmd> <maxSimTime>
function runSequential {
    timeoutPeriod=$1
    model=$2
    modelCmd=$3
    maxSimTime=$4

    outMsg="\nSequential : $modelCmd : max sim time: $maxSimTime"
    echo -e $outMsg

    cd ../models/$model/
    runCommand="$modelCmd \
                --simulation-type sequential \
                --max-sim-time $maxSimTime"
    result=$(timeout $timeoutPeriod bash -c "$runCommand" | \
                grep -e "Simulation completed in " -e "Events processed: " \
                -e "LP count: " | grep -Eo '[+-]?[0-9]+([.][0-9]+)?')
    echo -e "$result"

    cd ../../scripts/
    logFile="logs/sequential.dat"
    echo $result > $logFile

    sleep 10
}

hostName=`hostname`
date=`date +"%m-%d-%y_%T"`
errlogFile="logs/errlog_${date}.config"

trap control_c SIGINT

. $1

