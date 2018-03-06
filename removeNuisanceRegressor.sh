#!/bin/bash

##################################################################################################################
# Removal of Nuisance Signal, Filtering
#     1. Filtering
#       a. High or Lowpass filtering via AFNI's 3dBandpass
#       b. If High/Lowpass set to 0, the 0 and Nyquist Frequencies will still be removed
#     2. Removal or Nuisance signal (FEAT)
#       a. ROI based (e.g. wmroi, global, latvent)
#       b. Motion Parameters (mclfirt/3dvolreg)
##################################################################################################################

analysis=nuisancereg
analysis2=nuisanceregFix
nuisancefeat=nuisancereg.feat
preprocfeat=preproc.feat
melodicfeat=melodic.ica
fsf=${analysis}.fsf
fsf2=${analysis2}.fsf

##Check of all ROIs (from ROIs directory), that can be used for nuisance regression
scriptPath=$(perl -e 'use Cwd "abs_path";print abs_path(shift)' "$0")
scriptDir=$(dirname "$scriptPath")

SGE_ROOT='';export SGE_ROOT

function Usage {
  echo "Usage: removeNuisanceRegressor.sh --epi=restingStateImage --t1brain=T1Image --nuisanceMode=nuisanceMode --tr=tr --te=te --hp=highpass --lp=lowpass -c"
  echo "            -OR-"
  echo "Usage: removeNuisanceRegressor.sh -E restingStateImage -A T1Image -n nuisanceROI -t tr -T te -H highpass -L lowpass -M -c"
  echo ""
  echo " where"
  echo "  -epi preprocessed Resting State file"
  echo "     *If using 'Classic' mode (no ICA Denoising), specify 'nonfiltered_func_data.nii.gz' from preproc.feat directory"
  echo "     *If using ICA_AROMA, use denoised_func_data_nonaggr.nii.gz from ica_aroma directory"
  echo "  --t1brain T1 file (skull-stripped)"
  echo "     *T1 should be from output of dataPrep script, EPI shoule be from output of ICA_denoise script"
  echo "  --nuisanceList list containing paths to nuisance ROIs"
  echo "      compcor = ICA-AROMA + WM/CSF regressors derived from FAST segmentation"
  echo "      classic = global + WM roi + CSF roi"
  echo "  --lp lowpass filter frequency (Hz) (e.g. 0.08 Hz (2.5 sigma))"
  echo "  --hp highpass filter frequency (Hz) (e.g. 0.008 Hz (25.5 sigma / 120 s))"
  echo "    *If low/highpass filters are unset (or purposely set to both be '0'), the 0 and Nyquist frequencies will"
  echo "     still be removed (allpass filter)"
  echo "  --tr TR time (seconds)"
  echo "  --te TE (milliseconds) (default to 30 ms)"
  echo "  --aroma flag if using ICA_AROMA denoised data as input to nuisancereg"
  echo "  --compcor flag if using CompCor nuisancereg"
  echo "  -c clobber/overwrite previous results"
  echo ""
  echo "Existing nuisance ROIs:"
  echo "$knownNuisanceRois"
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

#Overwrites material or skips
function clobber()
{
	#Tracking Variables
	local -i num_existing_files=0
	local -i num_args=$#

	#Tally all existing outputs
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

	#see if the command should be run by seeing if the requisite files exist.
	#0=true
	#1=false
	if [ "${num_existing_files}" -lt "${num_args}" ]; then
		return 0
	else
		return 1
	fi

	#example usage
	#clobber test.nii.gz &&\
	#fslmaths input.nii.gz -mul 10 test.nii.gz
}
#default
clob=false
export -f clobber

function bandpass()
{
	local inData=$1
	local mask=$2
  local inDir
  inDir=$(dirname ${inData})

  # defaults
  if [ "$hp" == "" ]; then
    hp=.008
  fi

  if [ "$lp" == "" ]; then
    lp=.08
  fi

  clobber ${inDir}/"$(basename "${inData%%.nii*}")"_bp.nii.gz &&\
  rm -rf ${inDir}/*_mean.nii.gz 2> /dev/null &&\
  rm -rf ${inDir}/tmp_bp.nii.gz 2> /dev/null &&\
	3dBandpass -prefix $inDir/tmp_bp.nii.gz -mask ${mask} ${hp} ${lp} ${inData} &&\
	3dTstat -mean -prefix $inDir/orig_mean.nii.gz ${inData} &&\
	3dTstat -mean -prefix $inDir/bp_mean.nii.gz $inDir/tmp_bp.nii.gz &&\
	3dcalc -a $inDir/tmp_bp.nii.gz -b $inDir/orig_mean.nii.gz -c $inDir/bp_mean.nii.gz -expr "a+b-c" -prefix ${inDir}/"$(basename "${inData%%.nii*}")"_bp.nii.gz
  epiDataFilt=${inDir}/"$(basename "${inData%%.nii*}")"_bp.nii.gz
  export epiDataFilt
}
export -f bandpass

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
    -h)
        Usage;
        exit 0;;
    --epi)
  	    epiData=`get_arg1 $1`;
        export epiData;
        if [ "$epiData" == "" ]; then
          echo "Error: The restingStateImage (-E) is a required option"
          exit 1
        fi
  	    shift;;
  	--t1brain)
  	    t1Data=`get_imarg1 $1`;
        export t1Data;
        if [ "$t1Data" == "" ]; then
          echo "Error: The T1 image (-A) is a required option"
          exit 1
        fi
  	    shift;;
    --nuisanceList)
      nuisanceList=( "$(cat "$(get_arg1 $1)")" );
      nuisanceInFile=$(get_arg1 $1);
      shift;;
    --lp)
      lowpassArg=$(get_arg1 $1);
      export lowpassArg;
      shift;;
    --hp)
      highpassArg=$(get_arg1 $1);
      export highpassArg;
      shift;;
    --tr)
      tr=$(get_arg1 $1);
      export tr;
      shift;;
    --te)
      te=$(get_arg1 $1);
      export te;
      shift;;
    --compcor)
      compcorFlag=1;
      export compcorFlag;
      shift;;
    --aroma)
      aromaFlag=1;
      export aromaFlag;
      shift;;
    -c)
      clob=true;
      export clob;
      rm -- *_norm.png run_normseedregressors.m;
      rm -rf nuisancereg.*;
      rm -rf tsregressorslp;
      shift;;
    ?)
      echo "ERROR: Invalid option"
      printCommandLine
      ;;
     esac
done





#Check for required input

if [ "$FSLDIR" == "" ]; then
  echo "Error: The Environmental variable FSLDIR must be set"
  exit 1
fi


if [[ "${nuisanceList[*]}" == "" ]]; then
  echo "Error: At least one Nuisance ROI must be specified using the -n options"
  exit 1
fi




# A few default parameters (if input not specified, these parameters are assumed)
if [[ ${overwriteFlag} == "" ]]; then
  overwriteFlag=0
fi

if [[ ${tr} == "" ]]; then
  tr=2
fi

if [[ ${te} == "" ]]; then
  te=30
fi

if [[ "${lowpassArg}" == "" ]]; then
  lowpassArg=0
fi

if [[ "${highpassArg}" == "" ]]; then
  highpassArg=0
fi



# Vanilla settings for filtering: L=.08, H=.008

# Source input (~func) directory
indirTmp=$(dirname "$epiData")
indir=$(dirname "$indirTmp")
preprocfeat=$(echo "$indirTmp" | awk -F"/" '{print $NF}')
logDir=$indir

# Set flag depending on whether Melodic was run or not (to determine which directory to pull "reg" files from)
# "Classic" processing = nonfiltered_smooth_data.nii.gz ('nonfiltered')
# Melodic processing = denoised_func_data.nii.gz ('denoised')
epiBase=$(basename "$epiData" | awk -F"_" '{print $1}')
if [[ $epiBase == "denoised" ]]; then
  melFlag=1
fi

# If new nuisance regressors were added, echo them out to the rsParams file (only if they don't already exist in the file)
# Making a *strong* assumption that any nuisanceROI lists added after initial processing won't reuse the first ROI (e.g. pccrsp)
nuisanceTestBase=$(grep "nuisanceROI=" "$logDir"/rsParams | awk -F"=" '{print $2}' | awk -F"-n " '{for (i=2; i<=NF; i++) print $i}')
nuisanceTest=$(echo "$nuisanceTestBase" | awk '{print $1}')
roiTest=$(echo "${nuisanceList[@]}" | awk '{print $1}')

for i in "${nuisanceList[@]}"
do
  nuisanceROI="$nuisanceROI -n $i"
done

if [[ "$nuisanceTest" != "$roiTest" ]]; then
  echo "nuisanceROI=$nuisanceROI" >> "$logDir"/rsParams
fi

# Echo out nuisance ROIs to a text file in input directory.

if [ -e "$indir"/nuisance_rois.txt ]; then
  rm "$indir"/nuisance_rois.txt
fi

for i in "${nuisanceList[@]}"
do
  echo "$i" >> "$indir"/nuisance_rois.txt
done

nuisanceroiList=$indir/nuisance_rois.txt
nuisanceCount=$(awk 'END {print NR}' "$nuisanceroiList")

# Echo out all input parameters into a log
{ echo "$scriptPath"; \
echo "------------------------------------"; \
echo "-E $epiData"; \
echo "-A $t1Data"; } >> "$logDir"/rsParams_log
if [[ $nuisanceInd == 1 ]]; then
  echo "$nuisanceROI" >> "$logDir"/rsParams_log
else
  echo "-N $nuisanceInFile" >> "$logDir"/rsParams_log
fi
{ echo "-L $lowpassArg"; \
echo "-H $highpassArg"; \
echo "-t $tr"; \
echo "-T $te"; } >> "$logDir"/rsParams_log
if [[ $overwriteFlag == 1 ]]; then
  echo "-c" >> "$logDir"/rsParams_log
fi
date >> "$logDir"/rsParams_log
echo -e "\\n\\n" >> "$logDir"/rsParams_log


# If user defines overwrite, note in rsParams file
if [[ $overwriteFlag == 1 ]]; then
  echo "_removeNuisanceRegressor_clobber" >> "$logDir"/rsParams
fi

echo "Running $0 ..."

roiList=("${nuisanceList[@]}")

cd "$indir"/"${preprocfeat}" || exit
mkdir -p rois

clobber ${indir}/"$(basename "${epiData%%.nii*}")"_bp.nii.gz &&\
bandpass ${epiData} $indir/mcImgMean_mask.nii.gz .008 .08
# bandpassed data is exported to variable $epiDataFilt

# # Check to see if Melodic highpass filtering had already been run.  Don't want to highpass filter the EPI data twice
# if [[ $highpassMelodic == 1 ]]; then
#   # ONLY lowpass (or allpass) filtering possible for EPI
#
#   #### Bandpass EPI Data With AFNI Tools, before nuisance regression ############
#   # Vanilla settings for filtering: L=.08, H=.008 (2.5 sigma to 25.5 sigma / 120 s)
#   # Since filtereing was removed from previous steps, a new file:
#   # If filtering is set, filtered_func_data must be created
#   # If filtering is not set, nonfiltered_func_data must be scaled by 1000
#   echo "...Bandpass Filtering EPI data"
#
#   if [ $lowpassArg == 0 ]; then
#     # Allpass filter (only 0 and Nyquist frequencies are removed)
#     # Scale data by 1000
#
#     3dBandpass -prefix bandpass.nii.gz 0 99999 "${epiData}"
#     mv bandpass.nii.gz filtered_func_data.nii.gz
#     fslmaths "$indir"/mcImgMean_mask.nii.gz -mul 1000 mask1000.nii.gz -odt float
#     fslmaths filtered_func_data.nii.gz -add mask1000 filtered_func_data.nii.gz -odt float
#     epiDataFilt=$indir/${preprocfeat}/filtered_func_data.nii.gz
#
#     # Log filtered file
#     { echo "lowpassFilt=$lowpassArg"; \
#     echo "_allpassFilt"; \
#     echo "epiDataFilt=$epiDataFilt"; } >> "$logDir"/rsParams
#   else
#     # Filtering and scaling (lowpass)
#     # Scale data by 1000
#
#     3dBandpass -prefix bandpass.nii.gz 0 $lowpassArg "${epiData}"
#     mv bandpass.nii.gz filtered_func_data.nii.gz
#     fslmaths "$indir"/mcImgMean_mask.nii.gz -mul 1000 mask1000.nii.gz -odt float
#     fslmaths filtered_func_data.nii.gz -add mask1000 filtered_func_data.nii.gz -odt float
#     epiDataFilt=$indir/${preprocfeat}/filtered_func_data.nii.gz
#
#     # Log filtered file
#     echo "lowpassFilt=$lowpassArg" >> "$logDir"/rsParams
#     echo "epiDataFilt=$epiDataFilt" >> "$logDir"/rsParams
#   fi
#
# else
#   # Highpass filtering an option for EPI data
#
#   #### Bandpass EPI Data With AFNI Tools, before nuisance regression ############
#   # Vanilla settings for filtering: L=.08, H=.008 (2.5 sigma to 25.5 sigma / 120 s)
#   # Since filtereing was removed from previous steps, a new file:
#   # If filtering is set, filtered_func_data must be created
#   # If filtering is not set, nonfiltered_func_data must be scaled by 1000
#   echo "...Bandpass Filtering EPI data"
#
#   if [ $lowpassArg == 0 ] && [ $highpassArg == 0 ]; then
#     # Allpass filter (only 0 and Nyquist frequencies are removed)
#     # Scale data by 1000
#
#     3dBandpass -prefix bandpass.nii.gz 0 99999 "${epiData}"
#     mv bandpass.nii.gz filtered_func_data.nii.gz
#     fslmaths "$indir"/mcImgMean_mask.nii.gz -mul 1000 mask1000.nii.gz -odt float
#     fslmaths filtered_func_data.nii.gz -add mask1000 filtered_func_data.nii.gz -odt float
#     epiDataFilt=$indir/${preprocfeat}/filtered_func_data.nii.gz
#
#    # Log filtered file
#     { echo "lowpassFilt=$lowpassArg"; \
#     echo "highpassFilt=$highpassArg"; \
#     echo "_allpassFilt"; \
#     echo "epiDataFilt=$epiDataFilt"; } >> "$logDir"/rsParams
#   else
#     # Filtering and scaling (either lowpass, highpass or both)
#     # Scale data by 1000
#
#     3dBandpass -prefix bandpass.nii.gz "$highpassArg" "$lowpassArg" "${epiData}"
#     mv bandpass.nii.gz filtered_func_data.nii.gz
#     fslmaths "$indir"/mcImgMean_mask.nii.gz -mul 1000 mask1000.nii.gz -odt float
#     fslmaths filtered_func_data.nii.gz -add mask1000 filtered_func_data.nii.gz -odt float
#     epiDataFilt=$indir/${preprocfeat}/filtered_func_data.nii.gz
#
#     # Log filtered file
#     { echo "lowpassFilt=$lowpassArg"; \
#     echo "highpassFilt=$highpassArg"; \
#     echo "epiDataFilt=$epiDataFilt"; } >> "$logDir"/rsParams
#   fi
# fi
#
# #################################


#### Nuisance ROI mapping ############

for roi in "${roiList[@]}"; do
  roiName=$(basename ${roi} .nii.gz)

  #check if roi is in native space
  if [[ "$(fslinfo ${roi} | grep ^dim1 | awk '{print $2}')" -eq 91 ]]; then
    # roi is in MNI space
    clobber rois/"${roiName}"_native.nii.gz &&\
    MNItoEPIwarp=$(grep "MNItoEPIWarp=" "$logDir"/rsParams | tail -1 | awk -F"=" '{print $2}') &&\
    applywarp --ref="$indir"/mcImgMean_stripped.nii.gz --in=${roi} --out=rois/"${roiName}"_native.nii.gz --warp="$MNItoEPIwarp" --datatype=float

  elif [[ "$(fslinfo ${roi} | grep ^dim1 | awk '{print $2}')" -eq "$(fslinfo ${epiDataFilt} | grep ^dim1 | awk '{print $2}')" ]]; then
    # roi is in native space
    clobber rois/"${roiName}"_native.nii.gz &&\
    cp ${roi} rois/"${roiName}"_native.nii.gz

  else
    echo "dimensions of roi not in MNI or EPI space"
    exit 1
  fi
  # check if needs binarize
  if [[ "$(fslstats rois/"${roiName}"_native.nii.gz)" -ne 1 ]]; then
    fslmaths rois/"${roiName}"_native.nii.gz -thr 0.5 -bin rois/"${roiName}"_native.nii.gz
  fi

  if [[ "${compcorFlag}" -eq 1 ]]; then
    fslmeants -i "$epiDataFilt" -o rois/mean_"${roiName}"_ts.txt -m rois/"${roiName}"_native.nii.gz --eig --order=5

    # separate 5 eigenvectors into single files
    for i in {1..5}; do
        awk -v var="$i" '{print $var}' rois/mean_${roiName}_ts.txt > rois/mean_${roiName}_${i}_ts.txt
    done

  else
    clobber rois/mean_"${roiName}"_ts.txt &&\
    fslmeants -i "$epiDataFilt" -o rois/mean_"${roiName}"_ts.txt -m rois/"${roiName}"_native.nii.gz
  fi
done

# echo "...Warping Nuisance ROIs to EPI space"
#
# for roi in "${roiList[@]}"
# do
#   echo "......Mapping nuisance regressor $roi"
#
#   # Need to use warp from MNI to EPI from qualityCheck
#   MNItoEPIwarp=$(grep "MNItoEPIWarp=" "$logDir"/rsParams | tail -1 | awk -F"=" '{print $2}')
#   applywarp --ref="$indir"/mcImgMean_stripped.nii.gz --in="${scriptDir}"/ROIs/"${roi}".nii.gz --out=rois/"${roi}"_native.nii.gz --warp="$MNItoEPIwarp" --datatype=float
#   fslmaths rois/"${roi}"_native.nii.gz -thr 0.5 rois/"${roi}"_native.nii.gz
#   fslmaths rois/"${roi}"_native.nii.gz -bin rois/"${roi}"_native.nii.gz
#   fslmeants -i "$epiDataFilt" -o rois/mean_"${roi}"_ts.txt -m rois/"${roi}"_native.nii.gz
# done
#
# #################################


#### FEAT setup ############
echo "... FEAT setup"

cd "$indir" || exit

# Set a few variables from data
# epi_reg peDir setup (e.g. -y) is backwards from FEAT peDir (e.g. y-)
peDirBase=$(grep "peDir=" "$logDir"/rsParams | tail -1 | awk -F"=" '{print $2}')
if [[ $peDirBase == "" ]]; then
  peDirNEW="y-"
else
  peDirTmp1=$(echo "$peDirBase" | cut -c1)
  peDirTmp2=$(echo "$peDirBase" | cut -c2)
  if [[ "$peDirTmp1" == "-" ]]; then
    peDirNEW="${peDirTmp2}${peDirTmp1}"
  else
    peDirNEW="${peDirBase}"
  fi
fi

numtimepoint=$(fslinfo "$epiDataFilt" | grep ^dim4 | awk '{print $2}')

dwellTimeBase=$(grep "epiDwell=" "$logDir"/rsParams | tail -1 | awk -F"=" '{print $2}')
if [[ $dwellTimeBase == "" ]]; then
  dwellTime=0.00056
else
  dwellTime=$dwellTimeBase
fi

epiVoxTot=$(fslstats "${epiDataFilt}" -v | awk '{print $1}')

sed -e "s|SUBJECTPATH|${indir}|g" \
-e "s|SUBJECTEPIPATH|${epiDataFilt}|g" \
-e "s|VOXTOT|${epiVoxTot}|g" \
-e "s|SUBJECTT1PATH|${t1Data}|g" \
-e "s|SCANTE|${te}|g" \
-e "s|SUBJECTVOLS|${numtimepoint}|g" \
-e "s|SUBJECTTR|${tr}|g" \
-e "s|EPIDWELL|${dwellTime}|g" \
-e "s|PEDIR|${peDirNEW}|g" \
-e "s|FSLDIR|${FSLDIR}|g" "$scriptDir"/dummy_nuisance_5.0.10.fsf > "${indir}"/"${fsf}"

#################################



#### Calculate Nuisance Regressor time-series ############

if [[ "${compcorFlag}" -eq 1 ]]; then

  # reassign nuisanceList array with eigenvectors
  > $indir/nuisance_rois.txt
  nuisanceList=( "$(for i in {1..5}; do for roi in "${roiList[@]}"; do echo "$(basename ${roi} .nii.gz)"_${i};done;done)" )


  for i in $nuisanceList; do
    echo $i >> $indir/nuisance_rois.txt
  done

  nuisanceroiList=$indir/nuisance_rois.txt
  nuisanceCount=$(cat $nuisanceroiList | awk 'END {print NR}')
fi

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
nuisanceRoiFile=['${nuisanceroiList}'];
fid=fopen(nuisanceRoiFile);
roiList_tmp=textscan(fid,'%s');
fclose(fid);
roiList=cell(${nuisanceCount},1);

for i=1:${nuisanceCount}
roiList{i,1}=(roiList_tmp{1,1}(i));
end


featdir='${preprocfeat}';
includemotion=1;
normseedregressors('${indir}',roiList,featdir,includemotion)
quit;
EOF

# Run script using Matlab or Octave
haveMatlab=$(which matlab)
if [ "$haveMatlab" == "" ]; then
  octave --no-window-system "$indir"/"$filename"
else
  matlab -nodisplay -r "run $indir/$filename"
fi


echo "<hr><h2>Nuisance Regressors</h2>" >> "$indir"/analysisResults.html

#################################



#### Bandpass Motion Regressors ######

echo "...Bandpass filtering Motion Regressors"


if [ $lowpassArg != 0 ] || [ $highpassArg != 0 ]; then
  # Filtering ONLY if low/highpass don't both = 0
  mclist='1 2 3 4 5 6'
  for mc in ${mclist}
  do
      cp "${indir}"/tsregressorslp/mc"${mc}"_normalized.txt "${indir}"/tsregressorslp/mc"${mc}"_normalized.1D
      1dBandpass "$highpassArg" "$lowpassArg" "${indir}"/tsregressorslp/mc"${mc}"_normalized.1D > "${indir}"/tsregressorslp/mc"${mc}"_normalized_filt.1D
      cat "${indir}"/tsregressorslp/mc"${mc}"_normalized_filt.1D > "${indir}"/tsregressorslp/mc"${mc}"_normalized.txt
  done
else
  # Passband filter
  mclist='1 2 3 4 5 6'
  for mc in ${mclist}
  do
      cp "${indir}"/tsregressorslp/mc"${mc}"_normalized.txt "${indir}"/tsregressorslp/mc"${mc}"_normalized.1D
      1dBandpass 0 99999 "${indir}"/tsregressorslp/mc"${mc}"_normalized.1D > "${indir}"/tsregressorslp/mc"${mc}"_normalized_filt.1D
      cat "${indir}"/tsregressorslp/mc"${mc}"_normalized_filt.1D > "${indir}"/tsregressorslp/mc"${mc}"_normalized.txt
  done
fi

#################################



#### Plotting Regressor time courses ######

echo "...Plotting Regressor time series"

for roi in "${nuisanceList[@]}"
do
  fsl_tsplot -i "$indir"/tsregressorslp/"${roi}"_normalized_ts.txt -t "${roi} Time Series" -u 1 --start=1 -x 'Time Points (TR)' -w 800 -h 300 -o "$indir"/"${roi}"_norm.png
  echo "<br><br><img src=\"$indir/${roi}_norm.png\" alt=\"$roi nuisance regressor\"><br>" >> "$indir"/analysisResults.html
done

#################################



#### FEAT Regression ######

# Run feat
echo "...Running FEAT (nuisancereg)"
feat "${indir}"/"${fsf}"
#################################



###### FEAT registration correction ########################################

echo "...Fixing FEAT registration QC images."

# http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FEAT/FAQ
# ss: "How can I insert a custom registration into a FEAT analysis?"

regDir=$indir/${nuisancefeat}/reg

# Remove all FEAT files (after backup), repopulate with proper files
cp -r "$regDir" "$indir"/"${nuisancefeat}"/regORIG
rm -rf "$regDir"

# Copy over appropriate reg directory from melodic.ica or preproc.feat processing
  #If Melodic was run, copy over that version of the registration, otherwise use the portion from preprocessing
if [[ $melFlag == 1 ]]; then
  # Melodic was used (-P 2)
  # Copy over "melodic" registration directory
  cp -r "$indir"/"${melodicfeat}"/reg "$indir"/"${nuisancefeat}"

else
  # Melodic was not used (-P 2a)
  # Copy over "preproc" registration directory
  cp -r "$indir"/"${preprocfeat}"/reg "$indir"/"${nuisancefeat}"
fi

# Backup original design file
cp "$indir"/"${nuisancefeat}"/design.fsf "$indir"/"${nuisancefeat}"/designORIG.fsf


# Rerun FEAT to fix only post-stats portions (with no registrations)
# VOXTOT
epiVoxTot=$(fslstats "${epiDataFilt}" -v | awk '{print $1}')

# NUISANCEDIR
nuisanceDir=$indir/${nuisancefeat}

sed -e "s|SUBJECTPATH|${indir}|g" \
-e "s|VOXTOT|${epiVoxTot}|g" \
-e "s|NUISANCEDIR|${nuisanceDir}|g" \
-e "s|SCANTE|${te}|g" \
-e "s|SUBJECTVOLS|${numtimepoint}|g" \
-e "s|SUBJECTTR|${tr}|g" \
-e "s|EPIDWELL|${dwellTime}|g" \
-e "s|PEDIR|${peDirNEW}|g" \
-e "s|FSLDIR|${FSLDIR}|g" "$scriptDir"/dummy_nuisance_regFix_5.0.10.fsf > "${indir}"/"${fsf2}"

# Re-run feat
echo "...Rerunning FEAT (nuisancereg(post-stats only)0"
feat "${indir}"/"${fsf2}"

# Log output to HTML file
echo "<a href=\"$indir/${nuisancefeat}/report.html\">FSL Nuisance Regressor Results</a>" >> "$indir"/analysisResults.html

#################################



###### Post-FEAT data-scaling ########################################

cd "$indir"/"${nuisancefeat}"/stats || exit

# Backup file
echo "...Scaling data by 1000"
cp res4d.nii.gz res4d_orig.nii.gz

# For some reason, this mask isn't very good.  Use the good mask top-level
echo "...Copy Brain mask"
cp "$indir"/mcImgMean_mask.nii.gz mask.nii.gz
fslmaths mask -mul 1000 mask1000 -odt float

# normalize res4d here
echo "...Normalize Data"
fslmaths res4d -Tmean res4d_tmean
fslmaths res4d -Tstd res4d_std
fslmaths res4d -sub res4d_tmean res4d_dmean
fslmaths res4d_dmean -div res4d_std res4d_normed
fslmaths res4d_normed -add mask1000 res4d_normandscaled -odt float

# Echo out final file to rsParams file
echo "epiNorm=$indir/$nuisancefeat/stats/res4d_normandscaled.nii.gz" >> "$logDir"/rsParams

#################################




echo "$0 Complete"
echo ""
echo ""
