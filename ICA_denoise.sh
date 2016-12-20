#!/bin/bash

##################################################################################################################
# Removal of noise ICs, rater-classified from output of Melodic
#     1. ICA Noise removal
##################################################################################################################

scriptPath=`perl -e 'use Cwd "abs_path";print abs_path(shift)' $0`
scriptDir=`dirname $scriptPath`


function printCommandLine {
  echo ""
  echo "Usage: ICA_denoise -E restingStateImage -I NoiseICList -t tr -c"
  echo ""
  echo "   where:"
  echo "   -E Resting State file (filtered EPI data run through MELODIC)"
  echo "   -I List (comma-separated) of noise IC's from MELODIC"
  echo "   -t TR time (seconds)"
  echo "     *Default is 2s"
  echo "   -c clobber/overwrite previous results"
  exit 1
}



# Parse Command line arguments
while getopts “hE:I:L:t:cv” OPTION
do
  case $OPTION in
    h)
      printCommandLine
      ;;
    E)
      epiData=$OPTARG
      ;;
    I)
      noiseIC=$OPTARG
      ;;
    t)
     tr=$OPTARG
     ;;
    c)
      overwriteFlag=1
      ;;
    ?)
      printCommandLine
      ;;
     esac
done




#First check for proper input files
if [[ "$epiData" == "" ]]; then
  echo "Error: data file must be specified with the -E option"
  exit 1
fi

if [[ $noiseIC == "" ]]; then
  echo "Error: Noise IC's (comma-separated list) must be specified with the -I option"
  exit 1
fi



  #A few default parameters (if input not specified, these parameters are assumed)
  if [[ $tr == "" ]]; then
    tr=2
  fi

  if [[ $overwriteFlag == "" ]]; then
    overwriteFlag=0
  fi





#Path setup
ICADir=`dirname $epiData`
ICAname=`basename $epiData`




##Echo out all input parameters into a log
logDirtemp=`dirname $epiData`
logDir=`dirname $logDirtemp`
echo "$scriptPath" >> $logDir/rsParams_log
echo "------------------------------------" >> $logDir/rsParams_log
echo "-E $epiData" >> $logDir/rsParams_log
echo "-I $noiseIC" >> $logDir/rsParams_log
echo "-t $tr" >> $logDir/rsParams_log
if [[ $overwrite == 1 ]]; then
  echo "-c" >> $logDir/rsParams_log
fi
echo "`date`" >> $logDir/rsParams_log
echo "" >> $logDir/rsParams_log
echo "" >> $logDir/rsParams_log


#If user defines overwrite, note in rsParams file
if [[ $overwriteFlag == 1 ]]; then
  echo "_ICA_denoise_clobber" >> $logDir/rsParams
fi





echo "Running $0 ..."




 
cd $ICADir

#Denoising file using specified noise IC components
if [[ -e denoised_func_data.nii.gz ]]; then
  if [[ $overwriteFlag == 1 ]]; then
    fsl_regfilt -i ${ICAname} -o denoised_func_data -d filtered_func_data.ica/melodic_mix -f $noiseIC
  else
    echo "$0 has already been run. Use the -c option to overwrite results"
    exit
  fi
else
  fsl_regfilt -i ${ICAname} -o denoised_func_data -d filtered_func_data.ica/melodic_mix -f $noiseIC
fi


### Final output here is denoised_func_data.nii.gz file, which has had all preprocessing (possibly highpass filtered), and has had ICA noise component removal
echo "epiDenoised=$ICADir/denoised_func_data.nii.gz" >> $logDir/rsParams


echo "$0 Complete"
echo ""
echo ""




