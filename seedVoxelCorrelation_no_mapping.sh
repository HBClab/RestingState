#!/bin/bash

##################################################################################################################
# Time Series Correlation from Seed/ROI masks
#     1. Push Seed masks from MNI to EPI space
#     2. Calculate Time-series for each Seed of interest
##################################################################################################################

# nuisancefeat=nuisancereg.feat
melodicfeat=melodic.ica

# Check of all ROIs (from ROIs directory), that can be used for seeding
scriptPath=$(perl -e 'use Cwd "abs_path";print abs_path(shift)' $0)
scriptDir=$(dirname $scriptPath)
# knownRois=`ls -1 $scriptDir/ROIs/*nii* | awk -F"/" '{print $NF}' | awk -F"." '{print $1}'`
# VossLabMount=$(mount | grep $(whoami)@itf-rs-store13.hpc.uiowa.edu/vosslablss* | awk -F' ' '{print $3}')
VossLabMount="${HOME}/VossLabMount"


function printCommandLine {
  echo "Usage: seedVoxelCorrelation_no_mapping.sh -E restingStateImage -r roi -m motionscrubFlag -n -f"
  echo " where"
  echo "   -E resting state image"
  echo "        *Top-level RestingState.nii.gz image"
  echo "   -m use MotionScrub EPI: O,1 or 2 (default is 0/no)"
  echo "      0 = use non-motionscrubbed EPI only (default)"
  echo "      1 = use motionscrubbed EPI only"
  echo "      2 = use motionscrubbed and non-motionscrubbed EPI (parallel output)"
  echo "   -r roi for seed voxel (can be used multiple times)"
  echo "        *e.g. -r pccrsp -r icalc"
  echo "   -R Data file with seed list, one seed per line"
  echo "        **Use ONLY one option, -r or -R, NOT both"
  echo "   -n Nuisance regression method"
  echo "        1 = compcor only"
  echo "        2 = compcor + GM FAST regression"
  echo "        3 = compcor + GM mask regression"
  echo "        blank = classic"
  echo "   -f (fieldMap registration correction)"
  echo "        *Only set this flag if FieldMap correction was used during qualityCheck"
  echo "        **This affects only the EPI to T1 QC images"
  echo ""
  echo "Existing seeds:"
  echo "$knownRois"
  exit 1
}

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
			num_existing_files=$(( ${num_existing_files} + 1 ))
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
	if [ ${num_existing_files} -lt ${num_args} ]; then
		return 0
	else
		return 1
	fi

	# example usage
	# clobber test.nii.gz &&\
	# fslmaths input.nii.gz -mul 10 test.nii.gz
}
# default
clob=false
export -f clobber

# Parse Command line arguments
while getopts "hE:m:r:R:n:f" OPTION
do
  case $OPTION in
    h)
      printCommandLine
      ;;
    E)
      epiData=$OPTARG
      ;;
    m)
      motionscrubFlag=$OPTARG
      ;;
    r)
      roiList=$(echo $roiList $OPTARG)
      roiInd=1
      ;;
    R)
      roiList="$(cat $OPTARG | sed "s|VOSSLABMOUNT|${VossLabMount}|g")"
      roiInFile=$OPTARG
      ;;
    n)
      nuisanceFlag=$OPTARG
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

case "$nuisanceFlag" in
  1)
    nuisancefeat=nuisancereg_compcor.feat
    seedcorrDir=$(dirname ${epiData})/seedCorrelation_compcor
    ;;
  2)
    nuisancefeat=nuisancereg_compcor_wGMR.feat
    seedcorrDir=$(dirname ${epiData})/seedCorrelation_compcor_wGMR
    ;;
  3)
    nuisancefeat=nuisancereg_compcor_wGMRv1.feat
    seedcorrDir=$(dirname ${epiData})/seedCorrelation_compcor_wGMRv1
    ;;
  4)
    nuisancefeat=nuisancereg_classic_aroma.feat
    seedcorrDir=$(dirname ${epiData})/seedCorrelation_classic_aroma
    ;;
  "")
    nuisancefeat=nuisancereg.feat
    seedcorrDir=$(dirname ${epiData})/seedCorrelation
    ;;
esac

# Check for existence of output directory
if [[ ! -d ${seedcorrDir} ]]; then
  mkdir -p ${seedcorrDir}
fi

# A few default parameters (if input not specified, these parameters are assumed)

if [[ $motionscrubFlag == "" ]]; then
motionscrubFlag=0
fi

if [[ $fieldMapFlag == "" ]]; then
fieldMapFlag=0
fi

if [[ "$epiData" == "" ]]; then
  echo "Error: The restingStateImage (-E) is a required option."
  exit 1
fi

# If new seeds are added, echo them out to the rsParams file (only if they don't already exist in the file)
# Making a *strong* assumption that any ROI lists added after initial processing won't reuse the first ROI (e.g. pccrsp)
indir=$(dirname $epiData)
seedTestBase=$(cat $indir/rsParams | grep "seeds=" | awk -F"=" '{print $2}' | awk -F"-r " '{for (i=2; i<=NF; i++) print $i}')
seedTest=$(echo $seedTestBase | awk '{print $1}')
roiTest=$(echo $roiList | awk '{print $1}')

for i in $roiList
do
  seeds="$seeds -r $i"
done

if [[ "$seedTest" != "$roiTest" ]]; then
  echo "seeds=$seeds" >> $indir/rsParams
fi

subjectDir=$(dirname $indir)

if [ $motionscrubFlag == 0 ]; then
  filename=run_firstlevelseeding_parallel.m
elif [ $motionscrubFlag = 1 ]; then
  filename2=run_firstlevelseeding_parallel_ms.m
else
  filename=run_firstlevelseeding_parallel.m
  filename2=run_firstlevelseeding_parallel_ms.m
fi

# Echo out all input parameters into a log
logDir=$indir
echo "$scriptPath" >> $logDir/rsParams_log
echo "------------------------------------" >> $logDir/rsParams_log
echo "-E $epiData" >> $logDir/rsParams_log
echo "-m $motionscrubFlag" >> $logDir/rsParams_log
if [[ $roiInd == 1 ]]; then
  echo "$seeds" >> $logDir/rsParams_log
else
  echo "-R $roiInFile" >> $logDir/rsParams_log
fi
if [[ $fieldMapFlag == 1 ]]; then
  echo "-f" >> $logDir/rsParams_log
fi
echo "$(date)" >> $logDir/rsParams_log
echo "" >> $logDir/rsParams_log
echo "" >> $logDir/rsParams_log





echo "Running $0 ..."

#### Mapping ROIs To Functional Space ############
echo "...Transforming ROIs to EPI space"

cd $indir

# TW edit
> $indir/seeds.txt
> $indir/seeds_ms.txt

# Map the ROIs
for roi in $roiList; do
	roiName=$(basename ${roi} .nii.gz)
	roiMask=$(find $indir/nuisancereg*.feat -maxdepth 2 -type f -name "${roiName}_mask.nii.gz" | head -n 1)
	# Copy over Seed ROI
  clobber ${seedcorrDir}/${roiName}_standard.nii.gz &&\
	cp ${roi} ${seedcorrDir}/${roiName}_standard.nii.gz

	if [ "$(echo ${roiMask})" = "" ]; then # TW edit
  	echo "......Mapping $roiName from MNI (standard) to subject EPI (func) space"
  	# Source MNI to EPI warp file
  	# MNItoEPIWarp=`cat $indir/rsParams | grep "MNItoEPIWarp=" | tail -1 | awk -F"=" '{print $2}'`
  	MNItoEPIWarp=${indir}/EPItoT1optimized/MNItoEPI_warp.nii.gz

  	# Apply the nonlinear warp from MNI to EPI
  	applywarp --ref=${epiData} --in=${roi} --out=${nuisancefeat}/stats/${roiName}_mask.nii.gz --warp=${MNItoEPIWarp} --mask=${nuisancefeat}/stats/mask.nii.gz --datatype=float

  	# Threshold and binarize output
  	fslmaths ${nuisancefeat}/stats/${roiName}_mask.nii.gz -thr 0.5 ${nuisancefeat}/stats/${roiName}_mask.nii.gz
  	fslmaths ${nuisancefeat}/stats/${roiName}_mask.nii.gz -bin ${nuisancefeat}/stats/${roiName}_mask.nii.gz
  	roiMask=${nuisancefeat}/stats/${roiName}_mask.nii.gz
	else # TW edit
    echo "$roiName has already been mapped from MNI to EPI" #TW edit
    echo "roimask: ${roiMask}"

	fi # TW edit

	# Check to see that resultant, warped file has any volume (if seed is too small, warped output may have a zero volume)
  echo "extracting seed time-series, NOT creating individual seed maps"
	seedVol=$(fslstats ${roiMask} -V | awk '{print $2}')
	if [[ $seedVol == 0.000000 ]]; then
		echo $roiName >> ${nuisancefeat}/stats/seedsTooSmall.txt
		rm ${nuisancefeat}/stats/${roiName}_mask.nii.gz
	else
		# Account for $motionscrubFlag
		# Extract the time-series per ROI
		# Will need the "normal" time-series, regardless of motion-scrubbing flag so, if condition = 1 or 2, write out regular time-series
		if [[ $motionscrubFlag == 0 ]]; then
				clobber ${nuisancefeat}/stats/${roiName}_residvol_ts.txt &&\
				fslmeants -i ${nuisancefeat}/stats/res4d_normandscaled -o ${nuisancefeat}/stats/${roiName}_residvol_ts.txt -m ${roiMask}
		elif [[ $motionscrubFlag == 1 ]]; then
				echo ${roiMask}
				clobber ${nuisancefeat}/stats/${roiName}_residvol_ms_ts.txt &&\
				fslmeants -i ${nuisancefeat}/stats/res4d_normandscaled_motionscrubbed -o ${nuisancefeat}/stats/${roiName}_residvol_ms_ts.txt -m ${roiMask}
		else
				clobber ${nuisancefeat}/stats/${roiName}_residvol_ts.txt &&\
				fslmeants -i ${nuisancefeat}/stats/res4d_normandscaled -o ${nuisancefeat}/stats/${roiName}_residvol_ts.txt -m ${roiMask}
				clobber ${nuisancefeat}/stats/${roiName}_residvol_ms_ts.txt &&\
				fslmeants -i ${nuisancefeat}/stats/res4d_normandscaled_motionscrubbed -o ${nuisancefeat}/stats/${roiName}_residvol_ms_ts.txt -m ${roiMask}
		fi

		# Output of fslmeants is a text file with space-delimited values.  There is only one "true" ts value (first column) and the blank space is interpreted as a "0" value in matlab.  Write to temp file then move (rewrite original)
		if [[ $motionscrubFlag == 0 ]]; then
			cat ${nuisancefeat}/stats/${roiName}_residvol_ts.txt | awk '{print $1}' > ${nuisancefeat}/stats/temp_${roiName}_residvol_ts.txt
			mv ${nuisancefeat}/stats/temp_${roiName}_residvol_ts.txt ${nuisancefeat}/stats/${roiName}_residvol_ts.txt
		elif [[ $motionscrubFlag == 1 ]]; then
			cat ${nuisancefeat}/stats/${roiName}_residvol_ms_ts.txt | awk '{print $1}' > ${nuisancefeat}/stats/temp_${roiName}_residvol_ms_ts.txt
			mv ${nuisancefeat}/stats/temp_${roiName}_residvol_ms_ts.txt ${nuisancefeat}/stats/${roiName}_residvol_ms_ts.txt
		else
			cat ${nuisancefeat}/stats/${roiName}_residvol_ts.txt | awk '{print $1}' > ${nuisancefeat}/stats/temp_${roiName}_residvol_ts.txt
			cat ${nuisancefeat}/stats/${roiName}_residvol_ms_ts.txt | awk '{print $1}' > ${nuisancefeat}/stats/temp_${roiName}_residvol_ms_ts.txt
			mv ${nuisancefeat}/stats/temp_${roiName}_residvol_ts.txt ${nuisancefeat}/stats/${roiName}_residvol_ts.txt
			mv ${nuisancefeat}/stats/temp_${roiName}_residvol_ms_ts.txt ${nuisancefeat}/stats/${roiName}_residvol_ms_ts.txt
		fi
		echo "$roiName" >> $indir/seeds.txt
	fi
done

#################################


echo "$0 Complete"
echo "Please make sure that the ROI folders were created in the ${nuisancefeat}/stats/ folder."
echo "If resultant warped seeds (to MNI) were too small, they were NOT processed.  Check ${nuisancefeat}/stats/seedsTooSmall for exclusions."
echo "If motionscrubbing was set to 1 or 2, make sure that motionscrubbed data was created."
echo "OCTAVE/Matlab wouldn't give an error even if this step was not successfully done."
echo ""
echo ""
