#!/bin/bash

##################################################################################################################
# Motion Scrubbing (Censoring TRs with too much movement (Power 2012 Neuroimage)
#     1. Scrubbing
#       a. 0=No Scrubbing
#       b. 1=Motion Scrubbing
#       c. 2=No Scrubbing, Motion Scrubbing in parallel
##################################################################################################################

scriptPath=`perl -e 'use Cwd "abs_path";print abs_path(shift)' $0`
scriptDir=`dirname $scriptPath`
nuisancefeat=nuisancereg.feat
filename=run_motionscrub.m


function printCommandLine {
  echo "Usage: motionScrub.sh -f restingStateImage"
  echo " where"
  echo "  -E resting state image"
  echo "    *Top-level RestingState.nii.gz image"
  echo "  -h help"
  exit 1
}

# Parse Command line arguments
while getopts “hE:” OPTION
do
  case $OPTION in
    h)
      printCommandLine
      ;;
    E)
      epiData=$OPTARG
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




#### Motion scrubbing ############

echo "...Scrubbing data"
cat > $filename << EOF
% It is matlab script
addpath('${scriptDir}')
niftiScripts=['${scriptDir}','/Octave/nifti'];
addpath(niftiScripts)
funcvoldim=[${numXdim} ${numYdim} ${numZdim} ${numtimepoint}];
motionscrub('${indir}','${nuisancefeat}',funcvoldim)
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



#### Process Summary ############
echo "...Summarizing Results"

##Want to summarize motion-scrubbing output 
echo "ID,total_volumes,deleted_volumes,prop_deleted,resid_vols" > ${indir}/motion_scrubbing_info.txt


##Echo out the pertinent info for the motion-scrubbed/processed subjects

numvols=`fslinfo ${indir}/nuisancereg.feat/stats/res4d_normandscaled.nii | grep ^dim4 | awk '{print $2}'`
delvols=`cat ${indir}/nuisancereg.feat/stats/deleted_vols.txt | wc | awk '{print $2}'`
propdel=`echo ${numvols} ${delvols} | awk '{print ($2/$1)}'`
residvols=`echo ${numvols} ${delvols} | awk '{print ($1-$2)}'`
echo "${indir},${numvols},${delvols},${propdel},${residvols}" >> ${indir}/motion_scrubbing_info.txt

#Echo out motionscrub info to rsParams file
echo "epiNormMS=${indir}/nuisancereg.feat/stats/res4d_normandscaled_motionscrubbed.nii" >> $indir/rsParams



echo "<hr>" >> ${indir}/analysisResults.html
echo "<h2>Motion Scrubbing</h2>" >> ${indir}/analysisResults.html
echo "<b>Total Volumes</b>: $numvols<br>" >> ${indir}/analysisResults.html
echo "<b>Deleted Volumes</b>: $delvols<br>" >> ${indir}/analysisResults.html
echo "<b>Remaining Volumes</b>: $residvols<br>" >> ${indir}/analysisResults.html

scrubDataCheck=`cat $indir/$nuisancefeat/stats/deleted_vols.txt | head -1`
if [[ $scrubDataCheck != "" ]]; then
  echo "<b>Scrubbed TR</b>: `cat ${indir}/nuisancereg.feat/stats/deleted_vols.txt | awk '{$1=$1}1'`<br>" >> ${indir}/analysisResults.html
fi

#################################


echo "$0 Complete"
echo ""
echo ""



