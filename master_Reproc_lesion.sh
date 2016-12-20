#!/bin/bash

##################################################################################################################
# An attempt to take preprocessed Lifespan data and reprocess with updated registration, filtering techniques
#  *Starting at output of ICA_denoise (denoised_filtered_func_data)
#     1. dataPrep
#       a. T1 to MNI registration via flirt/fnirt (requires regular and skull-stripped T1)		
#       b. EPI to T1 registration via BBR.  May or may not involve FieldMap correction
#     2. removeNuisanceRegressors
#       a. mcImg.par conversion to mm  (for motion scrubbing purposes)
#         *Newer scripts use 3dVolreg but sticking with previously applied mcflirt
#       b. Seed mapping to EPI space (with updated warps)
#       c. Bandpass filtering of the motion parameters
#         *EPI data was previously high/lowpass filtered
#       d. Regress out nuisance signals
#       e. FEAT registration corrections (with warps)
#     3. motionScrub (if chosen)
#       *Now uses mcImg_mm.par file for matlab scrubbing functions
#     4. seedVoxelCorrelation
#       a. Warp seeds into EPI space
#       b. Calculate mean time series for each seed
#       c. Correlate mean time series with processed EPI signal
#       d. Output results (zmap) to highres (T1) and standard (MNI) space
#         *Mask to 2mm brain to clip off signal that is outside cerebrum
##################################################################################################################

scriptPath=`perl -e 'use Cwd "abs_path";print abs_path(shift)' $0`
scriptDir=`dirname $scriptPath`

analysis=nuisancereg
analysis2=nuisanceregFix
nuisancefeat=${analysis}.feat
fsf=${analysis}.fsf
fsf2=${analysis2}.fsf


function printCommandLine {
  echo "Usage: master_Reproc.sh -i inputDirectory -f fieldMapCorrection -F 2.46 -n nuisanceROI -t TR -T TE -D 0.000350475 -d PhaseEncDir -L lowpass_nuisance -H highpass_nuisance -m motionScrubLevel -r seedROI -V Create_output_QCimages"
  echo ""
  echo "   where:"
  echo "   -i Input (base) directory from original processing (e.g. /pathToLifeSpan/sub0005"
  echo "   -f use FieldMap correction with EPI to T1 registration (BBR)"
  echo "   -F deltaTE of the fieldMap (in s) (default to 2.46 s)"
  echo "         *This scan be obtained from the difference in TE between the Phase and Magnitude images"
  echo "           e.g.:, TE(Phase)=2550, TE(Mag)=5010; deltaTE=2460 m (2.46s)"
  echo "   -n ROI for nuisance regression (can be used multiple times)"
  echo "      *e.g. -n global -n latvent -n wmroi"
  echo "   -N Data file with nuisance ROI list, one seed per line"
  echo "      **Use ONLY one option, -n or -N, NOT both"  
  echo "   -t TR time (seconds) (default to 2 s)"
  echo "   -T TE (milliseconds) (default to 30 ms)"
  echo "   -D dwell time (in seconds)"
  echo "       *dwell time is from the EPI but is only set if FieldMap correction ('-f') is chosen."
  echo "       *If not set and FieldMap correction is flagged ('-f'), default is 0.00056"
  echo "   -d Phase Encoding Direction (from dataPrep)"
  echo "       *Options are x/y/z/-x/-y/-z"
  echo "   -L lowpass filter frequency (Hz) (e.g. 0.08 Hz (2.5 sigma))"
  echo "   -H highpass filter frequency (Hz) (e.g. 0.008 Hz (25.5 sigma / 120 s))"
  echo "     *These filters are for the nuisane regressors ONLY.  If not set, defaults to '0' and they won't be bandpassed"
  echo "   -g global nuisance reg. sets nuisance reg fsf file to be used: 1, 2, 3, or 4 (this MUST match rois in Nuisance ROI seed list!)"
  echo "      1 = use dummy_nuisance.fsf (motion, wm, latvent, and global signal regression)"
  echo "      2 = use dummy_nuisance_lesion.fsf (motion, wm, latvent, global and lesion regression)"
  echo "      3 = use dummy_nuisance_noglobal.fsf (motion, wm, latvent regression only)"
  echo "      4 = use dummy_nuisance_noglobal_lesion.fsf (motion, wm, latvent and lesion regression)"
  echo "   -m MotionScrubb the EPI: O,1 or 2 (default is 0/no)"
  echo "      0 = use non-motionscrubbed EPI only (default)"
  echo "      1 = use motionscrubbed EPI only"
  echo "      2 = use motionscrubbed and non-motionscrubbed EPI (parallel output)"
  echo "   -r roi for seed voxel (can be used multiple times)"
  echo "        *e.g. -r pccrsp -r icalc"
  echo "   -R Data file with seed list, one seed per line"
  echo "        **Use ONLY one option, -r or -R, NOT both"
  echo "   -V Review SeedCorrelation Results (default is to NOT view results).  Setting of this flag will spit out time-series plot"
  echo "      of seed/ROI"
  echo "        *If selected, results seed Maps will be registered to subject's T1 and the MNI 2mm atlas"
  exit 1
}

# Parse Command line arguments
while getopts “hi:fF:n:N:t:T:D:d:L:H:g:m:r:R:V” OPTION
do
  case $OPTION in
    h)
      printCommandLine
      ;;
    i)
      inDir=$OPTARG
      ;;
    f)
      fieldMapFlag=1
      ;;
    F)
      deltaTE=$OPTARG
      ;;
    n)
      nuisanceList=`echo $nuisanceList $OPTARG`
      nuisanceInd=1
      ;;
    N)
      nuisanceList=`cat $OPTARG`
      nuisanceInFile=$OPTARG
      ;;
    t)
      tr=$OPTARG
      ;;
    T)
      te=$OPTARG
      ;;
    D)
      dwellTime=$OPTARG
      ;;
    d)
      peDir=$OPTARG
      ;;
    L)
      lowpassArg=$OPTARG
      ;;
    H)
      highpassArg=$OPTARG
      ;;
    g)
      globalsignalFlag=$OPTARG
      ;;
    m)
      motionscrubFlag=$OPTARG
      ;;
    r)
      roiList=`echo $roiList $OPTARG`
      roiInd=1
      ;;
    R)
      roiList=`cat $OPTARG`
      roiInFile=$OPTARG
      ;;
    V)
      reviewResults=1
      ;;   
    ?)
      echo "ERROR: Invalid option"
      printCommandLine
      ;;
     esac
done








#### Default Variables     ##############################################
  #Vanilla settings if no user-input

  if [[ $tr == "" ]]; then
    tr=2
  fi

  if [[ $te == "" ]]; then
    te=25
  fi

  if [[ $lowpassArg == "" ]]; then
    lowpassArg=0
  fi

  if [[ $highpassArg == "" ]]; then
    highpassArg=0
  fi

  if [[ $reviewResults == "" ]]; then
    reviewResults=0
  fi

  if [[ $globalsignalFlag == "" ]]; then
    globalsignalFlag=1
  fi

  if [[ $motionscrubFlag == "" ]]; then
    motionscrubFlag=0
  fi

  if [[ $fieldMapFlag == "" ]]; then
    fieldMapFlag=0
  fi

  if [[ $deltaTE == "" ]]; then
    deltaTE=2.46
  fi

  if [[ $dwellTime == "" ]]; then
    dwellTime=0.000350475
  fi

  if [[ $peDir == "" ]]; then
    peDir="-y"
  fi

  if [[ $nuisanceInd == "" ]]; then
    nuisanceInd=0
  fi

  if [[ $roiInd == "" ]]; then
    roiInd=0
  fi

#########################################################################
  




#### Input Data     #####################################################


T1brain=$inDir/rsOut/anat/T1_MNI_brain.nii.gz
T1=$inDir/rsOut/anat/T1_MNI.nii.gz
rsMean=$inDir/rsOut/func/mcImgMean.nii.gz
rsMask=$inDir/rsOut/func/mcImgMean_mask.nii.gz
epiDataFilt=$inDir/rsOut/func/preproc.feat/filtered_func_data.nii.gz

if [[ $globalsignalFlag == 1 ]]; then
  dummynuisance=dummy_nuisance
elif [[ $globalsignalFlag == 2 ]]; then
  dummynuisance=dummy_nuisance_lesion
elif [[ $globalsignalFlag == 3 ]]; then
  dummynuisance=dummy_nuisance_noglobal
else
  dummynuisance=dummy_nuisance_noglobal_lesion
fi

echo "Using $dummynuisance.fsf"

#########################################################################





#### Directory setup for main reprocessing directory     ################

outDir=$inDir/reproc

if [[ ! -e $outDir ]]; then
  mkdir $outDir
fi

  #sub directories (FieldMap, T1toMNI, EPItoT1)
  ##FieldMap setup
   #$outDir/fieldMap

  if [[ $fieldMapFlag == 1 ]]; then
    fmOutDir=$outDir/fieldMap
    if [[ ! -e $fmOutDir ]]; then
      mkdir $fmOutDir
    fi
  fi

  ##T1toMNI
    #T1forWarp

  t1WarpDir=$outDir/T1forWarp


  ##EPItoT1
    #EPItoT1optimized

  epiWarpDir=$outDir/EPItoT1optimized


#########################################################################





#### Log setup to rsParams_log     ######################################

echo "$0" >> $outDir/rsParams_log
echo "------------------------------------" >> $outDir/rsParams_log
echo "-i ${inDir}" >> $outDir/rsParams_log
if [[ $fieldMapFlag == 1 ]]; then
  echo "-f" >> $outDir/rsParams_log
  echo "-F ${deltaTE}" >> $outDir/rsParams_log
fi
if [[ $nuisanceInd == 1 ]]; then
  echo "-n ${nuisanceList}" >> $outDir/rsParams_log
else
  echo "-N ${nuisanceInFile}" >> $outDir/rsParams_log
fi
echo "-t ${tr}" >> $outDir/rsParams_log
echo "-T ${te}" >> $outDir/rsParams_log
echo "-D ${dwellTime}" >> $outDir/rsParams_log
echo "-d ${peDir}" >> $outDir/rsParams_log
echo "-L ${lowpassArg}" >> $outDir/rsParams_log
echo "-H ${highpassArg}" >> $outDir/rsParams_log
echo "-g ${globalsignalFlag}" >> $outDir/rsParams_log
echo "-m ${motionscrubFlag}" >> $outDir/rsParams_log
if [[ $roiInd == 1 ]]; then
  echo "-n ${roiList}" >> $outDir/rsParams_log
else
  echo "-R ${roiInFile}" >> $outDir/rsParams_log
fi
if [[ reviewResults == 1 ]]; then
  echo "-V" >> $outDir/rsParams_log
fi
echo `date` >> $outDir/rsParams_log
echo "" >> $outDir/rsParams_log

#########################################################################







############################### Begin data processing  #################################################################

#### dataPrep     #######################################################
  ##Registration, reorientation, naming

  #### T1toMNI Registration  ############
  echo "...T1 to MNI Registration"
  cp -R ${inDir}/rsOut/func/T1forWarp $outDir/
  ##T1 to MNI registration
  #T1 to MNI, affine (skull-stripped data)
  #flirt -in $T1brain -ref $FSLDIR/data/standard/MNI152_T1_2mm_brain.nii.gz -out $t1WarpDir/T1_to_MNIaff.nii.gz -omat $t1WarpDir/T1_to_MNIaff.mat

  #T1 to MNI, nonlinear (T1 with skull)
 # fnirt --in=$T1 --aff=$t1WarpDir/T1_to_MNIaff.mat --config=T1_2_MNI152_2mm.cnf --cout=$t1WarpDir/coef_T1_to_MNI152 --iout=$t1WarpDir/T1_to_MNI152.nii.gz --jout=$t1WarpDir/jac_T1_to_MNI152 --jacrange=0.1,10

  #Apply the warp to the skull-stripped T1
  #applywarp --ref=$FSLDIR/data/standard/MNI152_T1_2mm_brain.nii.gz --in=$T1brain --out=$t1WarpDir/T1_brain_to_MNI152.nii.gz --warp=$t1WarpDir/coef_T1_to_MNI152.nii.gz

  #Invert the warp (to get MNItoT1)
  #invwarp -w $t1WarpDir/coef_T1_to_MNI152.nii.gz -r $T1brain -o $t1WarpDir/MNItoT1_warp.nii.gz

    #Echo out warp files to log
    echo "MNItoT1IWarp=${t1WarpDir}/MNItoT1_warp.nii.gz" >> $outDir/rsParams
    echo "T1toMNI=${t1WarpDir}/T1_brain_to_MNI152.nii.gz" >> $outDir/rsParams
    echo "T1toMNIWarp=${t1WarpDir}/coef_T1_to_MNI152.nii.gz" >> $outDir/rsParams

  #######################################



  #### FieldMap Preparation  ############
    #Check for use FieldMap correction

  if [[ $fieldMapFlag == 1 ]]; then
    echo "...Preparing the FieldMap data"

  #Copy over and rename fieldMap data
  cp $inDir/rsOut/fieldMap/fieldMapMag.nii.gz $fmOutDir/fieldMapMag.nii.gz
  cp $inDir/rsOut/fieldMap/fieldMapMag_MNI_stripped.nii.gz $fmOutDir/fieldMapMag_brain.nii.gz
  cp $inDir/rsOut/fieldMap/fieldMapPhase.nii.gz $fmOutDir/fieldMapPhase.nii.gz

    #Input data for FieldMap preparation
    magImage=${fmOutDir}/fieldMapMag.nii.gz
    magImageStripped=${fmOutDir}/fieldMapMag_brain.nii.gz
    phaseImage=${fmOutDir}/fieldMapPhase.nii.gz

      #Making an assumption that ALL lifespan data has the same deltaTE


    #Prepare the fieldMaps
    fsl_prepare_fieldmap SIEMENS $phaseImage $magImageStripped $fmOutDir/fieldMap_prepped.nii.gz $deltaTE

    preppedImage=${fmOutDir}/fieldMap_prepped.nii.gz


      #Saving variables for logging and for downstream processing
      echo "fieldMapPhase=${phaseImage}" >> $outDir/rsParams
      echo "fieldMapMag=${magImage}" >> $outDir/rsParams
      echo "fieldMapMagStripped=${magImageStripped}" >> $outDir/rsParams
      echo "fieldMapPrepped=$fmOutDir/fieldMap_prepped.nii.gz" >> $outDir/rsParams
  fi

  #######################################



  #### EPItoT1 Registration  ############
    #Check for use of FieldMap correction
  
  #Need to create a skull-stripped version of the mean EPI image
  fslmaths $rsMean -mul $rsMask $outDir/mcImgMean_stripped.nii.gz
  rsStripped=$outDir/mcImgMean_stripped.nii.gz


  if [[ $fieldMapFlag == 1 ]]; then
    echo "......Logging of EPI to T1 Registration With FieldMap Correction."
    

    cp -R ${inDir}/rsOut/func/EPItoT1optimized ${epiWarpDir}
  
    #Warp using FieldMap correction
      #Output will be a (warp) .nii.gz file
   # epi_reg --epi=${rsMean} --t1=${T1} --t1brain=${T1brain} --out=$epiWarpDir/EPItoT1 --fmap=${preppedImage} --fmapmag=${magImage} --fmapmagbrain=${magImageStripped} --echospacing=${dwellTime} --pedir=${peDir}

    #Apply the warp to the stripped EPI file
   # applywarp --ref=${T1brain} --in=${rsStripped} --out=$epiWarpDir/EPIstrippedtoT1.nii.gz --warp=$epiWarpDir/EPItoT1_warp.nii.gz

    #Invert the affine registration (to get T1toEPI)
  #  convert_xfm -omat $epiWarpDir/T1toEPI.mat -inverse $epiWarpDir/EPItoT1.mat

    #Invert the nonlinear warp (to get T1toEPI)
  #  invwarp -w $epiWarpDir/EPItoT1_warp.nii.gz -r ${rsMean} -o $epiWarpDir/T1toEPI_warp.nii.gz

    #Sum the $epiDataFiltnonlinear warp (MNItoT1_warp.nii.gz) with the second nonlinear warp (T1toEPI_warp.nii.gz) to get a warp from MNI to EPI
   # convertwarp --ref=${rsMean} --warp1=${t1WarpDir}/MNItoT1_warp.nii.gz --warp2=${epiWarpDir}/T1toEPI_warp.nii.gz --out=${epiWarpDir}/MNItoEPI_warp.nii.gz --relout

    #Invert the warp to get EPItoMNI_warp.nii.gz
   # invwarp -w ${epiWarpDir}/MNItoEPI_warp.nii.gz -r $FSLDIR/data/standard/MNI152_T1_2mm.nii.gz -o ${epiWarpDir}/EPItoMNI_warp.nii.gz

    #Apply EPItoMNI warp to EPI file
    #applywarp --ref=$FSLDIR/data/standard/MNI152_T1_2mm.nii.gz --in=${rsStripped} --out=$epiWarpDir/EPItoMNI.nii.gz --warp=${epiWarpDir}/EPItoMNI_warp.nii.gz

    #Echo out warp files, wmedge to log
    echo "t1WMedge=${epiWarpDir}/EPItoT1_fast_wmedge.nii.gz" >> $outDir/rsParams
    echo "T1toEPIWarp=${epiWarpDir}/T1toEPI_warp.nii.gz" >> $outDir/rsParams
    echo "EPItoT1=${epiWarpDir}/EPIstrippedtoT1.nii.gz" >> $outDir/rsParams
    echo "EPItoT1Warp=${epiWarpDir}/EPItoT1_warp.nii.gz" >> $outDir/rsParams
    echo "MNItoEPIWarp=${epiWarpDir}/MNItoEPI_warp.nii.gz" >> $outDir/rsParams
    echo "EPItoMNI=${epiWarpDir}/EPItoMNI.nii.gz" >> $outDir/rsParams
    echo "EPItoMNIWarp=${epiWarpDir}/EPItoMNI_warp.nii.gz" >> $outDir/rsParams

  else
    echo "......Logging of EPI to T1 Registration Without FieldMap Correction."
    
    #Echo out warp files, wmedge to log
    echo "t1WMedge=${epiWarpDir}/EPItoT1_fast_wmedge.nii.gz" >> $outDir/rsParams
    echo "T1toEPIWarp=${epiWarpDir}/T1toEPI_warp.nii.gz" >> $outDir/rsParams
    echo "EPItoT1=${epiWarpDir}/EPIstrippedtoT1.nii.gz" >> $outDir/rsParams
    echo "EPItoT1Warp=${epiWarpDir}/EPItoT1_warp.nii.gz" >> $outDir/rsParams
    echo "MNItoEPIWarp=${epiWarpDir}/MNItoEPI_warp.nii.gz" >> $outDir/rsParams
    echo "EPItoMNI=${epiWarpDir}/EPItoMNI.nii.gz" >> $outDir/rsParams
    echo "EPItoMNIWarp=${epiWarpDir}/EPItoMNI_warp.nii.gz" >> $outDir/rsParams
  fi

  #######################################

#########################################################################










#### removeNuisanceRegressors     #######################################
  #high/lowpass filter the nuisance ROIs, Registration of ROIs to EPI, removal of nuisance signal

  #### Nuisance ROI setup  ##############

  #Echo out nuisance ROIs to a text file in input directory
  if [ -e $outDir/nuisance_rois.txt ]; then
    rm $outDir/nuisance_rois.txt
  fi

  for i in $nuisanceList
  do
    nuisanceROI="$nuisanceROI -n $i"
    echo $i >> $outDir/nuisance_rois.txt
  done

  nuisanceroiList=$outDir/nuisance_rois.txt

  #######################################



  #### mcImg.par conversion #############

  #Copy over mcImg.par file.  Should already be in radians and mm
  cp $inDir/rsOut/func/mcImg.par $outDir/mcImg.par

  #Convert file to mm for all rotations/translations
    #Need to create a version where ALL (rotations and translations) measurements are in mm.  Going by Power 2012 Neuroimage paper, radius of 50mm.
    #l = wr, where r is the radius, w is the radian angle
  cat $outDir/mcImg.par | awk -v r=50 '{print (r*$1) " " (r*$2) " " (r*$3) " " $4 " " $5 " " $6}' > $outDir/mcImg_mm.par

  #Split up mcImg.par file
  for i in 1 2 3 4 5 6
  do
    cat $outDir/mcImg.par | awk -v var=${i} '{print $var}' > $outDir/mc${i}.par
  done

  #######################################



  #### Nuisance ROI mapping #############
  echo "...Warping Nuisance ROIs to EPI space"

  #Create directory for nuisance ROIs
  if [ ! -e $outDir/Nuisancerois ]; then
    mkdir $outDir/Nuisancerois
    mkdir $outDir/Nuisancerois/rois
  fi

  #Move seeds to EPI space, calculate time series
  for roi in $nuisanceList
  do
    
    roiname=`basename $roi | awk -F "." '{print $1}'`
    echo "......Mapping nuisance regressor $roiname"
    echo $roiname >> $outDir/nuisanceListRois.txt
    NuisanceRoiDir=`dirname $roi`
    roi_orient=`fslhd $roi | grep "qform_name" | tail -1 | awk -F " " '{print $2}'`

    if [[ ${roi_orient} == "MNI_152" ]]; then
    echo "in MNI space, using MNI to EPI warp"
    #Warp Nuisance ROIs from MNI to EPI
      applywarp --ref=${rsStripped} --in=${NuisanceRoiDir}/${roiname}.nii.gz --out=$outDir/Nuisancerois/rois/${roiname}_native.nii.gz --warp=${epiWarpDir}/MNItoEPI_warp.nii.gz --datatype=float
      fslmaths $outDir/Nuisancerois/rois/${roiname}_native.nii.gz -thr 0.5 $outDir/Nuisancerois/rois/${roiname}_native.nii.gz
      fslmaths $outDir/Nuisancerois/rois/${roiname}_native.nii.gz -bin $outDir/Nuisancerois/rois/${roiname}_native.nii.gz
      fslmeants -i ${epiDataFilt} -o ${outDir}/Nuisancerois/rois/mean_${roiname}_ts.txt -m ${outDir}/Nuisancerois/rois/${roiname}_native.nii.gz
    else
    echo "not in MNI space, using T1 to EPI warp"
      applywarp --ref=${rsStripped} --in=${NuisanceRoiDir}/${roiname}.nii.gz --out=$outDir/Nuisancerois/rois/${roiname}_native.nii.gz --warp=${epiWarpDir}/T1toEPI_warp --datatype=float
      fslmaths $outDir/Nuisancerois/rois/${roiname}_native.nii.gz -thr 0.5 $outDir/Nuisancerois/rois/${roiname}_native.nii.gz
      fslmaths $outDir/Nuisancerois/rois/${roiname}_native.nii.gz -bin $outDir/Nuisancerois/rois/${roiname}_native.nii.gz
      fslmeants -i $epiDataFilt -o $outDir/Nuisancerois/rois/mean_${roiname}_ts.txt -m $outDir/Nuisancerois/rois/${roiname}_native.nii.gz
    fi
  done

  #######################################



  #### FEAT setup #######################
  echo "... FEAT setup (nuisancereg) using $scriptDir/$dummynuisance.fsf"
 
  cd $outDir

  #Set a few variables from data
    #epi_reg peDir setup (e.g. -y) is backwards from FEAT peDir (e.g. y-)
  peDirBase=$peDir
 


  if [[ $peDirBase == "" ]]; then
    peDirNEW="y-"
  else
    peDirTmp1=`echo $peDirBase | cut -c1`
    peDirTmp2=`echo $peDirBase | cut -c2`
    if [[ "$peDirTmp1" == "-" ]]; then
      peDirNEW="${peDirTmp2}${peDirTmp1}"
    else
      peDirNEW="${peDirBase}"
    fi
  fi



  numtimepoint=`fslinfo $epiDataFilt | grep ^dim4 | awk '{print $2}'`

  cat $scriptDir/${dummynuisance}.fsf | sed 's|SUBJECTPATH|'${outDir}'|g' | \
                                      sed 's|SUBJECTEPIPATH|'${epiDataFilt}'|g' | \
                                      sed 's|SUBJECTT1PATH|'${T1brain}'|g' | \
                                      sed 's|SCANTE|'${te}'|g' | \
                                      sed 's|SUBJECTVOLS|'${numtimepoint}'|g' | \
                                      sed 's|SUBJECTTR|'${tr}'|g' | \
                                      sed 's|EPIDWELL|'${dwellTime}'|g' | \
                                      sed 's|PEDIR|\'${peDirNEW}'|g' | \
                                      sed 's|FSLDIR|'${FSLDIR}'|g' > ${outDir}/${fsf}

  #######################################
nuisanceRoiList=$outDir/nuisanceListRois.txt

  #### Calculate Nuisance Regressor time-series ############
    # Create Regressors using Octave
  echo "...Creating Regressors"
  filename=run_normseedregressors.m;
cat > $filename << EOF
% It is matlab script
close all;
clear all;
addpath('${scriptDir}');
statsScripts=['${scriptDir}','/Octave/statistics'];
addpath(statsScripts);
nuisanceRoiFile=['${nuisanceRoiList}'];
fid=fopen(nuisanceRoiFile);
roiList_tmp=textscan(fid,'%s');
fclose(fid);
roiListSize=cellfun(@length,roiList_tmp)
roiList=cell(roiListSize,1);

for i=1:roiListSize
  roiList{i,1}=(roiList_tmp{1,1}(i));
end


featdir='Nuisancerois';
includemotion=1;
normseedregressors('${outDir}',roiList,featdir,includemotion)
quit;
EOF

  # Run script using Matlab or Octave
  haveMatlab=`which matlab`
  if [ "$haveMatlab" == "" ]; then
    octave --no-window-system $outDir/$filename 
  else
    matlab -nodisplay -r "run $outDir/$filename"
  fi

  echo "<hr><h2>Nuisance Regressors</h2>" >> $outDir/analysisResults.html

  #######################################



  #### Bandpass Motion Regressors #######
  echo "...Bandpass filtering Motion Regressors"

    #Vanilla settings for filtering: L=.08, H=.008

  if [ $lowpassArg != 0 ] || [ $highpassArg != 0 ]; then
    #Filtering ONLY if low/highpass don't both = 0
    mclist='1 2 3 4 5 6'
    for mc in ${mclist}
    do
      cp ${outDir}/tsregressorslp/mc${mc}_normalized.txt ${outDir}/tsregressorslp/mc${mc}_normalized.1D
      1dBandpass $highpassArg $lowpassArg ${outDir}/tsregressorslp/mc${mc}_normalized.1D > ${outDir}/tsregressorslp/mc${mc}_normalized_filt.1D   
      cat ${outDir}/tsregressorslp/mc${mc}_normalized_filt.1D | awk '{print $1}' > ${outDir}/tsregressorslp/mc${mc}_normalized.txt
    done
  else
    #Passband filter
    mclist='1 2 3 4 5 6'
    for mc in ${mclist}
    do
      cp ${outDir}/tsregressorslp/mc${mc}_normalized.txt ${outDir}/tsregressorslp/mc${mc}_normalized.1D
      1dBandpass 0 99999 ${outDir}/tsregressorslp/mc${mc}_normalized.1D > ${outDir}/tsregressorslp/mc${mc}_normalized_filt.1D   
      cat ${outDir}/tsregressorslp/mc${mc}_normalized_filt.1D | awk '{print $1}' > ${outDir}/tsregressorslp/mc${mc}_normalized.txt
    done
  fi

  #######################################



  #### Plotting Regressor time courses ##
  echo "...Plotting Regressor time series"
  echo $nuisanceList
  for roi in $nuisanceList
  do
    echo $roi
    roiname=`basename $roi | awk -F "." '{print $1}'`
    fsl_tsplot -i $outDir/tsregressorslp/${roiname}_normalized_ts.txt -t "${roi} Time Series" -u 1 --start=1 -x 'Time Points (TR)' -w 800 -h 300 -o $outDir/${roiname}_norm.png  
    echo "<br><img src=\"$outDir/${roiname}_norm.png\" alt=\"$roiname nuisance regressor\"><br>" >> $outDir/analysisResults.html
  done

  #######################################



  #### FEAT Regression ##################
    
  #Run feat
  echo "...Running FEAT (nuisancereg)"
  feat ${outDir}/${fsf}

  #######################################



  #### FEAT registration correction #####
  echo "...Fixing FEAT registration QC images."

    #http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FEAT/FAQ
      #ss: "How can I insert a custom registration into a FEAT analysis?"

  regDir=$outDir/${nuisancefeat}/reg

  #Remove all FEAT (registration) files, repopulate with proper files
  cp -r $regDir $outDir/${nuisancefeat}/regORIG
  rm -f $regDir/*
  
  ##Copy over appropriate files from previous processing
  #T1 (highres)
  fslmaths $T1brain $regDir/highres.nii.gz  
  fslmaths ${t1WarpDir}/T1_brain_to_MNI152.nii.gz $regDir/highres2standard.nii.gz

  #EPI (example_func)
  fslmaths $rsStripped $regDir/example_func.nii.gz
  fslmaths ${epiWarpDir}/EPIstrippedtoT1.nii.gz $regDir/example_func2highres.nii.gz
  fslmaths ${epiWarpDir}/EPItoMNI.nii.gz $regDir/example_func2standard.nii.gz

  #MNI (standard)
  fslmaths $FSLDIR/data/standard/avg152T1_brain.nii.gz $regDir/standard.nii.gz

  #Transforms
    #EPItoT1/T1toEPI (Check for presence of FieldMap Correction)
    if [[ $fieldMapFlag == 1 ]]; then
      #Copy the EPItoT1 warp file
      cp  $epiWarpDir/EPItoT1_warp.nii.gz $regDir/example_func2highres_warp.nii.gz
    else
      #Only copy the affine .mat files
      cp $epiWarpDir/EPItoT1_init.mat $regDir/example_func2initial_highres.mat
      cp $epiWarpDir/EPItoT1.mat $regDir/example_func2highres.mat    
    fi

    #T1toMNI
    cp $t1WarpDir/T1_to_MNIaff.mat $regDir/highres2standard.mat
    cp $t1WarpDir/coef_T1_to_MNI152.nii.gz $regDir/highres2standard_warp.nii.gz

    #EPItoMNI
    cp $epiWarpDir/EPItoMNI_warp.nii.gz $regDir/example_func2standard_warp.nii.gz


  #Forgoing "updatefeatreg" and just recreating the appropriate pics with slicer/pngappend
  cd $regDir

  #example_func2highres
  echo "......func2highres"
  slicer example_func2highres.nii.gz highres.nii.gz -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png
  pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png example_func2highres1.png

  slicer highres.nii.gz example_func2highres.nii.gz -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png
  pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png example_func2highres2.png

  pngappend example_func2highres1.png - example_func2highres2.png example_func2highres.png

  rm sl*.png
                                                                                                                                                                            
  #highres2standard
  echo "......highres2standard"
  slicer highres2standard.nii.gz standard.nii.gz -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png
  pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png highres2standard1.png

  slicer standard.nii.gz highres2standard.nii.gz -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png
  pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png highres2standard2.png

  pngappend highres2standard1.png - highres2standard2.png highres2standard.png

  rm sl*.png

  #example_func2standard
  echo "......func2standard"
  slicer example_func2standard.nii.gz standard.nii.gz -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png
  pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png example_func2standard1.png

  slicer standard.nii.gz example_func2standard.nii.gz -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png
  pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png example_func2standard2.png

  pngappend example_func2standard1.png - example_func2standard2.png example_func2standard.png

  rm sl*.png


  #Backup original design file
  cp $outDir/${nuisancefeat}/design.fsf $outDir/${nuisancefeat}/designORIG.fsf



  #Rerun FEAT to fix only post-stats portions (with no registrations)

    #VOXTOT
    epiVoxTot=`fslstats ${epiDataFilt} -v | awk '{print $1}'`

    #NUISANCEDIR
    nuisanceDir=$outDir/${nuisancefeat}

  cat $scriptDir/${dummynuisance}_regFix.fsf | sed 's|SUBJECTPATH|'${outDir}'|g' | \
                                             sed 's|VOXTOT|'${epiVoxTot}'|g' | \
                                             sed 's|NUISANCEDIR|'${nuisanceDir}'|g' | \
                                             sed 's|SCANTE|'${te}'|g' | \
                                             sed 's|SUBJECTVOLS|'${numtimepoint}'|g' | \
                                             sed 's|SUBJECTTR|'${tr}'|g' | \
                                             sed 's|EPIDWELL|'${dwellTime}'|g' | \
                                             sed 's|PEDIR|\'${peDirNEW}'|g' | \
                                             sed 's|FSLDIR|'${FSLDIR}'|g' > ${outDir}/${fsf2}

  #Re-run feat
  echo "...Rerunning FEAT (nuisancereg (post-stats only))"
  feat ${outDir}/${fsf2}


  #Log output to HTML file
  echo "<a href=\"$outDir/${nuisancefeat}/report.html\">FSL Nuisance Regressor Results</a>" >> $outDir/analysisResults.html

  #######################################



  ###### Post-FEAT data-scaling #########

  cd $outDir/${nuisancefeat}/stats

  #Backup file
  echo "...Scaling data by 1000"
  cp res4d.nii.gz res4d_orig.nii.gz
	
  #For some reason, this mask isn't very good.  Use the good mask top-level
  echo "...Copy Brain mask"
  cp $inDir/rsOut/func/mcImgMean_mask.nii.gz mask.nii.gz
  fslmaths mask -mul 1000 mask1000 -odt float

  #normalize res4d here
  echo "...Normalize Data"
  fslmaths res4d -Tmean res4d_tmean 
  fslmaths res4d -Tstd res4d_std 
  fslmaths res4d -sub res4d_tmean res4d_dmean
  fslmaths res4d_dmean -div res4d_std res4d_normed
  fslmaths res4d_normed -add mask1000 res4d_normandscaled -odt float

  #Echo out final file to rsParams file
  echo "epiNorm=$outDir/$nuisancefeat/stats/res4d_normandscaled.nii.gz" >> $outDir/rsParams


  epiNorm=$outDir/$nuisancefeat/stats/res4d_normandscaled.nii.gz

  #######################################

#########################################################################










#### motionScrub     ####################################################
  #Motion scrub the EPI data (in parallel with non motion-scrubbing)

  #Check for motion scrub flag (1 or 2)
  if [[ $motionscrubFlag == 1 || $motionscrubFlag == 2 ]]; then
    cd $outDir

    # Extract image dimensions from the NIFTI File
    numXdim=`fslinfo $epiNorm | grep ^dim1 | awk '{print $2}'`
    numYdim=`fslinfo $epiNorm | grep ^dim2 | awk '{print $2}'`
    numZdim=`fslinfo $epiNorm | grep ^dim3 | awk '{print $2}'`
    numtimepoint=`fslinfo $epiNorm | grep ^dim4 | awk '{print $2}'`


    filename=run_motionscrub.m


    #### Motion scrubbing #################
    echo "...Scrubbing data"

cat > $filename << EOF
% It is matlab script
addpath('${scriptDir}')
niftiScripts=['${scriptDir}','/Octave/nifti'];
addpath(niftiScripts)
funcvoldim=[${numXdim} ${numYdim} ${numZdim} ${numtimepoint}];
motionscrub('${outDir}','${nuisancefeat}',funcvoldim)
quit
EOF



    # Run script using Matlab or Octave
    haveMatlab=`which matlab`
    if [ "$haveMatlab" == "" ]; then
      octave --no-window-system $outDir/$filename 
    else
      matlab -nodisplay -r "run $outDir/$filename"
    fi

    #######################################



    #### Process Summary ##################
    echo "...Summarizing Results"

    ##Want to summarize motion-scrubbing output 
    echo "ID,total_volumes,deleted_volumes,prop_deleted,resid_vols" > ${outDir}/motion_scrubbing_info.txt

    ##Echo out the pertinent info for the motion-scrubbed/processed subjects
    numvols=`fslinfo ${outDir}/nuisancereg.feat/stats/res4d_normandscaled.nii | grep ^dim4 | awk '{print $2}'`
    delvols=`cat ${outDir}/nuisancereg.feat/stats/deleted_vols.txt | wc | awk '{print $2}'`
    propdel=`echo ${numvols} ${delvols} | awk '{print ($2/$1)}'`
    residvols=`echo ${numvols} ${delvols} | awk '{print ($1-$2)}'`
    echo "${outDir},${numvols},${delvols},${propdel},${residvols}" >> ${outDir}/motion_scrubbing_info.txt

    #Echo out motionscrub info to rsParams file
    echo "epiNormMS=${outDir}/nuisancereg.feat/stats/res4d_normandscaled_motionscrubbed.nii" >> $outDir/rsParams

    echo "<hr>" >> ${outDir}/analysisResults.html
    echo "<h2>Motion Scrubbing</h2>" >> ${outDir}/analysisResults.html
    echo "<b>Total Volumes</b>: $numvols<br>" >> ${outDir}/analysisResults.html
    echo "<b>Deleted Volumes</b>: $delvols<br>" >> ${outDir}/analysisResults.html
    echo "<b>Remaining Volumes</b>: $residvols<br>" >> ${outDir}/analysisResults.html

    scrubDataCheck=`cat $outDir/$nuisancefeat/stats/deleted_vols.txt | head -1`
    if [[ $scrubDataCheck != "" ]]; then
      echo "<b>Scrubbed TR</b>: `cat ${outDir}/nuisancereg.feat/stats/deleted_vols.txt | awk '{$1=$1}1'`<br>" >> ${outDir}/analysisResults.html
    fi

    #######################################

  fi

#########################################################################










#### seedVoxelCorrelation     ########################################## 
  #Calculate seed Time series

  for i in $roiList
  do
    seeds="$seeds -r $i"
  done

  roiDir=${scriptDir}/ROIs

  if [ $motionscrubFlag == 0 ]; then
    filename=run_firstlevelseeding_parallel.m
  elif [ $motionscrubFlag = 1 ]; then
    filename2=run_firstlevelseeding_parallel_ms.m
  else
    filename=run_firstlevelseeding_parallel.m
    filename2=run_firstlevelseeding_parallel_ms.m
  fi


  #### Mapping ROIs To Functional Space #
  echo "...Transforming ROIs to EPI space"

  cd $outDir

  if [ -e $outDir/seeds.txt ]; then
    rm $outDir/seeds.txt
  fi

  # Map the ROIs
  for roi in $roiList
  do
    echo "......Mapping $roi from MNI (standard) to subject EPI (func) space"

    #Apply the nonlinear warp from MNI to EPI
    applywarp --ref=${rsStripped} --in=${roiDir}/${roi}.nii.gz --out=${outDir}/${nuisancefeat}/stats/${roi}_mask.nii.gz --warp=${epiWarpDir}/MNItoEPI_warp.nii.gz --datatype=float

    #Threshold and binarize output	    
    fslmaths ${outDir}/${nuisancefeat}/stats/${roi}_mask.nii.gz -thr 0.5 ${outDir}/${nuisancefeat}/stats/${roi}_mask.nii.gz
    fslmaths ${outDir}/${nuisancefeat}/stats/${roi}_mask.nii.gz -bin ${outDir}/${nuisancefeat}/stats/${roi}_mask.nii.gz

    #Check to see that resultant, warped file has any volume (if seed is too small, warped output may have a zero volume)
    seedVol=`fslstats ${outDir}/${nuisancefeat}/stats/${roi}_mask.nii.gz -V | awk '{print $2}'`
      if [[ $seedVol == 0.000000 ]]; then
        echo "$roi >> ${outDir}/${nuisancefeat}/stats/seedsTooSmall"
        rm ${outDir}/${nuisancefeat}/stats/${roi}_mask.nii.gz
      else
        #Account for $motionscrubFlag
          # Extract the time-series per ROI
          # Will need the "normal" time-series, regardless of motion-scrubbing flag so, if condition = 1 or 2, write out regular time-series
        if [[ $motionscrubFlag == 0 ]]; then	   
          fslmeants -i ${outDir}/${nuisancefeat}/stats/res4d_normandscaled -o ${outDir}/${nuisancefeat}/stats/${roi}_residvol_ts.txt -m ${outDir}/${nuisancefeat}/stats/${roi}_mask.nii.gz
        elif [[ $motionscrubFlag == 1 ]]; then
          fslmeants -i ${outDir}/${nuisancefeat}/stats/res4d_normandscaled_motionscrubbed -o ${outDir}/${nuisancefeat}/stats/${roi}_residvol_ms_ts.txt -m ${outDir}/${nuisancefeat}/stats/${roi}_mask.nii.gz
        else
          fslmeants -i ${outDir}/${nuisancefeat}/stats/res4d_normandscaled -o ${outDir}/${nuisancefeat}/stats/${roi}_residvol_ts.txt -m ${outDir}/${nuisancefeat}/stats/${roi}_mask.nii.gz
          fslmeants -i ${outDir}/${nuisancefeat}/stats/res4d_normandscaled_motionscrubbed -o ${outDir}/${nuisancefeat}/stats/${roi}_residvol_ms_ts.txt -m ${outDir}/${nuisancefeat}/stats/${roi}_mask.nii.gz
        fi

        #Output of fslmeants is a text file with space-delimited values.  There is only one "true" ts value (first column) and the blank space is interpreted as a "0" value in matlab.  Write to temp file then move (rewrite original)
        if [[ $motionscrubFlag == 0 ]]; then
          cat ${outDir}/${nuisancefeat}/stats/${roi}_residvol_ts.txt | awk '{print $1}' > ${outDir}/${nuisancefeat}/stats/temp_${roi}_residvol_ts.txt
          mv ${outDir}/${nuisancefeat}/stats/temp_${roi}_residvol_ts.txt ${outDir}/${nuisancefeat}/stats/${roi}_residvol_ts.txt
        elif [[ $motionscrubFlag == 1 ]]; then
          cat ${outDir}/${nuisancefeat}/stats/${roi}_residvol_ms_ts.txt | awk '{print $1}' > ${outDir}/${nuisancefeat}/stats/temp_${roi}_residvol_ms_ts.txt
          mv ${outDir}/${nuisancefeat}/stats/temp_${roi}_residvol_ms_ts.txt ${outDir}/${nuisancefeat}/stats/${roi}_residvol_ms_ts.txt
        else
          cat ${outDir}/${nuisancefeat}/stats/${roi}_residvol_ts.txt | awk '{print $1}' > ${outDir}/${nuisancefeat}/stats/temp_${roi}_residvol_ts.txt
          cat ${outDir}/${nuisancefeat}/stats/${roi}_residvol_ms_ts.txt | awk '{print $1}' > ${outDir}/${nuisancefeat}/stats/temp_${roi}_residvol_ms_ts.txt
          mv ${outDir}/${nuisancefeat}/stats/temp_${roi}_residvol_ts.txt ${outDir}/${nuisancefeat}/stats/${roi}_residvol_ts.txt
          mv ${outDir}/${nuisancefeat}/stats/temp_${roi}_residvol_ms_ts.txt ${outDir}/${nuisancefeat}/stats/${roi}_residvol_ms_ts.txt
        fi
  
        echo "$roi" >> $outDir/seeds.txt
      fi
  done

  #######################################



  #### Seed Transform QC Images #########
  echo "...QC Image Setup"

  ###Create QC images of seed/ROI overlaid on RestingState EPI.  Place in top level directory and report in HTML file
    ##Create underlay/overlay NIFTI files for QC check
    #Create a temp directory 
  seedQCdir=$outDir/$nuisancefeat/stats/seedQC
  if [ ! -e $seedQCdir/temp ]; then
    mkdir -p $seedQCdir/temp
  fi

  #Create underlay/overlay images for each seed
  for roi in $roiList
  do
    for splitdirection in x y z
    do
      echo "......Preparing $roi ($splitdirection)"

      underlayBase=$rsMean
      overlayBase=$outDir/$nuisancefeat/stats/${roi}_mask.nii.gz

      #Compute Center-Of-Gravity for seed mask to determine which axial slice to use for both underlay and overlay
        #Adding 0.5 to COG for xyz dimensions to handle rounding issues
        #Need to account for slices named 0007, 0017, 0107, etc. (have to be able to handle 4-digit numbers)
      if [[ $splitdirection == "x" ]]; then
        suffix=sagittal
        sliceCutTEMP=`fslstats $overlayBase -C | awk '{printf("%d\n",$1 + 0.5)}'`
        sliceCutLength=`echo $sliceCutTEMP | awk '{print length($1)}'`
        if [[ $sliceCutLength == 1 ]]; then
          sliceCut=000${sliceCutTEMP}
        elif [[ $sliceCutLength == 2 ]]; then
          sliceCut=00${sliceCutTEMP}
        else
          sliceCut=0${sliceCutTEMP}
        fi
      elif [[ $splitdirection == "y" ]]; then
        suffix=coronal
        sliceCutTEMP=`fslstats $overlayBase -C | awk '{printf("%d\n",$2 + 0.5)}'`
        sliceCutLength=`echo $sliceCutTEMP | awk '{print length($1)}'`
        if [[ $sliceCutLength == 1 ]]; then
          sliceCut=000${sliceCutTEMP}
        elif [[ $sliceCutLength == 2 ]]; then
          sliceCut=00${sliceCutTEMP}
        else
          sliceCut=0${sliceCutTEMP}
        fi
      else
        suffix=axial
        sliceCutTEMP=`fslstats $overlayBase -C | awk '{printf("%d\n",$3 + 0.5)}'`
        sliceCutLength=`echo $sliceCutTEMP | awk '{print length($1)}'`
        if [[ $sliceCutLength == 1 ]]; then
          sliceCut=000${sliceCutTEMP}
        elif [[ $sliceCutLength == 2 ]]; then
          sliceCut=00${sliceCutTEMP}
        else
          sliceCut=0${sliceCutTEMP}
        fi
      fi

      #Split apart seed mask and example EPI image
      fslsplit $underlayBase $seedQCdir/temp/underlay_split_${suffix} -${splitdirection}
      fslsplit $overlayBase $seedQCdir/temp/overlay_split_${suffix} -${splitdirection}

      #Set variables for underlay and overlay images
      underlayImage=`ls -1 $seedQCdir/temp | grep "underlay_split_${suffix}" | grep $sliceCut`
      overlayImage=`ls -1 $seedQCdir/temp | grep "overlay_split_${suffix}" | grep $sliceCut`

	
      #Copy over underlay/overlay images, uncompress
        ##Will need to check for presence of unzipped NIFTI file (from previous runs (otherwise "clobber" won't work))
      if [[ -e $seedQCdir/${roi}_underlay_${suffix}.nii ]]; then
        if [[ ! -e $seedQCdir/oldSeeds ]]; then
          mkdir $seedQCdir/oldSeeds
        fi

        mv $seedQCdir/${roi}_underlay_${suffix}.nii $seedQCdir/oldSeeds
      fi

      cp $seedQCdir/temp/$underlayImage $seedQCdir/${roi}_underlay_${suffix}.nii.gz
      #gunzip $seedQCdir/${roi}_underlay_${suffix}.nii.gz
      if [[ -e $seedQCdir/${roi}_overlay_${suffix}.nii ]]; then
        if [[ ! -e $seedQCdir/oldSeeds ]]; then
          mkdir $seedQCdir/oldSeeds
        fi

        mv $seedQCdir/${roi}_overlay_${suffix}.nii $seedQCdir/oldSeeds
      fi

      cp $seedQCdir/temp/$overlayImage $seedQCdir/${roi}_overlay_${suffix}.nii.gz
      #gunzip $seedQCdir/${roi}_overlay_${suffix}.nii.gz
    
      ##Need to reorient coronal and sagittal images in order for matlab to process correctly (axial is already OK)
      #Coronal images will also need the orientation swapped to update header AND image info
      if [ $suffix == "sagittal" ]; then
        fslswapdim $seedQCdir/${roi}_underlay_${suffix}.nii.gz y z x $seedQCdir/${roi}_underlay_${suffix}.nii.gz
        fslswapdim $seedQCdir/${roi}_overlay_${suffix}.nii.gz y z x $seedQCdir/${roi}_overlay_${suffix}.nii.gz
      elif [ $suffix == "coronal" ]; then
        fslswapdim $seedQCdir/${roi}_underlay_${suffix}.nii.gz x z y $seedQCdir/${roi}_underlay_${suffix}.nii.gz
        fslorient -swaporient $seedQCdir/${roi}_underlay_${suffix}.nii.gz
        fslswapdim $seedQCdir/${roi}_overlay_${suffix}.nii.gz x z y $seedQCdir/${roi}_overlay_${suffix}.nii.gz
        fslorient -swaporient $seedQCdir/${roi}_overlay_${suffix}.nii.gz
      fi

      #Need to gunzip the files for use with matlab
      gunzip $seedQCdir/${roi}_underlay_${suffix}.nii.gz
      gunzip $seedQCdir/${roi}_overlay_${suffix}.nii.gz
    done
  done

  #Create an output directory for QC seed images
  seedQCOutdir=$outDir/seedQC
  if [ ! -e $seedQCOutdir ]; then
    mkdir $seedQCOutdir
  fi


  #Create overlaps of seed_mask registered to EPI space using Octave
  echo "...Creating QC Images of ROI/Seed Registration To Functional Space"
  filenameQC=run_seedregistrationcheck.m;
cat > $filenameQC << EOF
% It is matlab script
close all;
clear all;
addpath('${scriptDir}');
statsScripts=['${scriptDir}','/Octave/statistics'];
niftiScripts=['${scriptDir}','/Octave/nifti'];
addpath(niftiScripts)
addpath(statsScripts);
fid=fopen('$outDir/seeds.txt');
roiList=textscan(fid,'%s');
fclose(fid);
seedDir='$seedQCdir';
imageDir='$seedQCOutdir';
seedregistrationcheck(seedDir,roiList,imageDir)
quit;
EOF


  # Run script using Matlab or Octave
  haveMatlab=`which matlab`
  if [ "$haveMatlab" == "" ]; then
    octave --no-window-system $outDir/$filenameQC 
  else
    matlab -nodisplay -r "run $outDir/$filenameQC"
  fi


  #Remove temp directory of "split" files.  Keep only underaly and overlay base images
  rm -rf $seedQCdir/temp

  #######################################



  #### Output Images To HTML File #######

  #Display Coronal,Sagittal,Axial on one line
    #Put header of seed type

  echo "<hr>" >> ${outDir}/analysisResults.html
  echo "<h2>Seed Registration QC (Neurological View, Right=Right)</h2>" >> ${outDir}/analysisResults.html
  for roi in $roiList
  do
    echo "<br><b>$roi</b><br>" >> ${outDir}/analysisResults.html
    echo "<img src=\"$seedQCOutdir/${roi}_coronal.png\" alt=\"${roi}_coronal seed QC\"><img src=\"$seedQCOutdir/${roi}_sagittal.png\" alt=\"${roi}_sagittal seed QC\"><img src=\"$seedQCOutdir/${roi}_axial.png\" alt=\"${roi}_axial seed QC\"><br>" >> $outDir/analysisResults.html
  done

  #######################################



  #### Seed Voxel Correlation (Setup) ###
  echo "...Seed Voxel Correlation Setup"

  #Dimensions of EPI data
  numXdim=`fslinfo $rsMean | grep ^dim1 | awk '{print $2}'`
  numYdim=`fslinfo $rsMean | grep ^dim2 | awk '{print $2}'`
  numZdim=`fslinfo $rsMean | grep ^dim3 | awk '{print $2}'`

  #Perform the Correlation
    #Take into account $motionscrubFlag

  if [[ $motionscrubFlag == 0 ]]; then

    # If $motionscrubFlag == 0 (no motionscrub), res4dnormandscaled never gets unzipped
    if [[ -e $outDir/$nuisancefeat/stats/res4d_normandscaled.nii.gz ]]; then
      gunzip $outDir/$nuisancefeat/stats/res4d_normandscaled.nii.gz
    fi

  echo "...Creating Octave script"
cat > $filename << EOF
% It is matlab script
addpath('${scriptDir}')
statsScripts=['${scriptDir}','/Octave/nifti'];
addpath(statsScripts)
fid=fopen('$outDir/seeds.txt');
roiList=textscan(fid,'%s');
fclose(fid);

funcvoldim=[$numXdim $numYdim ${numZdim}];
doFisherZ=1;
motion_scrub=0;
input='res4d_normandscaled.nii';

firstlevelseeding_parallel('$outDir',roiList,'$nuisancefeat',funcvoldim,input,motion_scrub,doFisherZ)
quit
EOF

  elif [[ $motionscrubFlag == 1 ]]; then

    echo "...Creating Octave script (motionscrubbed data)"
cat > $filename2 << EOF
% It is matlab script
addpath('${scriptDir}')
statsScripts=['${scriptDir}','/Octave/nifti'];
addpath(statsScripts)
fid=fopen('$outDir/seeds.txt');
roiList=textscan(fid,'%s');
fclose(fid);

funcvoldim=[$numXdim $numYdim ${numZdim}];
doFisherZ=1;
motion_scrub=1;
input='res4d_normandscaled_motionscrubbed.nii';

firstlevelseeding_parallel('$outDir',roiList,'$nuisancefeat',funcvoldim,input,motion_scrub,doFisherZ)
quit
EOF

  else

    echo "...Creating Octave script"
cat > $filename << EOF
% It is matlab script
addpath('${scriptDir}')
statsScripts=['${scriptDir}','/Octave/nifti'];
addpath(statsScripts)
fid=fopen('$outDir/seeds.txt');
roiList=textscan(fid,'%s');
fclose(fid);

funcvoldim=[$numXdim $numYdim ${numZdim}];
doFisherZ=1;
motion_scrub=0;
input='res4d_normandscaled.nii';

firstlevelseeding_parallel('$outDir',roiList,'$nuisancefeat',funcvoldim,input,motion_scrub,doFisherZ)
quit
EOF

    echo "...Creating Octave script (motionscrubbed data)"
cat > $filename2 << EOF
% It is matlab script
addpath('${scriptDir}')
statsScripts=['${scriptDir}','/Octave/nifti'];
addpath(statsScripts)
fid=fopen('$outDir/seeds.txt');
roiList=textscan(fid,'%s');
fclose(fid);

funcvoldim=[$numXdim $numYdim ${numZdim}];
doFisherZ=1;
motion_scrub=1;
input='res4d_normandscaled_motionscrubbed.nii';

firstlevelseeding_parallel('$outDir',roiList,'$nuisancefeat',funcvoldim,input,motion_scrub,doFisherZ)
quit
EOF

  fi

  #######################################



  #### Seed Voxel Correlation (Execution) #
  echo "...Correlating Seeds With Time Series Data"

    # Run script using Matlab or Octave
      # Check for $motionscrubFlag, run appropriate file(s)
  haveMatlab=`which matlab`
  if [[ "$haveMatlab" == "" ]]; then
    if [[ $motionscrubFlag == 0 ]]; then
      octave --no-window-system $outDir/$filename
    elif [[ $motionscrubFlag == 1 ]]; then
      octave --no-window-system $outDir/$filename2
    else
      octave --no-window-system $outDir/$filename
      octave --no-window-system $outDir/$filename2
    fi
  else
    if [[ $motionscrubFlag == 0 ]]; then
      matlab -nodisplay -r "run $outDir/$filename"
    elif [[ $motionscrubFlag == 1 ]]; then
      matlab -nodisplay -r "run $outDir/$filename2"
    else
      matlab -nodisplay -r "run $outDir/$filename"
      matlab -nodisplay -r "run $outDir/$filename2"
    fi  
  fi

  #######################################



  #### Zstat Results (to T1/MNI) ########

  if [ $reviewResults == 1 ]; then
    echo "...Creating zstat Results Directory"

    #Check for existence of output directory
    if [[ ! -e $outDir/seedCorrelation ]]; then
      mkdir $outDir/seedCorrelation
    fi

    #Copy over anatomical files to results directory
      #T1 (highres)
    cp $outDir/${nuisancefeat}/reg/highres.nii.gz $outDir/seedCorrelation

      #T1toMNI (highres2standard)
    cp $outDir/${nuisancefeat}/reg/highres2standard.nii.gz $outDir/seedCorrelation

      #MNI (standard)
    cp $outDir/${nuisancefeat}/reg/standard.nii.gz $outDir/seedCorrelation


    #HTML setup
    echo "<hr><h2>Seed Time Series</h2>" >> $outDir/analysisResults.html

    for roi in $roiList
    do

      echo "...Mapping Correlation For $roi To Subject T1"

      ####Adjust for motion scrubbing
      if [[ $motionscrubFlag == 0 ]]; then
        #No motionscrubbing
        if [ -e ${roi}.png ]; then
          rm ${roi}.png
        fi

        #Check for FieldMap registration correction
        if [[ $fieldMapFlag == 1 ]]; then
          #Nonlinear warp from EPI to T1
          applywarp --in=$outDir/${nuisancefeat}/stats/${roi}/cope1.nii \
          --ref=$outDir/${nuisancefeat}/reg/highres.nii.gz \
          --out=$outDir/seedCorrelation/${roi}_standard_zmap.nii.gz \
          --warp=$outDir/${nuisancefeat}/reg/example_func2highres_warp.nii.gz \
          --datatype=float
        else
          #Affine Transform from EPI to T1
          flirt -in $outDir/${nuisancefeat}/stats/${roi}/cope1.nii \
          -ref $outDir/${nuisancefeat}/reg/highres.nii.gz \
          -out $outDir/seedCorrelation/${roi}_highres_zmap.nii.gz \
          -applyxfm -init $outDir/${nuisancefeat}/reg/example_func2highres.mat \
          -datatype float
        fi

        #Nonlinear warp from EPI to MNI
        applywarp --in=$outDir/${nuisancefeat}/stats/${roi}/cope1.nii \
        --ref=$outDir/${nuisancefeat}/reg/standard.nii.gz \
        --out=$outDir/seedCorrelation/${roi}_standard_zmap.nii.gz \
        --warp=$outDir/${nuisancefeat}/reg/example_func2standard_warp.nii.gz \
        --datatype=float

          #Mask out data with MNI mask
          fslmaths $outDir/seedCorrelation/${roi}_standard_zmap.nii.gz -mas $FSLDIR/data/standard/MNI152_T1_2mm_brain_mask.nii.gz $outDir/seedCorrelation/${roi}_standard_zmap_masked.nii.gz

        #Copy over Seed ROI        
        cp ${roiDir}/${roi}.nii.gz $outDir/seedCorrelation/${roi}_standard.nii.gz

        ##Creating new plots with fsl_tsplot
          #~2.2% plotting difference between actual Ymin and Ymax values (higher and lower), with fsl_tsplot
        yMax=`cat $outDir/${nuisancefeat}/stats/${roi}_residvol_ts.txt | sort -r | tail -1 | awk '{print ($1+($1*0.0022))}'`
        yMin=`cat $outDir/${nuisancefeat}/stats/${roi}_residvol_ts.txt | tail -1 | awk '{print ($1-($1*0.0022))}'`

        fsl_tsplot -i $outDir/${nuisancefeat}/stats/${roi}_residvol_ts.txt -t "$roi Time Series" -u 1 --start=1 -x 'Time Points (TR)' --ymin=$yMin --ymax=$yMax -w 800 -h 300 -o $outDir/${roi}.png

        echo "<br><img src=\"$outDir/${roi}.png\" alt=\"$roi seed\"><br>" >> $outDir/analysisResults.html

      elif [[ $motionscrubFlag == 1 ]]; then
        #Only motionscrubbed data
        if [ -e ${roi}_ms.png ]; then
          rm ${roi}_ms.png
        fi

        #Check for FieldMap registration correction
        if [[ $fieldMapFlag == 1 ]]; then
          #Nonlinear warp from EPI to T1
          applywarp --in=$outDir/${nuisancefeat}/stats/${roi}_ms/cope1.nii \
          --ref=$outDir/${nuisancefeat}/reg/highres.nii.gz \
          --out=$outDir/seedCorrelation/${roi}_ms_standard_zmap.nii.gz \
          --warp=$outDir/${nuisancefeat}/reg/example_func2highres_warp.nii.gz \
          --datatype=float
        else
          #Affine Transform from EPI to T1
          flirt -in $outDir/${nuisancefeat}/stats/${roi}_ms/cope1.nii \
          -ref $outDir/${nuisancefeat}/reg/highres.nii.gz \
          -out $outDir/seedCorrelation/${roi}_ms_highres_zmap.nii.gz \
          -applyxfm -init $outDir/${nuisancefeat}/reg/example_func2highres.mat \
          -datatype float
        fi

        #Nonlinear warp from EPI to MNI
        applywarp --in=$outDir/${nuisancefeat}/stats/${roi}_ms/cope1.nii \
        --ref=$outDir/${nuisancefeat}/reg/standard.nii.gz \
        --out=$outDir/seedCorrelation/${roi}_ms_standard_zmap.nii.gz \
        --warp=$outDir/${nuisancefeat}/reg/example_func2standard_warp.nii.gz \
        --datatype=float

          #Mask out data with MNI mask
          fslmaths $outDir/seedCorrelation/${roi}_ms_standard_zmap.nii.gz -mas $FSLDIR/data/standard/MNI152_T1_2mm_brain_mask.nii.gz $outDir/seedCorrelation/${roi}_ms_standard_zmap_masked.nii.gz

        #Copy over Seed ROI  
        cp ${roiDir}/${roi}.nii.gz $outDir/seedCorrelation/${roi}_standard.nii.gz


        #Look for the presence of deleted volumes.  ONLY create "spike" (ms) images if found, otherwise default to non-motionscrubbed images
        scrubDataCheck=`cat $outDir/$nuisancefeat/stats/deleted_vols.txt | head -1`

        if [[ $scrubDataCheck != "" ]]; then
          #Presence of scrubbed volumes

          ##Creating new plots with fsl_tsplot
            #~2.2% plotting difference between actual Ymin and Ymax values (higher and lower), with fsl_tsplot
          yMax=`cat $outDir/${nuisancefeat}/stats/${roi}_residvol_ts.txt | sort -r | tail -1 | awk '{print ($1+($1*0.0022))}'`
          yMin=`cat $outDir/${nuisancefeat}/stats/${roi}_residvol_ts.txt | tail -1 | awk '{print ($1-($1*0.0022))}'`

            #Log the "scrubbed TRs"
          xNum=`cat $outDir/${nuisancefeat}/stats/${roi}_residvol_ts.txt | wc -l`
          count=1
          while [ $count -le $xNum ]; do
            tsPlotIn=`cat $outDir/${nuisancefeat}/stats/${roi}_residvol_ts.txt | head -${count} | tail -1`
            delPlotCheck=`cat $outDir/${nuisancefeat}/stats/deleted_vols.txt | awk '{$1=$1}1' | grep -E '(^| )'${count}'( |$)'`
            if [ "$delPlotCheck" == "" ]; then
              delPlot=$yMin
            else
              delPlot=$yMax
            fi
            echo $delPlot >> $outDir/${nuisancefeat}/stats/${roi}_censored_TRplot.txt
          let count=count+1
          done

          #Plot of normal data showing scrubbed TRs
          fsl_tsplot -i $outDir/${nuisancefeat}/stats/${roi}_residvol_ts.txt,$outDir/${nuisancefeat}/stats/${roi}_censored_TRplot.txt -t "$roi Time Series" -u 1 --start=1 -x 'Time Points (TR)' -a ",Scrubbed_TR" --ymin=$yMin --ymax=$yMax -w 800 -h 300 -o $outDir/${roi}.png

          #Plot of "scrubbed" data
          fsl_tsplot -i $outDir/${nuisancefeat}/stats/${roi}_residvol_ms_ts.txt -t "$roi Time Series (Scrubbed)" -u 1 --start=1 -x 'Time Points (TR)' --ymin=$yMin --ymax=$yMax -w 800 -h 300 -o $outDir/${roi}_ms.png


          echo "<br><img src=\"$outDir/${roi}.png\" alt=\"${roi} seed\"><img src=\"$outDir/${roi}_ms.png\" alt=\"${roi}_ms seed\"><br>" >> $outDir/analysisResults.html        

        else
          #Absence of scrubbed volumes

          ##Creating new plots with fsl_tsplot
            #~2.2% plotting difference between actual Ymin and Ymax values (higher and lower), with fsl_tsplot
          yMax=`cat $outDir/${nuisancefeat}/stats/${roi}_residvol_ts.txt | sort -r | tail -1 | awk '{print ($1+($1*0.0022))}'`
          yMin=`cat $outDir/${nuisancefeat}/stats/${roi}_residvol_ts.txt | tail -1 | awk '{print ($1-($1*0.0022))}'`

          fsl_tsplot -i $outDir/${nuisancefeat}/stats/${roi}_residvol_ts.txt -t "$roi Time Series" -u 1 --start=1 -x 'Time Points (TR)' --ymin=$yMin --ymax=$yMax -w 800 -h 300 -o $outDir/${roi}.png

          echo "<br><img src=\"$outDir/${roi}.png\" alt=\"$roi seed\"><br>" >> $outDir/analysisResults.html        
        fi

      else
        #motionScrubFlag=2
          ##Non-motionscrubbed data
        if [ -e ${roi}.png ]; then
          rm ${roi}.png
        fi
        if [ -e ${roi}_ms.png ]; then
          rm ${roi}_ms.png
        fi

        #Check for FieldMap registration correction
        if [[ $fieldMapFlag == 1 ]]; then
          #Nonlinear warp from EPI to T1
          applywarp --in=$outDir/${nuisancefeat}/stats/${roi}/cope1.nii \
          --ref=$outDir/${nuisancefeat}/reg/highres.nii.gz \
          --out=$outDir/seedCorrelation/${roi}_standard_zmap.nii.gz \
          --warp=$outDir/${nuisancefeat}/reg/example_func2highres_warp.nii.gz \
          --datatype=float
        else
          #Affine Transform from EPI to T1
          flirt -in $outDir/${nuisancefeat}/stats/${roi}/cope1.nii \
          -ref $outDir/${nuisancefeat}/reg/highres.nii.gz \
          -out $outDir/seedCorrelation/${roi}_highres_zmap.nii.gz \
          -applyxfm -init $outDir/${nuisancefeat}/reg/example_func2highres.mat \
          -datatype float
        fi

        #Nonlinear warp from EPI to MNI
        applywarp --in=$outDir/${nuisancefeat}/stats/${roi}/cope1.nii \
        --ref=$outDir/${nuisancefeat}/reg/standard.nii.gz \
        --out=$outDir/seedCorrelation/${roi}_standard_zmap.nii.gz \
        --warp=$outDir/${nuisancefeat}/reg/example_func2standard_warp.nii.gz \
        --datatype=float

          #Mask out data with MNI mask
          fslmaths $outDir/seedCorrelation/${roi}_standard_zmap.nii.gz -mas $FSLDIR/data/standard/MNI152_T1_2mm_brain_mask.nii.gz $outDir/seedCorrelation/${roi}_standard_zmap_masked.nii.gz

        #Copy over Seed ROI  
        cp ${roiDir}/${roi}.nii.gz $outDir/seedCorrelation/${roi}_standard.nii.gz

          ##Motionscrubbed data
          #Check for FieldMap registration correction
        if [[ $fieldMapFlag == 1 ]]; then
          #Nonlinear warp from EPI to T1
          applywarp --in=$outDir/${nuisancefeat}/stats/${roi}_ms/cope1.nii \
          --ref=$outDir/${nuisancefeat}/reg/highres.nii.gz \
          --out=$outDir/seedCorrelation/${roi}_ms_standard_zmap.nii.gz \
          --warp=$outDir/${nuisancefeat}/reg/example_func2highres_warp.nii.gz \
          --datatype=float



        else
          #Affine Transform from EPI to T1
          flirt -in $outDir/${nuisancefeat}/stats/${roi}_ms/cope1.nii \
          -ref $outDir/${nuisancefeat}/reg/highres.nii.gz \
          -out $outDir/seedCorrelation/${roi}_ms_highres_zmap.nii.gz \
          -applyxfm -init $outDir/${nuisancefeat}/reg/example_func2highres.mat \
          -datatype float
        fi

        #Nonlinear warp from EPI to MNI
        applywarp --in=$outDir/${nuisancefeat}/stats/${roi}_ms/cope1.nii \
        --ref=$outDir/${nuisancefeat}/reg/standard.nii.gz \
        --out=$outDir/seedCorrelation/${roi}_ms_standard_zmap.nii.gz \
        --warp=$outDir/${nuisancefeat}/reg/example_func2standard_warp.nii.gz \
        --datatype=float

          #Mask out data with MNI mask
          fslmaths $outDir/seedCorrelation/${roi}_ms_standard_zmap.nii.gz -mas $FSLDIR/data/standard/MNI152_T1_2mm_brain_mask.nii.gz $outDir/seedCorrelation/${roi}_ms_standard_zmap_masked.nii.gz


        #Look for the presence of deleted volumes.  ONLY create "spike" (ms) images if found, otherwise default to non-motionscrubbed images
        scrubDataCheck=`cat $outDir/$nuisancefeat/stats/deleted_vols.txt | head -1`

        if [[ $scrubDataCheck != "" ]]; then
          #Presence of scrubbed volumes

          ##Creating new plots with fsl_tsplot
            #~2.2% plotting difference between actual Ymin and Ymax values (higher and lower), with fsl_tsplot
          yMax=`cat $outDir/${nuisancefeat}/stats/${roi}_residvol_ts.txt | sort -r | tail -1 | awk '{print ($1+($1*0.0022))}'`
          yMin=`cat $outDir/${nuisancefeat}/stats/${roi}_residvol_ts.txt | tail -1 | awk '{print ($1-($1*0.0022))}'`

            #Log the "scrubbed TRs"
          xNum=`cat $outDir/${nuisancefeat}/stats/${roi}_residvol_ts.txt | wc -l`
          count=1
          while [ $count -le $xNum ]; do
            tsPlotIn=`cat $outDir/${nuisancefeat}/stats/${roi}_residvol_ts.txt | head -${count} | tail -1`
            delPlotCheck=`cat $outDir/${nuisancefeat}/stats/deleted_vols.txt | awk '{$1=$1}1' | grep -E '(^| )'${count}'( |$)'`
            if [ "$delPlotCheck" == "" ]; then
              delPlot=$yMin
            else
              delPlot=$yMax
            fi
            echo $delPlot >> $outDir/${nuisancefeat}/stats/${roi}_censored_TRplot.txt
          let count=count+1
          done

          #Plot of normal data showing scrubbed TRs
          fsl_tsplot -i $outDir/${nuisancefeat}/stats/${roi}_residvol_ts.txt,$outDir/${nuisancefeat}/stats/${roi}_censored_TRplot.txt -t "$roi Time Series" -u 1 --start=1 -x 'Time Points (TR)' -a ",Scrubbed_TR" --ymin=$yMin --ymax=$yMax -w 800 -h 300 -o $outDir/${roi}.png

          #Plot of "scrubbed" data
          fsl_tsplot -i $outDir/${nuisancefeat}/stats/${roi}_residvol_ms_ts.txt -t "$roi Time Series (Scrubbed)" -u 1 --start=1 -x 'Time Points (TR)' --ymin=$yMin --ymax=$yMax -w 800 -h 300 -o $outDir/${roi}_ms.png


          echo "<br><img src=\"$outDir/${roi}.png\" alt=\"${roi} seed\"><img src=\"$outDir/${roi}_ms.png\" alt=\"${roi}_ms seed\"><br>" >> $outDir/analysisResults.html

        else
          #No scrubbed TRs

          ##Creating new plots with fsl_tsplot
            #~2.2% plotting difference between actual Ymin and Ymax values (higher and lower), with fsl_tsplot
          yMax=`cat $outDir/${nuisancefeat}/stats/${roi}_residvol_ts.txt | sort -r | tail -1 | awk '{print ($1+($1*0.0022))}'`
          yMin=`cat $outDir/${nuisancefeat}/stats/${roi}_residvol_ts.txt | tail -1 | awk '{print ($1-($1*0.0022))}'`

          fsl_tsplot -i $outDir/${nuisancefeat}/stats/${roi}_residvol_ts.txt -t "$roi Time Series" -u 1 --start=1 -x 'Time Points (TR)' --ymin=$yMin --ymax=$yMax -w 800 -h 300 -o $outDir/${roi}.png

          echo "<br><img src=\"$outDir/${roi}.png\" alt=\"$roi seed\"><br>" >> $outDir/analysisResults.html             
        fi
      fi     
    done
  fi

  #######################################


  echo "$0 Complete"
  echo "Please make sure that the ROI folders were created in the nuisancereg.feat/stats/ folder."
  echo "If resultant warped seeds (to MNI) were too small, they were NOT processed.  Check nuisancereg.feat/stats/seedsTooSmall for exclusions."
  echo "If motionscrubbing was set to 1 or 2, make sure that motionscrubbed data was created."
  echo "OCTAVE/Matlab wouldn't give an error even if this step was not successfully done."

#########################################################################

############################### End data processing  ###################################################################




