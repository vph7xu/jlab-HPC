#!/bin/bash

# ------------------------------------------------------------------------- #
# This script runs SIMC events on ifarm and then uses the output ROOT files #
# to submit corresponding g4sbs, sbsdig, and replay jobs to the batch farm. #
# There is a flag that can be set to run all the jobs on ifarm as well.     #
# ---------                                                                 #
# P. Datta <pdbforce@jlab.org> CREATED 04-19-2023                           #
# ---------                                                                 #
# ** Do not tamper with this sticker! Log any updates to the script below.  #
# ------------------------------------------------------------------------- #

# ------------------- Notes and Instructions (READ BEFORE EXECUTION) -------------------- #
# --------------------------------------------------------------------------------------- #
# 1. This script takes 5 arguments:                                                       #
#    a. SIMC infile w/o file extention. Must be located at $SIMC/infiles directory.       #
#    b. SBS configuration (Valid options: GMN4,GMN7,GMN11,GMN14,GMN8,GMN9,GEN1,GEN2,GEN3,GEN4) #
#    c. First job id.                                                                     #
#    d. Total no. of jobs to submit.                                                      #
#    e. Flag to force all jobs to run on ifarm. (1=>YES) Very useful for debugging.       #
# 2. Total no. of events applies to both SIMC and g4sbs for consistency.                  #
# 3. Be sure to edit "workflowname" variable appropriately before executing script.       #
# 4. Be sure to edit "outdirpath" variable appropriately before executing script.         #
# 5. After all the SIMC jobs are finished a summary CSV file, $infile_summary.csv get     # 
#    created and kept in $outdirpath/simcoutdir, which contain the important              #
#    normalization factors for all jobs.                                                  #
# 6. List of interdependencies: utility.py, run-g4sbs-w-simc.sh, run-sbsdig.sh, run-      #
#    simc.sh, run-digi-replay.sh | All these scripts must be present in the $SCRIPT_DIR   #
# --------------------------------------------------------------------------------------- #

# Setting necessary environments via setenv.sh
source setenv.sh

# ------ Variables needed to be set properly for successful execution ------ #
# -------------------------------------------------------------------------- #
# SIMC input file (don't add file extension). Must be located at $SIMC/infiles. 
# G4SBS macro should have same name as SIMC input file just with different 
# file extention and should be located at $G4SBS/scripts.
infile=$1
sbsconfig=$2    # SBS configuration (Valid options: 4,7,11,14,8,9
nevents=$3      # No. of SIMC (and g4sbs) events to generate
fjobid=$4       # first job id
njobs=$5        # total no. of jobs to submit 
run_on_ifarm=$6 # 1=>Yes (If true, runs all jobs on ifarm)
genconfig=$7
# ----/\---- Above variables are taken as arguments to this script ---/\---- # 
# Workflow name
workflowname=simc_test_gen4_n_noNRad_1106
# Specify a directory on volatile to store simc, g4sbs, sbsdig, & replayed outfiles.
# Working on a single directory is convenient & safe for the above mentioned
# four processes to run coherently without any error.
outdirpath=/volatile/halla/sbs/vimukthi/simc_g4sbs/He3een_GEN4_PSfix_noNRad_1106/
# -------------------------------------------------------------------------- #

# ------ Variables to allocate time and memory for each type of jobs  ------ #
# -------------------------------------------------------------------------- #
# SIMC jobs
SIMCJOBram='200MB'
SIMCJOBdisk='250MB'
SIMCJOBtime='24h'
# g4sbs jobs
G4SBSJOBram='1200MB'
G4SBSJOBdisk='1GB'
G4SBSJOBtime='24h'
# sbsdig jobs
SBSDIGJOBram='1200MB'
SBSDIGJOBdisk='100MB'
SBSDIGJOBtime='6h'
# replay jobs
REPLAYJOBram='3200MB'
REPLAYJOBdisk='1GB'
REPLAYJOBtime='6h'
# -------------------------------------------------------------------------- #

# Sanity check 0: Checking the environments
if [[ ! -d $SCRIPT_DIR ]]; then
    echo -e '\nERROR!! Please set "SCRIPT_DIR" path properly in setenv.sh script!\n'; exit;
elif [[ ! -d $SIMC ]]; then
    echo -e '\nERROR!! Please set "SIMC" path properly in setenv.sh script!\n'; exit;
elif [[ ! -d $G4SBS ]]; then
    echo -e '\nERROR!! Please set "G4SBS" path properly in setenv.sh script!\n'; exit;
elif [[ ! -d $LIBSBSDIG ]]; then
    echo -e '\nERROR!! Please set "LIBSBSDIG" path properly in setenv.sh script!\n'; exit;
elif [[ (! -d $ANALYZER) && ($useJLABENV -eq 1) ]]; then
    echo -e '\nERROR!! Please set "ANALYZER" path properly in setenv.sh script!\n'; exit;
elif [[ ! -d $SBSOFFLINE ]]; then
    echo -e '\nERROR!! Please set "SBSOFFLINE" path properly in setenv.sh script!\n'; exit;
elif [[ ! -d $SBS_REPLAY ]]; then
    echo -e '\nERROR!! Please set "SBS_REPLAY" path properly in setenv.sh script!\n'; exit;
fi

# Sanity check 1: Validating the number of arguments provided
if [[ "$#" -ne 7 ]]; then
    echo -e " \n --!!--\n ERROR! Illegal number of arguments!! \n ------"
    echo -e " This script takes 6 arguments: <infile> <sbsconfig> <fjobid> <njobs> <run_on_ifarm>"
    echo -e "  1. <infile>       : SIMC infile w/o file extention. Must be located at SIMC/infiles directory."
    echo -e "  2. <sbsconfig>    : SBS configuration (Valid options: GMN4,GMN7,GMN11,GMN14,GMN8,GMN9,GEN1,GEN2,GEN3,GEN4)."  
    echo -e "  3. <nevents>      : No. of SIMC (and g4sbs) events to generate per job."  
    echo -e "  4. <fjobid>       : First job id."  
    echo -e "  5. <njobs>        : Total no. of jobs to submit."
    echo -e "  6. <run_on_ifarm> : 1=>Yes (If true, runs all jobs on ifarm)"
    echo -e "  7. <genconfig>    : for GEN (GENX)"
    echo -e " ------"
    echo -e ' ** Make sure "workflowname" & "outdirpath" variables are set properly in the script.'
    echo -e ' ** Read the "Notes and Instructions" block at the top of script for more information.\n'
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
		read -p "Enter desired outdirpath   : " temp2
		outdirpath=$temp2		
		break; ;;
	esac
    done
fi

# Sanity check 2: Create the output directory if necessary
if [[ ! -d $outdirpath ]]; then
    { #try
	mkdir $outdirpath
    } || { #catch
	echo -e "\n!!!!!!!! ERROR !!!!!!!!!"
	echo -e $outdirpath "doesn't exist and cannot be created!\n"
	exit;
    }
fi

# Sanity check 3: Check for the existance of SIMC infile
simcmacro=$SIMC'/infiles/'$infile'.inp'
if [[ ! -f $simcmacro ]]; then
    echo -e "\n!!!!!!!! ERROR !!!!!!!!!"
    echo -e "SIMC infile, $simcmacro, doesn't exist! Aborting!\n"
    exit;
fi

# Sanity check 4: Finding matching G4SBS preinit macro for SIMC infile
g4sbsmacro=$G4SBS'/scripts/'$infile'.mac'
if [[ ! -f $g4sbsmacro ]]; then
    echo -e "\n!!!!!!!! ERROR !!!!!!!!!"
    echo -e "G4SBS preinit macro, $g4sbsmacro, doesn't exist! Aborting!\n"
    exit;
fi

# Sanity check 5: Check SIMC input file character count
charcount=$(echo -n $infile | wc -c) 
if [[ $charcount -gt 100 ]]; then
    echo -e "\n!!!!!!!! ERROR !!!!!!!!!"
    echo -e "SIMC infile name must have < 100 characters.."
    echo -e "Given infile, $infile, has $charcount characters!"
    echo -e "Aborting.."
    exit;
fi

# Creating a sub-directory (simcout) to keep all the SIMC outputs in one place
export simcoutdir=$outdirpath'/simcout'
if [[ ! -d $simcoutdir ]]; then
    mkdir $simcoutdir
fi

# # Creating a CSV file to write a summary table of normalization factors by job
# simcnormtable=$simcoutdir'/'$infile'_summary.csv'

# Reading SIMC infile ("ngen" flag) to determine no. of g4sbs events to generate
#nevents=$(python3 $SCRIPT_DIR'/'utility.py 'grab_simc_param_value' $simcmacro 'ngen')
if [[ $nevents -lt 0 ]]; then
    echo -e "\n!!!!!!!! ERROR !!!!!!!!!"
    echo -e "Illegal no. of events! nevents = $nevents | Aborting!\n"
    exit;
else
    echo -e "\n ** $nevents SIMC (and g4sbs) events will be generated per job!"
fi

# Creating the workflow
if [[ $run_on_ifarm -ne 1 ]]; then
    swif2 create $workflowname
else
    echo -e "\nRunning all jobs on ifarm!\n"
fi

# Choosing the right GEM config for digitization
gemconfig=0
if [[ ($sbsconfig == GMN4) || ($sbsconfig == GMN7) ]]; then
    gemconfig=12
elif [[ $sbsconfig == GMN11 ]]; then
    gemconfig=10
elif [[ ($sbsconfig == GMN14) || ($sbsconfig == GMN8) || ($sbsconfig == GMN9) || ($sbsconfig == GEN1) || ($sbsconfig == GEN2) || ($sbsconfig == GEN3) || ($sbsconfig == GEN4) ]]; then
    gemconfig=8
else
    echo -e "Enter valid SBS config! Valid options: GMN4,GMN7,GMN11,GMN14,GMN8,GMN9,GEN1,GEN2,GEN3,GEN4"
    exit;
fi

# Loop to create jobs
for ((i=$fjobid; i<$((fjobid+njobs)); i++))
do
    # submitting SIMC jobs
    simcjobname=$infile'_simc_job_'$i
    randomseed=$(od -An -N3 -i /dev/urandom)
    
    simcscript=$SCRIPT_DIR'/run-simc.sh'' '$infile' '$nevents' '$randomseed' '$i' '$simcoutdir' '$run_on_ifarm' '$SIMC' '$SCRIPT_DIR' '$ANAVER' '$useJLABENV' '$JLABENV

    if [[ $run_on_ifarm -ne 1 ]]; then
	swif2 add-job -workflow $workflowname -partition production -name $simcjobname -cores 1 -disk $SIMCJOBdisk -ram $SIMCJOBram -time $SIMCJOBtime $simcscript
    else
	$simcscript
    fi
    simcoutfile=$simcoutdir'/'$infile'_job_'$i'.root'

    # submitting g4sbs jobs using SIMC outfiles
    outfilebase=$infile'_job_'$i
    postscript=$infile'_job_'$i'.mac'
    g4sbsjobname=$infile'_g4sbs_job_'$i

    g4sbsscript=$SCRIPT_DIR'/run-g4sbs-w-simc.sh'' '$infile' '$postscript' '$nevents' '$outfilebase' '$outdirpath' '$simcoutfile' '$run_on_ifarm' '$G4SBS' '$ANAVER' '$useJLABENV' '$JLABENV

    if [[ $run_on_ifarm -ne 1 ]]; then
	swif2 add-job -workflow $workflowname -antecedent $simcjobname -partition production -name $g4sbsjobname -cores 1 -disk $G4SBSJOBdisk -ram $G4SBSJOBram -time $G4SBSJOBtime $g4sbsscript
    else
	$g4sbsscript
    fi

    # now, it's time for digitization
    txtfile=$infile'_job_'$i'.txt'
    sbsdigjobname=$infile'_digi_job_'$i
    sbsdiginfile=$outdirpath'/'$outfilebase'.root'

    sbsdigscript=$SCRIPT_DIR'/run-sbsdig.sh'' '$txtfile' '$sbsdiginfile' '$gemconfig' '$run_on_ifarm' '$G4SBS' '$LIBSBSDIG' '$ANAVER' '$useJLABENV' '$JLABENV' '$genconfig
    
    if [[ $run_on_ifarm -ne 1 ]]; then
	swif2 add-job -workflow $workflowname -antecedent $g4sbsjobname -partition production -name $sbsdigjobname -cores 1 -disk $SBSDIGJOBdisk -ram $SBSDIGJOBram -time $SBSDIGJOBtime $sbsdigscript
    else
	$sbsdigscript
    fi

    # finally, lets replay the digitized data
    digireplayinfile=$infile'_job_'$i
    digireplayjobname=$infile'_digi_replay_job_'$i

    digireplayscript=$SCRIPT_DIR'/run-digi-replay.sh'' '$digireplayinfile' '$sbsconfig' '-1' '$outdirpath' '$run_on_ifarm' '$ANALYZER' '$SBSOFFLINE' '$SBS_REPLAY' '$ANAVER' '$useJLABENV' '$JLABENV
    
    if [[ $run_on_ifarm -ne 1 ]]; then
	swif2 add-job -workflow $workflowname -antecedent $sbsdigjobname -partition production -name $digireplayjobname -cores 1 -disk $REPLAYJOBdisk -ram $REPLAYJOBram -time $REPLAYJOBtime $digireplayscript
    else
	$digireplayscript
    fi
done

# # keep a copy of SIMC job summary file in the $outdirpath as well
# cp $simcnormtable $outdirpath

# run the workflow and then print status
if [[ $run_on_ifarm -ne 1 ]]; then
    swif2 run $workflowname
    echo -e "\n Getting workflow status.. [may take a few minutes!] \n"
    swif2 status $workflowname
fi
