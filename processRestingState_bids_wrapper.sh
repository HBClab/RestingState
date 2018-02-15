#!/bin/bash
# wrapper script for calling legacy resting state scripts
# assumes BIDS directory structure
# TODOS:
# need a different way to determine scannerID. e.g., dicom header?
function printCommandLine {
  echo ""
  echo "Usage: processRestingState_wrapper.sh -i infile -R roilist "
  echo "-i path/to/BIDS/sub-GEA161/ses-activepost"
  echo "-R file with list of rois. must include path to roi file."
  exit 1
}

function softwareCheck()
{
  fsl_check=$(which fsl)
  afni_check=$(which afni)
  freesurfer_check=$(which freesurfer)

  if [ "${afni_check}" == "" ]; then
      echo "afni is either not downloaded or not defined in your path, exiting script"
      exit 1
  fi

  if [ "${fsl_check}" == "" ]; then
      echo "fsl is either not downloaded or not defined in your path, exiting script"
      exit 1
  fi

  if [ "${freesurfer_check}" == "" ]; then
      echo "freesurfer is either not downloaded or not defined in your path, exiting script"
      exit 1
  fi

}

function clobber()
{
	#Tracking Variables
	local -i num_existing_files=0
	local -i num_args=$#

	#Tally all existing outputs
	for arg in $@; do
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

	#see if the command should be run by seeing if the requisite files exist.
	#0=true
	#1=false
	if [ ${num_existing_files} -lt ${num_args} ]; then
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

while getopts “o:R:h” OPTION
do
  case $OPTION in
    o)
      rsOut=$OPTARG  # e.g., /vosslabhpc/Projects/Bike_ATrain/Imaging/BIDS/derivatives/rsOut_legacy/sub-GEA161/ses-activepre
      ;;
    R)
      roilist=$OPTARG
      ;;
    h)
      printCommandLine
      ;;
    ?)
      echo "ERROR: Invalid option"
      printCommandLine
      ;;
      esac
 done

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ "${rsOut}" == "" ]; then
  echo "ERROR: -O is required flag"
  exit 1
fi

# if no user-defined roilist, default to first .nii.gz file found in ROIs dir
if [[ "${roilist}" == "" ]]; then
  echo "$(find ${scriptdir}/ROIs -type f -name "*.nii.gz" -print -quit)" > ${scriptdir}/roiList_tmp.txt
  roilist=${scriptdir}/roiList_tmp.txt
fi

bidsDir=${rsOut//\/derivatives\/rsOut_legacy*} # bids directory e.g., /vosslabhpc/Projects/Bike_ATrain/Imaging/BIDS
subID="$(echo ${rsOut} | cut -d "-" -f 2 | sed 's|/.*||g')" # gets subID from rsOut path
subDir="${bidsDir}/${subID}" # e.g., /vosslabhpc/Projects/Bike_ATrain/Imaging/BIDS/sub-GEA161
scanner="$(echo ${subID} | cut -c -2)" # extract scannerID from subID, works when scannerID is embedded in subID. TODO: need a different way to determine scannerID. e.g., dicom header?


# load variables needed for processing

MBA_dir="$(dirname $(find ${bidsDir}/derivatives/MBA/sub-${subID} -type f -print -quit))" # find dir containing MBA output
echo "subDir is ${subDir}."
echo "MBA_dir is ${MBA_dir}."


if [[ ! -d "${MBA_dir}" ]]; then
  echo "ERROR: MBA directory not found in derivatives. Exiting."
  exit 1
else
  T1_RPI="$(find ${subDir}/ses-*/anat -type f -name "sub-${subID}_ses*_T1w.nii.gz")"
  T1_RPI_brain="$(find ${subDir}/ses-*/anat -type f -name "sub-${subID}_ses*_T1w_brain.nii.gz")"
  T1_brain_mask="(find ${MBA_dir} -type f -name "sub-${subID}_ses*_T1w_mask_60_smooth.nii.gz")"

  T1_RPI_brain="${MBA_dir}/sub-${subID}_ses-${dayone}pre_T1w_brain.nii.gz"
  T1_brain_mask="${MBA_dir}/sub-${subID}_ses-${dayone}pre_T1w_mask_60_smooth.nii.gz"
fi

rawRest="$(find ${bidsDir}/func -type f -name "*rest_bold*.nii.gz")"

if [ "${scanner}" == "GE" ]; then
  fmap_prepped="$(find ${bidsDir}/fmap -type f -name "*fieldmap.nii.gz")"
  fmap_mag="$(find ${bidsDir}/fmap -type f -name "*magnitude.nii.gz")"
  fmap_mag_stripped="$(find ${bidsDir}/fmap -type f -name "*magnitude_stripped.nii.gz")"
  dwellTime="$(cat $(find ${bidsDir}/func -type f -name "*rest_bold_info.txt") | grep "dwellTime=" | awk -F"=" '{print $2}' | tail -1)"
elif [ "${scanner}" == "SE" ]; then
  fmap_prepped="$(find ${bidsDir}/fmap -maxdepth 1 -type f -name "*fieldmap_prepped.nii.gz")"
  fmap_mag="$(find ${bidsDir}/fmap -maxdepth 1 -type f -name "*magnitude1.nii.gz")"
  fmap_mag_stripped="$(find ${bidsDir}/fmap/mag1/ -type f -name "*_stripped.nii.gz")"
  dwellTime=0.00056
fi


if [ -z "${T1_RPI}" ] || [ -z "${T1_RPI_brain}" ] || [ -z "${rawRest}" ]; then
  printf "\n$(date)\nERROR: at least one prerequisite scan is missing. Exiting.\n" 1>&2
  exit 1
else

  softwareCheck # check dependencies

  printf "\n$(date)\nBeginning preprocesssing (classic mode)...\n"

  mkdir -p ${rsOut}

  echo "t1=${T1_RPI_brain}" >> ${rsOut}/rsParams
  echo "t1Skull=${T1_RPI}" >> ${rsOut}/rsParams
  echo "t1Mask=${T1_brain_mask}" >> ${rsOut}/rsParams
  echo "peDir=-y" >> ${rsOut}/rsParams
  echo "epiDwell=${dwellTime}" >> ${rsOut}/rsParams
  echo "epiTR=2" >> ${rsOut}/rsParams
  echo "epiTE=30" >> ${rsOut}/rsParams


  # copy raw rest image from BIDS to derivatives/rsOut_legacy/subID/sesID/
  cp ${rawRest} ${rsOut}

  if [ ! -z "${fmap_prepped}" ]; then # process with fmap
    echo "fieldMapCorrection=1" >> ${rsOut}/rsParams
    #skull strip mag image
    if [ "${fmap_mag_stripped}" == "" ]; then
      clobber ${bidsDir}/fmap/$(find ${bidsDir}/fmap -type f -name "*magnitude_stripped.nii.gz") &&\
      printf "\n$(date)\nSkull stripping fmap magnitude image..." &&\
      bet ${fmap_mag} "$(echo ${fmap_mag} | sed -e 's/magnitude/magnitude_stripped/')" -m -n -f 0.3 -B &&\
      fslmaths "$(find ${bidsDir}/fmap -type f -name "*magnitude_stripped_mask.nii.gz")" -ero -bin "$(echo ${fmap_mag} | sed -e 's/magnitude/magnitude_stripped_mask_eroded/')" -odt char &&\
      fslmaths ${fmap_mag} -mas "$(echo ${fmap_mag} | sed -e 's/magnitude/magnitude_stripped_mask_eroded/')" "$(echo ${fmap_mag} | sed -e 's/magnitude/magnitude_stripped/')" &&\
      fmap_mag_stripped="$(find ${bidsDir}/fmap -type f -name "*magnitude_stripped.nii.gz")"
    fi

    ${scriptdir}/qualityCheck.sh -E "$(find ${rsOut} -maxdepth 1 -type f -name "*rest_bold*.nii.gz")" \
      -A ${T1_RPI_brain} \
      -a ${T1_RPI} \
      -f \
      -b ${fmap_prepped} \
      -v ${fmap_mag} \
      -x ${fmap_mag_stripped} \
      -D ${dwellTime} \
      -d -y -c

    ${scriptdir}/restingStatePreprocess.sh -E ${rsOut}/mcImg_stripped.nii.gz \
      -A ${T1_RPI_brain} \
      -t 2 \
      -T 30 \
      -s 6 \
      -f -c

    ${scriptdir}/removeNuisanceRegressor.sh -E $rsOut/preproc.feat/nonfiltered_smooth_data.nii.gz \
      -A ${T1_RPI_brain} \
      -n wmroi -n latvent -n global \
      -L .08 \
      -H .008 \
      -t 2 \
      -T 30 -c

    ${scriptdir}/motionScrub.sh -E $rsOut/RestingState.nii.gz

    ${scriptdir}/seedVoxelCorrelation.sh -E $rsOut/RestingState.nii.gz \
      -m 2 \
      -R ${roilist} \
      -f -V
  else
    printf "no fieldmap found."
    ${scriptdir}/qualityCheck.sh -E "$(find ${rsOut} -maxdepth 1 -type f -name "*rest_bold*.nii.gz")" \
      -A ${T1_RPI_brain} \
      -a ${T1_RPI} \
      -D ${dwellTime} \
      -d -y -c

    ${scriptdir}/restingStatePreprocess.sh -E ${rsOut}/mcImg_stripped.nii.gz \
      -A ${T1_RPI_brain} \
      -t 2 \
      -T 30 \
      -s 6 \
      -c

    ${scriptdir}/removeNuisanceRegressor.sh -E $rsOut/preproc.feat/nonfiltered_smooth_data.nii.gz \
      -A ${T1_RPI_brain} \
      -n wmroi -n latvent -n global \
      -L .08 \
      -H .008 \
      -t 2 \
      -T 30 -c

    ${scriptdir}/motionScrub.sh -E $rsOut/RestingState.nii.gz

    ${scriptdir}/seedVoxelCorrelation.sh -E $rsOut/RestingState.nii.gz \
      -m 2 \
      -R ${roilist} \
      -V
  fi
  printf "\n$(date)\nBeginning reproc nuisance regression (ica_aroma + compcor)...\n"
  ${scriptdir}/reproc_2016.sh -i ${rsOut} -R ${roilist} -A "${MBA_dir}"

  # prevents permissions denied error when others run new seeds
  parallel chmod 774 ::: $(find ${rsOut} -type f \( -name "highres2standard.nii.gz" -o -name "seeds*.txt" -o -name "rsParams*" -o -name "run*.m" -o -name "highres.nii.gz" -o -name "standard.nii.gz" -o -name "analysisResults.html" \))
fi
