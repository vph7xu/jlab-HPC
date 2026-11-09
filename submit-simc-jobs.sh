#!/bin/bash

# ------------------------------------------------------------------------- #
# This script runs SIMC jobs on ifarm or submits them to batch farm.        #
# ---------                                                                 #
# P. Datta <pdbforce@jlab.org> CREATED 03-23-2024                           #
# ---------                                                                 #
# ** Do not tamper with this sticker! Log any updates to the script above.  #
# ------------------------------------------------------------------------- #

# Setting necessary environments via setenv.sh
source setenv.sh
if [[ ! -d $SCRIPT_DIR ]]; then
    echo -e '\nERROR!! Please set "SCRIPT_DIR" path properly in setenv.sh script!\n'; exit;
elif [[ ! -d $SIMC ]]; then
    echo -e '\nERROR!! Please set "SIMC" path properly in setenv.sh script!\n'; exit;
fi

# ------ Variables needed to be set properly for successful execution ------ #
# -------------------------------------------------------------------------- #
infile=$1       # SIMC infile w/o file extention (Must be located at $SIMC/infiles)
nevents=$2      # No. of events to generate per job
fjobid=$3       # first job id
njobs=$4        # total no. of jobs to submit 
run_on_ifarm=$5 # 1=>Yes (If true, runs all jobs on ifarm)
workflowname=
outdirpath='/volatile/halla/sbs/vimukthi/simc/'
# -------------------------------------------------------------------------- #

# ------ Variables to allocate time and memory for each type of jobs  ------ #
# -------------------------------------------------------------------------- #
# SIMC jobs
SIMCJOBdisk='250MB'
SIMCJOBram='100MB'
SIMCJOBtime='1h'
# -------------------------------------------------------------------------- #

# Validating the number of arguments provided
if [[ "$#" -ne 5 ]]; then
    echo -e "\n--!--\n Illegal number of arguments!!"
    echo -e " This script expects 5 arguments: <infile> <nevents> <fjobid> <njobs> <run_on_ifarm>\n"
    exit;
else 
    echo -e '\n------'
    echo -e ' Check the following variable(s):'
    if [[ $run_on_ifarm -ne 1 ]]; then
	echo -e ' "workflowname" : '$workflowname''
    fi
    echo -e ' "outdirpath"   : '$outdirpath' \n------'
    while true; do
	read -p "Do they look good? [y/n] " yn
	echo -e ""
	case $yn in
	    [Yy]*) 
		break; ;;
	    [Nn]*) 
		if [[ $run_on_ifarm -ne 1 ]]; then
		    read -p "Enter desired workflowname : " temp1
		    workflowname=$temp1
		fi
		read -p "Enter desired outdirpath : " temp2
		outdirpath=$temp2		
		break; ;;
	esac
    done
fi

# Sanity check: Check SIMC input file character count
charcount=$(echo -n $infile | wc -c) 
if [[ $charcount -gt 100 ]]; then
    echo -e "\n!!!!!!!! ERROR !!!!!!!!!"
    echo -e "Given infile, $infile, has $charcount characters!"
    echo -e "SIMC infile name must have < 100 characters.."
    echo -e "Aborting.."
    exit;
fi

# Sanity check: Create the output directory if necessary
if [[ ! -d $outdirpath ]]; then
    { #try
	mkdir $outdirpath
    } || { #catch
	echo -e "\n!!!!!!!! ERROR !!!!!!!!!"
	echo -e $outdirpath "doesn't exist and cannot be created!\n"
	exit;
    }
fi

# Creating the workflow
if [[ $run_on_ifarm -ne 1 ]]; then
    swif2 create $workflowname
else
    echo -e "\nRunning all jobs on ifarm!\n"
fi

for ((i=$fjobid; i<$((fjobid+njobs)); i++))
do

    # submitting SIMC jobs
    simcjobname=$infile'_simc_job_'$i
    randomseed=$(od -An -N3 -i /dev/urandom)
    
    simcscript=$SCRIPT_DIR'/run-simc.sh'' '$infile' '$nevents' '$randomseed' '$i' '$outdirpath' '$run_on_ifarm' '$SIMC' '$SCRIPT_DIR' '$ANAVER' '$useJLABENV' '$JLABENV

    if [[ $run_on_ifarm -ne 1 ]]; then
	swif2 add-job -workflow $workflowname -partition production -name $simcjobname -cores 1 -disk $SIMCJOBdisk -ram $SIMCJOBram -time $SIMCJOBtime $simcscript
    else
	$simcscript
    fi
done

# run the workflow and then print status
if [[ $run_on_ifarm -ne 1 ]]; then
    swif2 run $workflowname
    echo -e "\n Getting workflow status.. [may take a few minutes!] \n"
    swif2 status $workflowname
fi
