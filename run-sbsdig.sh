#!/bin/bash

# ------------------------------------------------------------------------- #
# This script runs sbsdig jobs.                                             #
# ---------                                                                 #
# P. Datta <pdbforce@jlab.org> CREATED 11-09-2022                           #
# ---------                                                                 #
# ** Do not tamper with this sticker! Log any updates to the script above.  #
# ------------------------------------------------------------------------- #

#SBATCH --partition=production
#SBATCH --account=halla
#SBATCH --mem-per-cpu=1500

# list of arguments
txtfile=$1 # .txt file containing input file paths
infilename=$2
gemconfig=$3 # valid options: 8,10,12 (Represents # GEM modules)
run_on_ifarm=$4
g4sbsenv=$5
libsbsdigenv=$6
ANAVER=$7      # Analyzer version
useJLABENV=$8  # Use 12gev_env instead of modulefiles?
JLABENV=$9     # /site/12gev_phys/softenv.sh version
sbsconfig=${10}  #GEN2,GEN3,GEN4,GEN4b

# paths to necessary libraries (ONLY User specific part) ---- #
export G4SBS=/work/halla/sbs/vimukthi/g4sbs/install
export LIBSBSDIG=/work/halla/sbs/vimukthi/libsbsdig/install
# ----------------------------------------------------------- #

echo $G4SBS
echo $LIBSBSDIG

ifarmworkdir=${PWD}
if [[ $isifarm == 1 ]]; then
    SWIF_JOB_WORK_DIR=$ifarmworkdir
    echo -e "Running all jobs on ifarm!"
fi
echo 'Work directory = '$SWIF_JOB_WORK_DIR

# Enabling module
MODULES=/etc/profile.d/modules.sh 
if [[ $(type -t module) != function && -r ${MODULES} ]]; then 
    source ${MODULES} 
fi 
# Choosing software environment
if [[ (! -d /group/halla/modulefiles) || ($useJLABENV -eq 1) ]]; then 
    source /site/12gev_phys/softenv.sh $JLABENV
else 
    module purge
    module use /group/halla/modulefiles
    module load analyzer/$ANAVER
    module list
fi

# Setup sbsdig specific environments
source $G4SBS/bin/g4sbs.sh
source $LIBSBSDIG/bin/sbsdigenv.sh

# Choosing the right DB file depending on GEM config
if [[ $gemconfig -eq 8 ]]; then
    if [[ $sbsconfig == "GEN2" ]]; then
	dbfile=$LIBSBSDIG/db/db_gen_conf_8gemmodules_GEN2.dat
	echo -e "GEN2 digitization"
        echo -e $sbsconfig	
    elif [[ $sbsconfig == "GEN3" ]]; then 
	dbfile=$LIBSBSDIG/db/db_gen_conf_8gemmodules_GEN3.dat
	echo -e "GEN3 digitization"
        echo -e $sbsconfig
    elif [[ $sbsconfig == "GEN4" ]]; then
        dbfile=$LIBSBSDIG/db/db_gen_conf_8gemmodules_GEN4.dat
	echo -e "GEN4 digitization"
        echo -e $sbsconfig
    elif [[ $sbsconfig == "GEN4b" ]]; then
        dbfile=$LIBSBSDIG/db/db_gen_conf_8gemmodules_GEN4b.dat
	echo -e "GEN4b digitization"
        echo -e $sbsconfig
    else	    
    	dbfile=$LIBSBSDIG/db/db_gmn_conf_8gemmodules.dat
	echo -e "Generic digitization"
	echo -e $sbsconfig
    fi

elif [[ $gemconfig -eq 10 ]]; then
    dbfile=$LIBSBSDIG/db/db_gmn_conf_10gemmodules.dat
elif [[ $gemconfig -eq 12 ]]; then
    dbfile=$LIBSBSDIG/db/db_gmn_conf_12gemmodules.dat
else
    echo -e "[run-sbsdig.sh] ERROR!! Enter valid GEM config!"
    exit;
fi

# creating input text file
echo $infilename >>$txtfile

# run the sbsdig command
sbsdig $dbfile $txtfile

# cleaning up the work directory
rm $txtfile
