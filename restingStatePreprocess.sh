#!/bin/bash

########################################################################
# FEAT directory setup, smoothing, registration fixes
#     1. Dummy FEAT run (to get directory setup)
#     2. Data Smoothing (SUSAN)
#     3. "reg" directory setup
#      a. Populate with correct registrations from fnirt/BBR
#      b. updatefeatreg (fix registrations, logs, QC pics, etc.)
#        *updatefeatreg breaks on a simple affine transform,
#         replicating needed steps (slicer/pngappend)
########################################################################

scriptPath=$(perl -e 'use Cwd "abs_path";print abs_path(shift)' $0)
scriptDir=$(dirname $scriptPath)
analysis=preproc
fsf=${analysis}.fsf
preprocfeat=${analysis}.feat
SGE_ROOT='';export SGE_ROOT


function printCommandLine {
  echo "Usage: restingStatePreprocess.sh -A anatomicalImage -E restingStateImage -t tr -T te -s smooth -f -c"
  echo " where"
  echo "   -E Resting State file (motion-corrected, skull-stripped)"
  echo "   -A T1 file (skull-stripped)"
  echo "       *Both EPI and T1 should be from output of qualityCheck script"
  echo "   -t TR time (seconds)"
  echo "   -T TE (milliseconds) (default to 30 ms)"
  echo "   -s spatial smoothing filter size (mm)"
  echo "   -f (fieldMap registration correction)"
  echo "     *Set this if FieldMap correction was used for BBR to properly update the FEAT registrations"
  echo "   -c clobber/overwrite previous results"
  exit 1
}


# Parse Command line arguments
while getopts "hE:A:t:T:s:fc" OPTION
do
  case $OPTION in
    h)
      printCommandLine
      ;;
    E)
      epiData=$OPTARG
      ;;
    A)
      t1Data=$OPTARG
      ;;
    t)
      tr=$OPTARG
      ;;
    T)
      te=$OPTARG
      ;;
    s)
      smooth=$OPTARG
      ;;
    f)
      fieldMapFlag=1
      ;;
    c)
      overwriteFlag=1
      ;;
    ?)
      echo "ERROR: Invalid option"
      printCommandLine
      ;;
     esac
done




if [ "$epiData" == "" ]; then
  echo "Error: The restingStateImage (-E) is a required option"
  exit 1
fi

if [ "$t1Data" == "" ]; then
  echo "Error: The T1 image (-A) is a required option"
  exit 1
fi

if [ "$FSLDIR" == "" ]; then
  echo "Error: The Environmental variable FSLDIR must be set"
  exit 1
fi


#A few default parameters (if input not specified, these parameters are assumed)
if [[ $te == "" ]]; then
  te=30
fi

if [[ $tr == "" ]]; then
  tr=2
fi

if [[ $smooth == "" ]]; then
  smooth=6
fi

if [[ $fieldMapFlag == "" ]]; then
  fieldMapFlag=0
fi

if [[ $overwriteFlag == "" ]]; then
  overWriteFlag=0
fi



indir=$(dirname $epiData)
subjectDir=$(dirname $indir)



# Echo out all input parameters into a log
logDir=$(dirname $epiData)
echo "$scriptPath" >> $logDir/rsParams_log
echo "------------------------------------" >> $logDir/rsParams_log
echo "-E $epiData" >> $logDir/rsParams_log
echo "-A $t1Data" >> $logDir/rsParams_log
echo "-t $tr" >> $logDir/rsParams_log
echo "-T $te" >> $logDir/rsParams_log
echo "-s $smooth" >> $logDir/rsParams_log
if [[ $fieldMapFlag == 1 ]]; then
  echo "-f" >> $logDir/rsParams_log
fi
if [[ $overwriteFlag == 1 ]]; then
  echo "-c" >> $logDir/rsParams_log
fi
echo "$(date)" >> $logDir/rsParams_log
echo "" >> $logDir/rsParams_log
echo "" >> $logDir/rsParams_log



echo "Running $0 ..."

cd $indir


# Set a few variables from data
# epi_reg peDir setup (e.g. -y) is backwards from FEAT peDir (e.g. y-)
peDirBase=$(cat $logDir/rsParams | grep "peDir=" | tail -1 | awk -F"=" '{print $2}')
peDirTmp1=$(echo $peDirBase | cut -c1)
peDirTmp2=$(echo $peDirBase | cut -c2)
if [[ "$peDirTmp1" == "-" ]]; then
  peDirNEW="${peDirTmp2}${peDirTmp1}"
else
  peDirNEW="${peDirBase}"
fi

numtimepoint=$(fslinfo $epiData | grep ^dim4 | awk '{print $2}')

dwellTime=$(cat $logDir/rsParams | grep "epiDwell=" | tail -1 | awk -F"=" '{print $2}')


# Check for overwrite permissions
if [[ -e $indir/${preprocfeat} ]]; then
  if [[ $overwriteFlag == 1 ]]; then

    # Overwrite data
    rm -rf ${indir:?}/${preprocfeat}
    echo "_restingStatePreprocess_clobber" >> ${indir}/rsParams

    ###### FEAT (preproc) ########################################
    echo "...Running FEAT (preproc)"
    epiVoxTot=$(fslstats ${epiData} -v | awk '{print $1}')

    # .fsf setup
    cat $scriptDir/dummy_preproc_5.0.10.fsf | sed 's|SUBJECTPATH|'${indir}'|g'  | \
                                       sed 's|SUBJECTEPIPATH|'${epiData}'|g' |  \
                                       sed 's|SUBJECTT1PATH|'${t1Data}'|g' | \
                                       sed 's|SCANTE|'${te}'|g' | \
                                       sed 's|SUBJECTVOLS|'${numtimepoint}'|g' | \
                                       sed 's|SUBJECTSMOOTH|'${smooth}'|g' | \
                                       sed 's|SUBJECTTR|'${tr}'|g' | \
                                       sed 's|EPIDWELL|'${dwellTime}'|g' | \
                                       sed 's|VOXTOT|'${epiVoxTot}'|g' | \
                                       sed 's|PEDIR|'${peDirNEW}'|g' | \
                                       sed 's|FSLDIR|'${FSLDIR}'|g' > ${indir}/${fsf}
    # Run FEAT
    feat ${indir}/${fsf}

    ################################################################



    ###### Gaussian Smoothing ########################################
    echo "...Guassian Smoothing"

    preprocDir=$indir/${preprocfeat}

    # Guassian smooth:  mm to sigma
    # https://www.jiscmail.ac.uk/cgi-bin/webadmin?A2=FSL;d7249c17.1301
    # sigma=mm/sqrt(8*ln(2))
    smoothSigma=$(echo $smooth | awk '{print ($1/(sqrt(8*log(2))))}')

    # Determine 50% intensity of data, thresholded at 75% (for all non-zero voxels)
    epiThreshVal=$(fslstats $epiData -P 50 | awk '{print ($1*0.75)}')

    # Create a time-series mean of $epiData
    fslmaths $epiData -Tmean $preprocDir/mean_func.nii.gz

    # Binarize mean image and make a mask
    fslmaths $preprocDir/mean_func.nii.gz -bin $preprocDir/mask.nii.gz -odt char

    # SUSAN for smoothing
    susan $epiData $epiThreshVal $smoothSigma 3 1 1 $preprocDir/mean_func.nii.gz $epiThreshVal $preprocDir/nonfiltered_smooth.nii.gz

    # Threshold output by mean mask, rename original data
    fslmaths $preprocDir/nonfiltered_smooth.nii.gz -mul $preprocDir/mask.nii.gz $preprocDir/nonfiltered_smooth_data.nii.gz
    mv $preprocDir/nonfiltered_smooth.nii.gz $preprocDir/nonfiltered_smooth_data_orig.nii.gz

    # Echo out output to rsParams file
    echo "epiNonfilt=$preprocDir/nonfiltered_smooth_data.nii.gz" >> $indir/rsParams

    ################################################################


    ###### FEAT registration correction ########################################
    echo "...Fixing FEAT registration QC images."

    # http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FEAT/FAQ
    # ss: "How can I insert a custom registration into a FEAT analysis?"

    regDir=$preprocDir/reg

    # Remove all FEAT files (after backup), repopulate with proper files
    cp -r $regDir $preprocDir/regORIG
    rm -f $regDir/*

    # Copy over appropriate files from previous processing
    # T1 (highres)
    fslmaths $t1Data $regDir/highres.nii.gz
    t1toMNI=$(cat $indir/rsParams | grep "T1toMNI=" | tail -1 | awk -F"=" '{print $2}')
    fslmaths $t1toMNI $regDir/highres2standard.nii.gz

    # EPI (example_func)
    fslmaths $epiData $regDir/example_func.nii.gz
    epitoT1=$(cat $indir/rsParams | grep "EPItoT1=" | tail -1 | awk -F"=" '{print $2}')
    fslmaths $epitoT1 $regDir/example_func2highres.nii.gz
    epitoMNI=$(cat $indir/rsParams | grep "EPItoMNI=" | tail -1 | awk -F"=" '{print $2}')
    fslmaths $epitoMNI $regDir/example_func2standard.nii.gz

    # MNI (standard)
    fslmaths $FSLDIR/data/standard/avg152T1_brain.nii.gz $regDir/standard.nii.gz

    # Transforms
    # EPItoT1/T1toEPI (Check for presence of FieldMap Correction)
    epiWarpDirtmp=$(cat $indir/rsParams | grep "EPItoT1Warp=" | tail -1 | awk -F"=" '{print $2}')
    epiWarpDir=$(dirname $epiWarpDirtmp)

    if [[ $fieldMapFlag == 1 ]]; then
      #Copy the EPItoT1 warp file
      cp  $epiWarpDir/EPItoT1_warp.nii.gz $regDir/example_func2highres_warp.nii.gz
    else
      #Only copy the affine .mat files
      cp $epiWarpDir/EPItoT1_init.mat $regDir/example_func2initial_highres.mat
      cp $epiWarpDir/EPItoT1.mat $regDir/example_func2highres.mat
    fi

    # T1toMNI
    T1WarpDirtmp=$(cat $indir/rsParams | grep "MNItoT1IWarp=" | tail -1 | awk -F"=" '{print $2}')
    T1WarpDir=$(dirname $T1WarpDirtmp)

    cp $T1WarpDir/T1_to_MNIaff.mat $regDir/highres2standard.mat
    cp $T1WarpDir/coef_T1_to_MNI152.nii.gz $regDir/highres2standard_warp.nii.gz

    # EPItoMNI
    cp $epiWarpDir/EPItoMNI_warp.nii.gz $regDir/example_func2standard_warp.nii.gz

    # MNItoT1
    cp $T1WarpDirtmp $regDir/standard2highres_warp.nii.gz

    # Forgoing "updatefeatreg" and just recreating the appropriate pics with slicer/pngappend
    cd $regDir

    # example_func2highres
    echo "......func2highres"
    slicer example_func2highres.nii.gz highres.nii.gz -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png
    pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png example_func2highres1.png

    slicer highres.nii.gz example_func2highres.nii.gz -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png
    pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png example_func2highres2.png

    pngappend example_func2highres1.png - example_func2highres2.png example_func2highres.png

    rm sl*.png

    # highres2standard
    echo "......highres2standard"
    slicer highres2standard.nii.gz standard.nii.gz -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png
    pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png highres2standard1.png

    slicer standard.nii.gz highres2standard.nii.gz -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png
    pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png highres2standard2.png

    pngappend highres2standard1.png - highres2standard2.png highres2standard.png

    rm sl*.png

    # example_func2standard
    echo "......func2standard"
    slicer example_func2standard.nii.gz standard.nii.gz -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png
    pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png example_func2standard1.png

    slicer standard.nii.gz example_func2standard.nii.gz -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png
    pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png example_func2standard2.png

    pngappend example_func2standard1.png - example_func2standard2.png example_func2standard.png

    rm sl*.png

    ################################################################

  else
    echo "$0 has already been run. Use the -c option to overwrite results"
    exit
  fi
else
  # First instance of smoothing, reg setup
  epiVoxTot=$(fslstats ${epiData} -v | awk '{print $1}')
  ###### FEAT (preproc) ########################################
  echo "...Running FEAT (preproc)"

  # .fsf setup
  cat $scriptDir/dummy_preproc_5.0.10.fsf | sed 's|SUBJECTPATH|'${indir}'|g'  | \
                                     sed 's|SUBJECTEPIPATH|'${epiData}'|g' |  \
                                     sed 's|SUBJECTT1PATH|'${t1Data}'|g' | \
                                     sed 's|SCANTE|'${te}'|g' | \
                                     sed 's|SUBJECTVOLS|'${numtimepoint}'|g' | \
                                     sed 's|SUBJECTSMOOTH|'${smooth}'|g' | \
                                     sed 's|SUBJECTTR|'${tr}'|g' | \
                                     sed 's|VOXTOT|'${epiVoxTot}'|g' | \
                                     sed 's|EPIDWELL|'${dwellTime}'|g' | \
                                     sed 's|PEDIR|'${peDirNEW}'|g' | \
                                     sed 's|FSLDIR|'${FSLDIR}'|g' > ${indir}/${fsf}
  # Run FEAT
  feat ${indir}/${fsf}

  ################################################################


  ###### Gaussian Smoothing ########################################
  echo "...Guassian Smoothing"

  preprocDir=$indir/${preprocfeat}

  # Guassian smooth:  mm to sigma
  # https://www.jiscmail.ac.uk/cgi-bin/webadmin?A2=FSL;d7249c17.1301
  # sigma=mm/sqrt(8*ln(2))
  smoothSigma=$(echo $smooth | awk '{print ($1/(sqrt(8*log(2))))}')

  # Determine 50% intensity of data, thresholded at 75% (for all non-zero voxels)
  epiThreshVal=$(fslstats $epiData -P 50 | awk '{print ($1*0.75)}')

  # Create a time-series mean of $epiData
  fslmaths $epiData -Tmean $preprocDir/mean_func.nii.gz

  # Binarize mean image and make a mask
  fslmaths $preprocDir/mean_func.nii.gz -bin $preprocDir/mask.nii.gz -odt char

  # SUSAN for smoothing
  susan $epiData $epiThreshVal $smoothSigma 3 1 1 $preprocDir/mean_func.nii.gz $epiThreshVal $preprocDir/nonfiltered_smooth.nii.gz

  # Threshold output by mean mask, rename original data
  fslmaths $preprocDir/nonfiltered_smooth.nii.gz -mul $preprocDir/mask.nii.gz $preprocDir/nonfiltered_smooth_data.nii.gz
  mv $preprocDir/nonfiltered_smooth.nii.gz $preprocDir/nonfiltered_smooth_data_orig.nii.gz

  # Echo out output to rsParams file
  echo "epiNonfilt=$preprocDir/nonfiltered_smooth_data.nii.gz" >> $indir/rsParams

  ################################################################


  ###### FEAT registration correction ########################################
  echo "...Fixing FEAT registration QC images."

  # http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FEAT/FAQ
  # ss: "How can I insert a custom registration into a FEAT analysis?"

  regDir=$preprocDir/reg

  # Remove all FEAT files (after backup), repopulate with proper files
  cp -r $regDir $preprocDir/regORIG
  rm -f $regDir/*

  # Copy over appropriate files from previous processing
  # T1 (highres)
  fslmaths $t1Data $regDir/highres.nii.gz
  t1toMNI=$(cat $indir/rsParams | grep "T1toMNI=" | tail -1 | awk -F"=" '{print $2}')
  fslmaths $t1toMNI $regDir/highres2standard.nii.gz

  # EPI (example_func)
  fslmaths $epiData $regDir/example_func.nii.gz
  epitoT1=$(cat $indir/rsParams | grep "EPItoT1=" | tail -1 | awk -F"=" '{print $2}')
  fslmaths $epitoT1 $regDir/example_func2highres.nii.gz
  epitoMNI=$(cat $indir/rsParams | grep "EPItoMNI=" | tail -1 | awk -F"=" '{print $2}')
  fslmaths $epitoMNI $regDir/example_func2standard.nii.gz

  # MNI (standard)
  fslmaths $FSLDIR/data/standard/avg152T1_brain.nii.gz $regDir/standard.nii.gz

  # Transforms
  # EPItoT1/T1toEPI (Check for presence of FieldMap Correction)
  epiWarpDirtmp=$(cat $indir/rsParams | grep "EPItoT1Warp=" | tail -1 | awk -F"=" '{print $2}')
  epiWarpDir=$(dirname $epiWarpDirtmp)

  if [[ $fieldMapFlag == 1 ]]; then
    # Copy the EPItoT1 warp file
    cp  $epiWarpDir/EPItoT1_warp.nii.gz $regDir/example_func2highres_warp.nii.gz
  else
    # Only copy the affine .mat files
    cp $epiWarpDir/EPItoT1_init.mat $regDir/example_func2initial_highres.mat
    cp $epiWarpDir/EPItoT1.mat $regDir/example_func2highres.mat
  fi

  # T1toMNI
  T1WarpDirtmp=$(cat $indir/rsParams | grep "MNItoT1IWarp=" | tail -1 | awk -F"=" '{print $2}')
  T1WarpDir=$(dirname $T1WarpDirtmp)

  cp $T1WarpDir/T1_to_MNIaff.mat $regDir/highres2standard.mat
  cp $T1WarpDir/coef_T1_to_MNI152.nii.gz $regDir/highres2standard_warp.nii.gz

  # EPItoMNI
  cp $epiWarpDir/EPItoMNI_warp.nii.gz $regDir/example_func2standard_warp.nii.gz

  # MNItoT1
  cp $T1WarpDirtmp $regDir/standard2highres_warp.nii.gz


  # Forgoing "updatefeatreg" and just recreating the appropriate pics with slicer/pngappend
  cd $regDir

  # example_func2highres
  echo "......func2highres"
  slicer example_func2highres.nii.gz highres.nii.gz -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png
  pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png example_func2highres1.png

  slicer highres.nii.gz example_func2highres.nii.gz -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png
  pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png example_func2highres2.png

  pngappend example_func2highres1.png - example_func2highres2.png example_func2highres.png

  rm sl*.png

  # highres2standard
  echo "......highres2standard"
  slicer highres2standard.nii.gz standard.nii.gz -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png
  pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png highres2standard1.png

  slicer standard.nii.gz highres2standard.nii.gz -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png
  pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png highres2standard2.png

  pngappend highres2standard1.png - highres2standard2.png highres2standard.png

  rm sl*.png

  # example_func2standard
  echo "......func2standard"
  slicer example_func2standard.nii.gz standard.nii.gz -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png
  pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png example_func2standard1.png

  slicer standard.nii.gz example_func2standard.nii.gz -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png
  pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png example_func2standard2.png

  pngappend example_func2standard1.png - example_func2standard2.png example_func2standard.png

  rm sl*.png

  ################################################################
fi

cd $indir


# Log results to HTML file
echo "<hr><h2>Preprocessing Results</h2>" >> $indir/analysisResults.html
echo "<b>Spatial Filter Size (mm)</b>: $smooth<br>" >> $indir/analysisResults.html
echo "<b>TR (s): $tr</b><br>" >> $indir/analysisResults.html
echo "<b>TE (ms): $te</b><br>" >> $indir/analysisResults.html
echo "<b>Number of Time Points</b>: $numtimepoint<br>" >> $indir/analysisResults.html
echo "<br><a href=\"$indir/${preprocfeat}/report.html\">FSL Preprocessing Results</a>" >> $indir/analysisResults.html

echo "$0 Complete"
echo ""
echo ""
