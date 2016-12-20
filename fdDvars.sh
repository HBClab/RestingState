#!/bin/bash

##################################################################################################################
# FD and DVARS calculations (but not censoring TRs with too much movement (Power 2012 Neuroimage)
##################################################################################################################

scriptPath=`perl -e 'use Cwd "abs_path";print abs_path(shift)' $0`
scriptDir=`dirname $scriptPath`
#nuisancefeat=nuisancereg.feat
filename=run_fd_dvars.m


function printCommandLine {
  echo "Usage: fd_dvars.sh -E restingStateImage -n regressionDir"
  echo " where"
  echo "  -E resting state image"
  echo "    *Top-level RestingStateRaw.nii.gz image"
  echo "    **This MUST be a 4D file in order to use the time-dimension"
  echo "   -n nuisance feat directory"
  echo "    *e.g. nuiscance_classic_aroma.feat"
  echo "  -h help"
  exit 1
}

# Parse Command line arguments
while getopts “hE:n:” OPTION
do
  case $OPTION in
    h)
      printCommandLine
      ;;
    E)
      epiData=$OPTARG
      ;;
    n)
      nuisancefeat=$OPTARG
      ;;
    ?)
      echo "ERROR: Invalid option"
      printCommandLine
      ;;
     esac
done


if [ "$epiData" == "" ]; then
  echo "Error: The restingStateImage (-E) is a required option."
  exit 1
fi

#Default to nuisancereg.feat if directory is not specified
if [[ ${nuisancefeat} == "" ]]; then
  nuisancefeat=nuisancereg.feat
  echo "Regression directory not specified.  Defaulting to 'nuisancereg.feat'."
fi

indir=`dirname $epiData`


##Echo out all input parameters into a log
logDir=$indir
echo "$scriptPath" >> $logDir/rsParams_log
echo "------------------------------------" >> $logDir/rsParams_log
echo "-E $epiData" >> $logDir/rsParams_log
echo "`date`" >> $logDir/rsParams_log
echo "" >> $logDir/rsParams_log
echo "" >> $logDir/rsParams_log





echo "Running $0 ..."


cd $indir

# Extract image dimensions from the NIFTI File
numXdim=`fslinfo $epiData | grep ^dim1 | awk '{print $2}'`
numYdim=`fslinfo $epiData | grep ^dim2 | awk '{print $2}'`
numZdim=`fslinfo $epiData | grep ^dim3 | awk '{print $2}'`
numtimepoint=`fslinfo $epiData | grep ^dim4 | awk '{print $2}'`




#### FD and DVARS Calculations ###

echo "...Calculating FD and DVARS"
cat > $filename << EOF
% It is matlab script
addpath('${scriptDir}')
niftiScripts=['${scriptDir}','/Octave/nifti'];
addpath(niftiScripts)
funcvoldim=[${numXdim} ${numYdim} ${numZdim} ${numtimepoint}];
fd_dvars('${indir}','${nuisancefeat}',funcvoldim)
quit
EOF



# Run script using Matlab or Octave
haveMatlab=`which matlab`
if [ "$haveMatlab" == "" ]; then
  octave --no-window-system $indir/$filename 
else
  matlab -nodisplay -r "run $indir/$filename"
fi

#################################



echo "$0 Complete"
echo ""
echo ""



