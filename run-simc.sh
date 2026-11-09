#!/bin/bash

# ------------------------------------------------------------------------- #
# This script runs SIMC simulation jobs.                                    #
# ---------                                                                 #
# P. Datta <pdbforce@jlab.org> CREATED 03-20-2024                           #
# ---------                                                                 #
# ** Do not tamper with this sticker! Log any updates to the script above.  #
# ------------------------------------------------------------------------- #

#SBATCH --partition=production
#SBATCH --account=halla
#SBATCH --mem-per-cpu=100

# list of arguments
infile=$1
nevents=$2
randomseed=$3
jobid=$4
simcoutdir=$5
run_on_ifarm=$6
simcenv=$7
scriptdirenv=$8
ANAVER=$9        # Analyzer version
useJLABENV=${10} # Use 12gev_env instead of modulefiles?
JLABENV=${11}    # /site/12gev_phys/softenv.sh version

# paths to necessary libraries (ONLY User specific part) ---- #
export SIMC=$simcenv
export SCRIPT_DIR=$scriptdirenv
# ----------------------------------------------------------- #

ifarmworkdir=${PWD}
if [[ $run_on_ifarm == 1 ]]; then
    SWIF_JOB_WORK_DIR=$ifarmworkdir
    echo -e "Running all jobs on ifarm!"
fi
echo -e 'Work directory = '$SWIF_JOB_WORK_DIR

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

# Generating SIMC events
# 1. going to SIMC directory
echo -e "Moving to $SIMC.."
pushd $SIMC >/dev/null

# 2. creating a copy of infile for the specific job
echo -e "Creating a copy of job specific infile.."
infilejob=$infile'_job_'$jobid
cp $SIMC'/infiles/'$infile'.inp' $SIMC'/infiles/'$infilejob'.inp'

# 3. make necessary modifications to the above file
sed -i "s/ngen.*/ngen = $nevents/" "$SIMC/infiles/$infilejob.inp"
sed -i "s/random_seed.*/random_seed = $randomseed/" "$SIMC/infiles/$infilejob.inp"

# 4. running the SIMC job
echo -e "Running the SIMC job.."
./run_simc_tree $infilejob

# 5. move all the related files to simcout
echo -e "Moviing SIMC output files.."
mv 'worksim/'$infilejob'.root' $simcoutdir 
mv 'outfiles/'$infilejob'_start_random_state.dat' $simcoutdir
mv 'outfiles/'$infilejob'.geni' $simcoutdir
mv 'outfiles/'$infilejob'.gen' $simcoutdir
mv 'outfiles/'$infilejob'.hist' $simcoutdir
mv 'runout/'$infilejob'.out' $simcoutdir
popd >/dev/null

# 6. Remove the job specific copy of infile
rm $SIMC'/infiles/'$infilejob'.inp'

# Abort if SIMC job wasn't successfull
simcoutfile=$simcoutdir'/'$infilejob'.root'
if [[ ! -f $simcoutfile ]]; then
    echo -e "\n!!!!!!!! ERROR !!!!!!!!!"
    echo -e "SIMC event generation failed! job_$jobid"
    exit;
fi
echo -e "\nSIMC event generation successful! job_$jobid\n"

# time to write summary table with normalization factors
echo -e "Adding normalization factors to the summary file.."
simcnormtable=$simcoutdir'/'$infile'_summary.csv'
if [[ ! -f $simcnormtable ]]; then
    python3 $SCRIPT_DIR'/'utility.py 'grab_simc_norm_factors' 'None' '1' > $simcnormtable
fi
python3 $SCRIPT_DIR'/'utility.py 'grab_simc_norm_factors' $simcoutdir'/'$infilejob'.hist' '0' >> $simcnormtable
