#!/bin/bash

##################################################################################################################
# Removal of Nuisance Signal, Filtering
#     1. Filtering
#       a. High or Lowpass filtering via AFNI's 3dBandpass
#       b. If High/Lowpass set to 0, the 0 and Nyquist Frequencies will still be removed
#     2. Removal of Nuisance signal (3dTproject)
#       a. classic: global roi + WM roi + CSF roi + 6 motion params
#       b. CompCor: WM/CSF regressors derived from FAST segmentation
##################################################################################################################

SGE_ROOT='';export SGE_ROOT

function Usage {
  echo "Usage: removeNuisanceRegressor.sh --epi=restingStateImage --t1brain=T1Image --nuisanceList=nuisanceList.txt --hp=highpass --lp=lowpass --clobber"
  echo "            -OR-"
  echo "Usage: removeNuisanceRegressor.sh --epi=restingStateImage --t1brain=T1Image --nuisanceList=nuisanceList.txt --hp=highpass --lp=lowpass --compcor --clobber"
  echo ""
  echo " where"
  echo "  --epi preprocessed Resting State file"
  echo "     *If using 'Classic' mode (no ICA Denoising), specify 'nonfiltered_func_data.nii.gz' from preproc.feat directory"
  echo "     *If using ICA_AROMA, use denoised_func_data_nonaggr.nii.gz from ica_aroma directory"
  echo "  --t1brain T1 file (skull-stripped)"
  echo "  --nuisanceList list containing paths to nuisance ROIs"
  echo "      compcor = WM/CSF regressors derived from FAST segmentation"
  echo "      classic = global + WM roi + CSF roi + 6 motion params"
  echo "  --lp lowpass filter frequency (Hz) (e.g. 0.08 Hz (2.5 sigma))"
  echo "  --hp highpass filter frequency (Hz) (e.g. 0.008 Hz (25.5 sigma / 120 s))"
  echo "    *If low/highpass filters are unset (or purposely set to both be '0'), the 0 and Nyquist frequencies will"
  echo "     still be removed (allpass filter)"
  echo "  --compcor flag if using CompCor nuisancereg"
  echo "  --clobber clobber/overwrite previous results"
  echo ""
  exit 1
}

########## FSL's arg parsing functions ###################
get_opt1() {
    arg=$(echo $1 | sed 's/=.*//')
    echo "$arg"
}

get_imarg1() {
    arg=$(get_arg1 "$1");
    arg=$("$FSLDIR"/bin/remove_ext "$arg");
    echo "$arg"
}

get_arg1() {
    if [ X"$(echo $1 | grep '=')" = X ] ; then
	echo "Option $1 requires an argument" 1>&2
	exit 1
    else
	arg=`echo $1 | sed 's/.*=//'`
	if [ X$arg = X ] ; then
	    echo "Option $1 requires an argument" 1>&2
	    exit 1
	fi
	echo "$arg"
    fi
}

function get_filename() {
  local input=$1
  file=${input##*/}
  echo "${file%%.*}"
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
# default
clob=false
export -f clobber

# ${regressors} is file containing all the regressor timeseries
# 3dTproject will demean (normalize)
function SimultBandpassNuisanceReg()
{
	local inData=$1
	local mask=$2

   # If neither lowpass or highpass is set, do an allpass filter (fbot=0 ftop=99999)
   # If ONLY highpass is set, do a highpass filter (fbot=${hp} ftop=99999)
   # If ONLY lowpass is set, do a lowpass filter (fbot=0 ftop=${hp})
   # If both lowpass and highpass are set, do a bandpass filter (fbot=${hp} ftop=${lp})
  if [[ $lp == ""  &&  $hp == "" ]]; then
    # allpass filter
    fbot=0
    ftop=99999
    hp=0
    lp=99999
    filtType=allpass
    echo "Performing an 'allpass' filter.  Removal of '0' and Nyquist only."
  elif [[ $lp == ""  &&  $hp != "" ]]; then
    # highpass filter
    fbot=${hp}
    ftop=99999
    lp=99999
    filtType=highpass
    echo "Performing a 'highpass' filter.  Frequencies below ${hp} will be filtered."
  elif [[ $lp != ""  &&  $hp == "" ]]; then
    # lowpass filter
    fbot=0
    ftop=${lp}
    hp=0
    filtType=lowpass
    echo "Performing a 'lowpass' filter.  Frequencies above ${lp} will be filtered."
  else
    # bandpass filter (low and high)
    fbot=${hp}
    ftop=${lp}
    filtType=bandpass
    echo "Performing a 'bandpass' filter.  Frequencies between ${lp} & ${hp} will be filtered."
  fi


  clobber "${outDir}"/"$(basename "${inData%%.nii*}")"_bp_res4d.nii.gz &&\
  rm -rf "${outDir}"/*_mean.nii.gz 2> /dev/null &&\
  rm -rf "${outDir}"/tmp_bp* 2> /dev/null &&\
	3dTproject -input "${inData}" -prefix "$outDir"/tmp_bp.nii.gz -mask "${mask}" -bandpass "${fbot}" "${ftop}" -ort "${regressorsFile}" -verb &&\
  # add mean back in
	3dTstat -mean -prefix "$outDir"/orig_mean.nii.gz "${inData}" &&\
	3dTstat -mean -prefix "$outDir"/bp_mean.nii.gz "$outDir"/tmp_bp.nii.gz &&\
	3dcalc -a "$outDir"/tmp_bp.nii.gz -b "$outDir"/orig_mean.nii.gz -c "$outDir"/bp_mean.nii.gz -expr "a+b-c" -prefix "${outDir}"/"$(basename "${inData%%.nii*}")"_bp_res4d.nii.gz

  {
    echo "lowpassFilt=$ftop"
    echo "highpassFilt=$fbot"
    echo "_${filtType}"
  } >> "$logDir"/rsParams
}
export -f SimultBandpassNuisanceReg

###############################################################################

##########
## MAIN ##
##########


# Parse Command line arguments

if [ $# -lt 4 ] ; then Usage; exit 0; fi
while [ $# -ge 1 ] ; do
    iarg=$(get_opt1 "$1");
    case "$iarg"
	in
    -h)
        Usage;
        exit 0;;
    --epi)
  	    epiData=$(get_arg1 "$1");
        export epiData;
        if [ "$epiData" == "" ]; then
          echo "Error: The restingStateImage (-E) is a required option"
          exit 1
        fi
  	    shift;;
  	--t1brain)
  	    t1Data=$(get_arg1 "$1");
        export t1Data;
        if [ "$t1Data" == "" ]; then
          echo "Error: The T1 image is a required option"
          exit 1
        fi
  	    shift;;
    --nuisanceList)
      nuisanceInFile=$(get_arg1 "$1");
      if [ ! -e "$nuisanceInFile" ]; then
        echo "Error: The nuisanceList file is a required option"
        exit 1
      fi
      declare -a nuisanceList=( "$(cat "${nuisanceInFile}")" );
      shift;;
    --lp)
      lp=$(get_arg1 "$1");
      export lp;
      shift;;
    --hp)
      hp=$(get_arg1 "$1");
      export hp;
      shift;;
    --compcor)
      compcorFlag=1;
      export compcorFlag;
      shift;;
    --clobber)
      clob=true;
      export clob;
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

# Source input (~func) directory
indir=$(dirname "${epiData}")
preproc="${indir%/*}"/preproc
logDir=$(dirname "${preproc}")
rawEpiDir=$(dirname "${preproc}")

if [[ "${compcorFlag}" = 1 ]]; then
  outDir=${rawEpiDir}/nuisanceRegression/compcor
else
  outDir=${rawEpiDir}/nuisanceRegression/classic
fi

mkdir -p "${outDir}"/rois
cd "${outDir}"

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

if [ -e "$outDir"/nuisance_rois.txt ]; then
  rm "$outDir"/nuisance_rois.txt
fi

for i in "${nuisanceList[@]}"
do
  echo "$i" >> "$outDir"/nuisance_rois.txt
done


# Echo out all input parameters into a log
{
echo "------------------------------------"
echo "-E $epiData"
echo "-A $t1Data" 
echo "-N $nuisanceInFile" 
echo "-L $lp"
echo "-H $hp"
} >> "$logDir"/rsParams_log

if [[ $overwriteFlag == 1 ]]; then
  echo "-c" >> "$logDir"/rsParams_log
fi
{
date >> "$logDir"/rsParams_log
echo -e "\\n\\n" 
} >> "$logDir"/rsParams_log


# If user defines overwrite, note in rsParams file
if [[ $overwriteFlag == 1 ]]; then
  echo "_removeNuisanceRegressor_clobber" >> "$logDir"/rsParams
fi

echo "Running $0 ..."

#################################
#### Nuisance ROI mapping ############
for roi in $(cat "$nuisanceInFile")
do
  roiName="$(get_filename "${roi}")"

  #check if roi is in native space
  if [[ "$(fslinfo "${roi}" | grep ^dim1 | awk '{print $2}')" == 91 ]]; then
    echo "${roi} is in MNI space"
    clobber "$outDir"/rois/"${roiName}"_native.nii.gz &&\
    MNItoEPIwarp=$(grep "MNItoEPIWarp=" "$logDir"/rsParams | tail -1 | awk -F"=" '{print $2}') &&\
    applywarp --ref="$rawEpiDir"/mcImgMean_stripped.nii.gz --in="${roi}" --out="$outDir"/roi/"${roiName}"_native.nii.gz --warp="$MNItoEPIwarp" --datatype=float

  elif [[ "$(fslinfo "${roi}" | grep ^dim1 | awk '{print $2}')" == "$(fslinfo "${epiData}" | grep ^dim1 | awk '{print $2}')" ]]; then
    echo "${roi} is in native space"
    clobber "$outDir"/rois/"${roiName}"_native.nii.gz &&\
    cp "${roi}" "$outDir"/rois/"${roiName}"_native.nii.gz

  else
    echo "dimensions of $roi not in MNI or EPI space"
    exit 1
  fi
  # check if needs binarize
  if [[ $(printf %.0f $(fslstats "$outDir"/rois/"${roiName}"_native.nii.gz -M)) -ne 1 ]]; then
    fslmaths "$outDir"/rois/"${roiName}"_native.nii.gz -thr 0.5 -bin "$outDir"/rois/"${roiName}"_native.nii.gz
  fi

  # extract regressor timeseries from unfiltered epi
  if [[ "${compcorFlag}" -eq 1 ]]; then
    clobber "$outDir"/rois/mean_"${roiName}"_ts.txt &&\
    echo "extracting timeseries for $roiName" &&\
    fslmeants -i "$epiData" -o "$outDir"/rois/mean_"${roiName}"_ts.txt -m "$outDir"/rois/"${roiName}"_native.nii.gz --eig --order=5

  else
    clobber "$outDir"/rois/mean_"${roiName}"_ts.txt &&\
    fslmeants -i "$epiData" -o "$outDir"/rois/mean_"${roiName}"_ts.txt -m "$outDir"/rois/"${roiName}"_native.nii.gz
  fi
done


###### simultaneous bandpass + regression #####

# paste regressor timeseries into one file
if [[ "${compcorFlag}" -eq 1 ]]; then
  IFS=" " read -r -a arr <<< "$(for i in $(cat "$nuisanceInFile"); do echo "$outDir"/rois/mean_"$(get_filename "${i}")"_ts.txt; done | tr '\n' ' ')"
else # append motion parameters to regressor list
  IFS=" " read -r -a arr <<< "$(for i in $(cat "$nuisanceInFile"); do echo "$outDir"/rois/mean_"$(get_filename "${i}")"_ts.txt; done | tr '\n' ' '; echo "$rawEpiDir"/mcImg.par)"
fi

paste "${arr[@]}" > "$outDir"/NuisanceRegressor_ts.txt

regressorsFile="$outDir"/NuisanceRegressor_ts.txt
export regressorsFile

fsl_tsplot -i "$regressorsFile" -t "Time Series" -u 1 --start=1 -x 'Time Points (TR)' -w 800 -h 300 -o "${outDir}"/NuisanceRegressors_ts.png
echo "<br><br><img src=\"${outDir}/NuisanceRegressors_ts.png\" alt=\"$roi nuisance regressor\"><br>" >> "$indir"/analysisResults.html

# simultaneous bandpass + regression
clobber "${outDir}"/"$(basename "${epiData%%.nii*}")"_bp_res4d.nii.gz &&\
SimultBandpassNuisanceReg "${epiData}" "$rawEpiDir"/mcImgMean_mask.nii.gz

epiDataFiltReg="${outDir}"/"$(basename "${epiData%%.nii*}")"_bp_res4d.nii.gz
export epiDataFiltReg


###### Post-regression data-scaling ########################################

# Backup file
echo "...Scaling data by 1000"
cp "${epiDataFiltReg}" "${epiDataFiltReg/res4d/res4d_orig}"

# For some reason, this mask isn't very good.  Use the good mask top-level
echo "...Copy Brain mask"
cp "${rawEpiDir}"/mcImgMean_mask.nii.gz mask.nii.gz
fslmaths mask -mul 1000 mask1000 -odt float

# normalize res4d here
echo "...Normalize Data"
fslmaths "${epiDataFiltReg}" -Tmean "${epiDataFiltReg/res4d/res4d_tmean}"
fslmaths "${epiDataFiltReg}" -Tstd "${epiDataFiltReg/res4d/res4d_std}"
fslmaths "${epiDataFiltReg}" -sub "${epiDataFiltReg/res4d/res4d_tmean}" "${epiDataFiltReg/res4d/res4d_dmean}"
fslmaths "${epiDataFiltReg/res4d/res4d_dmean}" -div "${epiDataFiltReg/res4d/res4d_std}" "${epiDataFiltReg/res4d/res4d_normed}"
fslmaths "${epiDataFiltReg/res4d/res4d_normed}" -add mask1000 "${epiDataFiltReg/res4d/res4d_normandscaled}" -odt float

# Echo out final file to rsParams file
echo "epiNorm=${epiDataFiltReg/res4d/res4d_normed}" >> "$logDir"/rsParams

#################################




echo "$0 Complete"
echo ""
echo ""
