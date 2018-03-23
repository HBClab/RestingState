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
filename=run_motionscrub.m


function Usage {
  echo "Usage: motionScrub.sh -f restingStateImage"
  echo " where"
  echo "  -E resting state image"
  echo "    *Top-level RestingState.nii.gz image"
  echo "  -h help"
  exit 1
}

########## FSL's arg parsing functions ###################
get_opt1() {
    arg=$(echo $1 | sed 's/=.*//')
    echo $arg
}


get_imarg1() {
    arg=$(get_arg1 $1);
    arg=$($FSLDIR/bin/remove_ext $arg);
    echo $arg
}

get_arg1() {
    if [ X"`echo $1 | grep '='`" = X ] ; then
	echo "Option $1 requires an argument" 1>&2
	exit 1
    else
	arg=`echo $1 | sed 's/.*=//'`
	if [ X$arg = X ] ; then
	    echo "Option $1 requires an argument" 1>&2
	    exit 1
	fi
	echo $arg
    fi
}


# Parse Command line arguments
if [ $# -lt 1 ] ; then Usage; exit 0; fi
while [ $# -ge 1 ] ; do
    iarg=$(get_opt1 $1);
    case "$iarg"
	in
    --epi)
  	    epiData=`get_arg1 $1`;
        export epiData;
        indir=$(dirname $epiData);
        export indir;
        rawEpiDir=$(dirname $(x=$indir; while [ "$x" != "/" ] ; do x=`dirname "$x"`; find "$x" -maxdepth 1 -type f -name "mcImg.nii.gz"; done 2>/dev/null));
        export rawEpiDir
        if [ "$epiData" == "" ]; then
          echo "Error: The restingStateImage (-E) is a required option"
          exit 1
        fi
  	    shift;;
    -h)
      Usage;
      exit 0;;
    *)
      echo "Unrecognised option $1" 1>&2
      exit 1
     esac
done


##Echo out all input parameters into a log
logDir=$rawEpiDir
echo "$scriptPath" >> $logDir/rsParams_log
echo "------------------------------------" >> $logDir/rsParams_log
echo "-E $epiData" >> $logDir/rsParams_log
echo "`date`" >> $logDir/rsParams_log
echo "" >> $logDir/rsParams_log
echo "" >> $logDir/rsParams_log

cd $indir || exit
gunzip ${epiData}


echo "Running $0 ..."



cd $rawEpiDir || exit


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
motionscrub('${rawEpiDir}','${epiData//.nii.gz/.nii}',funcvoldim)
quit
EOF



# Run script using Matlab or Octave
haveMatlab=`which matlab`
if [ "$haveMatlab" == "" ]; then
  octave --no-window-system $rawEpiDir/$filename
else
  matlab -nodisplay -r "run $rawEpiDir/$filename"
fi

#################################


cd ${rawEpiDir}/motionScrub || exit
#### Process Summary ############
echo "...Summarizing Results"

##Want to summarize motion-scrubbing output
echo "ID,total_volumes,deleted_volumes,prop_deleted,resid_vols" > motion_scrubbing_info.txt

fsl_tsplot -i fd.txt -t "FD (mm)" -w 800 -h 300 -u 1 --start=1 -o fd.png
fsl_tsplot -i dvars.txt -t "DVARS" -w 800 -h 300 -u 1 --start=1 -o dvars.png
##Echo out the pertinent info for the motion-scrubbed/processed subjects

numvols=`fslinfo ${epiData} | grep ^dim4 | awk '{print $2}'`

delvols=`cat deleted_vols.txt | wc | awk '{print $2}'`

propdel=`echo ${numvols} ${delvols} | awk '{print ($2/$1)}'`
residvols=`echo ${numvols} ${delvols} | awk '{print ($1-$2)}'`
echo "${indir},${numvols},${delvols},${propdel},${residvols}" >> motion_scrubbing_info.txt

#Echo out motionscrub info to rsParams file
echo "epiNormMS=${epiData//.nii/_ms.nii}" >> $rawEpiDir/rsParams



echo "<hr>" >> ${rawEpiDir}/analysisResults.html
echo "<h2>Motion Scrubbing</h2>" >> ${rawEpiDir}/analysisResults.html
echo "<b>Total Volumes</b>: $numvols<br>" >> ${rawEpiDir}/analysisResults.html
echo "<b>Deleted Volumes</b>: $delvols<br>" >> ${rawEpiDir}/analysisResults.html
echo "<b>Remaining Volumes</b>: $residvols<br>" >> ${rawEpiDir}/analysisResults.html


scrubDataCheck=`cat deleted_vols.txt | head -1`
if [[ $scrubDataCheck != "" ]]; then
  echo "<b>Scrubbed TR</b>: `cat deleted_vols.txt | awk '{$1=$1}1'`<br>" >> ${rawEpiDir}/analysisResults.html
fi

#################################
# clean up gunzipped nifti
gzip ${epiData//.nii.gz/.nii}

echo "$0 Complete"
echo ""
echo ""
