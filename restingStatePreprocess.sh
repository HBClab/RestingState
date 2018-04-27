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

function Usage {
  echo "restingStatePreprocess.sh --epi=restingStateImage --t1brain=anatomicalImage --tr=tr --te=te --smooth=smoothing kernel -f -c"
  echo ""
  echo "   where:"
  echo "   --epi Resting State file"
  echo "   --t1brain skull-stripped T1 file"
  echo "   --tr TR time (seconds)"
  echo "   --te TE (milliseconds)"
  echo "   --smooth spatial smoothing kernel size"
  echo "   --usefmap fieldmap registration correction"
  echo "   --aroma run ICA_AROMA"
  echo "   -c clobber/overwrite previous results"
  exit 1
}

########## FSL's arg parsing functions ###################
get_opt1() {
    arg=`echo $1 | sed 's/=.*//'`
    echo $arg
}


get_arg1() {
    if [ X`echo $1 | grep '='` = X ] ; then
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

get_imarg1() {
    arg=`get_arg1 $1`;
    arg=`$FSLDIR/bin/remove_ext $arg`;
    echo $arg
}

# Overwrites material or skips
function clobber()
{
	# Tracking Variables
	local -i num_existing_files=0
	local -i num_args=$#

	# Tally all existing outputs
	for arg in "$@"; do
		if [ -s "${arg}" ] && [ "${clob}" == true ]; then
			rm -rf "${arg}"
		elif [ -s "${arg}" ] && [ "${clob}" == false ]; then
			num_existing_files=$(( num_existing_files + 1 ))
			continue
		elif [ ! -s "${arg}" ]; then
			continue
		else
			echo "How did you get here?"
		fi
	done

	# see if the command should be run by seeing if the requisite files exist.
	# 0=true
	# 1=false
	if [ ${num_existing_files} -lt "${num_args}" ]; then
		return 0
	else
		return 1
	fi

	# example usage
	# clobber test.nii.gz &&\
	# fslmaths input.nii.gz -mul 10 test.nii.gz
}
#default
clob=false
export -f clobber

function medianScale()
{
  local inFile=$1
  local maskFile=$2
  local outDir
  outDir="$(dirname "$inFile")"

  echo "scaling over median intensity"
  median_intensity=$(fslstats "$inFile" -k "$maskFile" -p 50)
  scaling=$(echo "scale=16; 10000/${median_intensity}" | bc)
  fslmaths "$inFile" -mul "$scaling" "$outDir"/nonfiltered_smooth_data_intnorm.nii.gz
}
export -f medianScale

###### FEAT registration correction ########################################

function feat_regFix()
{
  echo "...Fixing FEAT registration QC images."

  # http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FEAT/FAQ
  # ss: "How can I insert a custom registration into a FEAT analysis?"

  regDir="$preprocDir"/reg
  mkdir -p "$regDir"
  # Remove all FEAT files (after backup), repopulate with proper files
  cp -r "$regDir" "$preprocDir"/regORIG
  rm -f "$regDir"/*

  # Copy over appropriate files from previous processing
  # T1 (highres)
  fslmaths "$t1Data" "$regDir"/highres.nii.gz
  t1toMNI=$(find "$(dirname "$t1Data")"/T1forWarp -type f -name "T1_brain_to_MNI152.nii.gz")
  fslmaths "$t1toMNI" "$regDir"/highres2standard.nii.gz

  # EPI (example_func)
  fslmaths "$epiData" "$regDir"/example_func.nii.gz
  epitoT1=$(< "$indir"/rsParams grep "EPItoT1=" | tail -1 | awk -F"=" '{print $2}')
  fslmaths "$epitoT1" "$regDir"/example_func2highres.nii.gz
  epitoMNI=$(< "$indir"/rsParams grep "EPItoMNI=" | tail -1 | awk -F"=" '{print $2}')
  fslmaths "$epitoMNI" "$regDir"/example_func2standard.nii.gz

  # MNI (standard)
  fslmaths "$FSLDIR"/data/standard/avg152T1_brain.nii.gz "$regDir"/standard.nii.gz

  # Transforms
  # EPItoT1/T1toEPI (Check for presence of FieldMap Correction)
  epiWarpDirtmp=$(< "$indir"/rsParams grep "EPItoT1Warp=" | tail -1 | awk -F"=" '{print $2}')
  epiWarpDir=$(dirname "$epiWarpDirtmp")

  if [[ $fieldMapFlag == 1 ]]; then
    # Copy the EPItoT1 warp file
    cp  "$epiWarpDir"/EPItoT1_warp.nii.gz "$regDir"/example_func2highres_warp.nii.gz
  else
    # Only copy the affine .mat files
    cp "$epiWarpDir"/EPItoT1_init.mat "$regDir"/example_func2initial_highres.mat
    cp "$epiWarpDir"/EPItoT1.mat "$regDir"/example_func2highres.mat
  fi

  # T1toMNI
  T1WarpDir="$(dirname "$t1Data")"/T1forWarp

  cp "$T1WarpDir"/T1_to_MNIaff.mat "$regDir"/highres2standard.mat
  cp "$T1WarpDir"/coef_T1_to_MNI152.nii.gz "$regDir"/highres2standard_warp.nii.gz

  # EPItoMNI
  cp "$epiWarpDir"/EPItoMNI_warp.nii.gz "$regDir"/example_func2standard_warp.nii.gz

  # MNItoT1
  cp "$T1WarpDir"/MNItoT1_warp.nii.gz "$regDir"/standard2highres_warp.nii.gz

  # Forgoing "updatefeatreg" and just recreating the appropriate pics with slicer/pngappend
  cd "$regDir" || exit

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
}
export -f feat_regFix

###### Gaussian Smoothing ########################################
function smooth {
  echo "...Guassian Smoothing"


  # Guassian smooth:  mm to sigma
  # https://www.jiscmail.ac.uk/cgi-bin/webadmin?A2=FSL;d7249c17.1301
  # sigma=mm/sqrt(8*ln(2))
  smoothSigma=$(echo "$smooth" | awk '{print ($1/(sqrt(8*log(2))))}')

  # Determine 50% intensity of data, thresholded at 75% (for all non-zero voxels)
  epiThreshVal=$(fslstats "$epiData" -P 50 | awk '{print ($1*0.75)}')

  # Create a time-series mean of $epiData
  fslmaths "$epiData" -Tmean "$preprocDir"/mean_func.nii.gz

  # Binarize mean image and make a mask
  fslmaths "$preprocDir"/mean_func.nii.gz -bin "$preprocDir"/mask.nii.gz -odt char

  # SUSAN for smoothing
  susan "$epiData" "$epiThreshVal" "$smoothSigma" 3 1 1 "$preprocDir"/mean_func.nii.gz "$epiThreshVal" "$preprocDir"/nonfiltered_smooth.nii.gz

  # Threshold output by mean mask, rename original data
  fslmaths "$preprocDir"/nonfiltered_smooth.nii.gz -mul "$preprocDir"/mask.nii.gz "$preprocDir"/nonfiltered_smooth_data.nii.gz
  mv "$preprocDir"/nonfiltered_smooth.nii.gz "$preprocDir"/nonfiltered_smooth_data_orig.nii.gz

  # Echo out output to rsParams file
  echo "epiNonfilt=$preprocDir/nonfiltered_smooth_data.nii.gz" >> "$indir"/rsParams
}

###### ICA_AROMA ########################################
function run_aroma() {
  local inFile=$1

  clobber "$indir"/ica_aroma/denoised_func_data_nonaggr.nii.gz &&\
  ICA_AROMA.py -i "$inFile" -o "$indir"/ica_aroma -mc "$indir"/mcImg.par -w "$(find "${indir}"/EPItoT1* -type f -name "EPItoMNI_warp.nii.gz")"

  if [ ! -e "$indir"/ica_aroma/denoised_func_data_nonaggr.nii.gz ]; then
    >&2 echo "$indir/ica_aroma/denoised_func_data_nonaggr.nii.gz not found! exiting"
    exit 1
  fi

  # track ratio of noise components/total components

  clobber "$indir"/ica_aroma/noise_ratio.csv &&\
  numTotComps=$(tail -n +2 "$indir"/ica_aroma/classification_overview.txt | wc -l) &&\
  numNoiseComps=$(sed 's/[^,]//g' "$indir"/ica_aroma/classified_motion_ICs.txt | wc -c)
  ratio=$(echo "scale=2; ${numNoiseComps}/${numTotComps}" | bc) &&\
  echo "$indir,$numNoiseComps,$numTotComps,$ratio" >> "$indir"/ica_aroma/noise_ratio.csv
}

###############################################################################

##########
## MAIN ##
##########

# Parse Command line arguments
if [ $# -lt 4 ] ; then Usage; exit 0; fi
while [ $# -ge 1 ] ; do
    iarg=$(get_opt1 $1);
    case "$iarg"
	in
	--epi)
	    epiData=$(get_arg1 $1);
      export epiData;
      indir=$(dirname "$epiData")
      export indir
	    shift;;
	--t1brain)
	    t1Data=$(get_arg1 $1);
      export t1SkullData;
	    shift;;
  --tr)
	    tr=$(get_arg1 $1);
      export tr;
	    shift;;
  --te)
	    te=$(get_arg1 $1);
      export te;
	    shift;;
  --smooth)
	    smooth=$(get_arg1 $1);
      export smooth;
	    shift;;
  --usefmap)
      fieldMapFlag=1;
      export fieldMapFlag;
	    shift;;
  --aroma)
      aromaFlag=1;
      export aromaFlag;
      if [ "$(command -v ICA_AROMA.py)" == "" ]; then
        echo "ICA_AROMA is either not downloaded or not defined in your path, exiting script"
        exit 1
      fi
      shift;;
  -c)
      clob=true;
      export clob;
      echo "-c" >> "$logDir"/rsParams_log
      rm -rf "${indir:?}"/preproc
      rm -rf "${indir:?}"/ica_aroma;
      shift;;
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


# A few default parameters (if input not specified, these parameters are assumed)
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


preprocDir="$indir"/preproc
export preprocDir
mkdir -p "$preprocDir"

# Echo out all input parameters into a log
logDir=$(dirname "$epiData")
{
  echo "------------------------------------" 
  echo "-E $epiData" 
  echo "-A $t1Data" 
  echo "-t $tr" 
  echo "-T $te" 
  echo "-s $smooth" 
  if [[ $fieldMapFlag == 1 ]]; then
    echo "-f" 
  fi
  date 
  echo "" 
  echo "" 
} >> "$logDir"/rsParams_log



echo "Running $0 ..."

cd "$indir" || exit

# spatial smoothing
clobber "$preprocDir"/nonfiltered_smooth_data.nii.gz &&\
smooth

# set up registration
feat_regFix "$preprocDir"

# median scaling (for ICA_AROMA)
clobber "$preprocDir"/nonfiltered_smooth_data_intnorm.nii.gz &&\
medianScale "$preprocDir"/nonfiltered_smooth_data.nii.gz "$indir"/mcImgMean_mask.nii.gz

# ICA-AROMA
if [ ${aromaFlag} == 1 ]; then
  clobber "$indir"/ica_aroma/denoised_func_data_nonaggr.nii.gz &&\
  run_aroma "$preprocDir"/nonfiltered_smooth_data_intnorm.nii.gz
fi

cd "$indir" || exit


# Log results to HTML file
{
  echo "<hr><h2>Preprocessing Results</h2>" 
  echo "<b>Spatial Filter Size (mm)</b>: $smooth<br>" 
  echo "<b>TR (s): $tr</b><br>" 
  echo "<b>TE (ms): $te</b><br>" 
  echo "<b>Number of Time Points</b>: $numtimepoint<br>" 
} >> "$indir"/analysisResults.html

echo "$0 Complete"
echo ""
echo ""
