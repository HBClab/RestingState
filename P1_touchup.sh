#!/bin/bash

##################################################################################################################
# After fixing the EPI mask (T1 to EPI registration is imperfect), some files and pipelines need to be fixed
#     1. "stripped" EPI files
#     2. EPI to T1 and MNI registered files
##################################################################################################################

scriptPath=`perl -e 'use Cwd "abs_path";print abs_path(shift)' $0`
scriptDir=`dirname $scriptPath`


function printCommandLine {
  echo "Usage: P1_touchup.sh -p rsParams -f"
  echo ""
  echo "   where:"
  echo "    -p rsParams file"
  echo "    -f (fieldMap registration correction)"
  exit 1
}



# Parse Command line arguments
while getopts “hp:f” OPTION
do
  case $OPTION in
    h)
      printCommandLine
      ;;
    p)
      rsParamFile=$OPTARG
      ;;
    f)
      fieldMapFlag=1
      ;;
    ?)
      echo "ERROR: Invalid option"
      printCommandLine
      ;;
     esac
done




##Echo out all input parameters into a log
  indir=`dirname $rsParamFile`
echo "$scriptPath" >> $indir/rsParams_log
echo "------------------------------------" >> $indir/rsParams_log
echo "-p $rsParamFile" >> $indir/rsParams_log
if [[ $fieldMapFlag == 1 ]]; then
  echo "-f" >> $indir/rsParams_log
fi
echo "`date`" >> $indir/rsParams_log
echo "" >> $indir/rsParams_log
echo "" >> $indir/rsParams_log


#First check for proper input files
if [ "$rsParamFile" == "" ]; then
  echo "Error: The rsParams (-p) is a required option"
  exit 1
fi

  #A few default parameters (if input not specified, these parameters are assumed)
    #Other variables that need to be set
  if [[ $fieldMapFlag == "" ]]; then
    fieldMapFlag=0
  fi

  fslDir=`echo $FSLDIR`
  epiWarpDir=${indir}/EPItoT1optimized
  epiMask=`cat $rsParamFile | grep "epiMask=" | awk -F"=" '{print $2}' | tail -1`
  t1Data=`cat $rsParamFile | grep "t1=" | awk -F"=" '{print $2}' | tail -1`





echo "Running $0 ..."

cd $indir

  ########## Skullstrip the EPI data ######################
  echo "...Fixing skullstripping on EPI data"

  #skull-strip the motion-corrected EPI image
  fslmaths mcImgMean.nii.gz -mas $epiMask mcImgMean_stripped.nii.gz

  #skull-strip mcImgMean volume, write output to rsParams file
  fslmaths mcImg.nii.gz -mas $epiMask mcImg_stripped.nii.gz

  #Leftover section from dataPrep (to create "RestingState.nii.gz")
  fslmaths RestingStateRaw.nii.gz -mas $epiMask RestingState.nii.gz

  #nonfiltered SNR image
  fslmaths nonfilteredSNRImg.nii.gz -mas $epiMask nonfilteredSNRImg.nii.gz

  ################################################################




  ########## Fix EPI to MNI registration data #############
  echo "...Fixing EPI to T1/MNI registration files"

  #Check for use of a FieldMap correction
  if [[ $fieldMapFlag == 1 ]]; then

    #Apply EPItoT1 warp to EPI file
    applywarp --ref=${t1Data} --in=${indir}/mcImgMean_stripped.nii.gz --out=$epiWarpDir/EPIstrippedtoT1.nii.gz --warp=$epiWarpDir/EPItoT1_warp.nii.gz

    #Apply EPItoMNI warp to EPI file
    applywarp --ref=$fslDir/data/standard/MNI152_T1_2mm.nii.gz --in=${indir}/mcImgMean_stripped.nii.gz --out=$epiWarpDir/EPItoMNI.nii.gz --warp=${epiWarpDir}/EPItoMNI_warp.nii.gz

  else

    #Apply EPItoT1 warp to EPI file
    flirt -in ${indir}/mcImgMean_stripped.nii.gz -ref ${t1Data} -applyxfm -init $epiWarpDir/EPItoT1.mat -out $epiWarpDir/EPIstrippedtoT1.nii.gz

    #Apply EPItoMNI warp to EPI file
    applywarp --ref=$fslDir/data/standard/MNI152_T1_2mm.nii.gz --in=${indir}/mcImgMean_stripped.nii.gz --out=$epiWarpDir/EPItoMNI.nii.gz --warp=${epiWarpDir}/EPItoMNI_warp.nii.gz

  fi

  ################################################################



echo "$0 Complete"
echo ""
echo ""




