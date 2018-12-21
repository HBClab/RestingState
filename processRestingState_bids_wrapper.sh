#!/bin/bash
# wrapper script for calling legacy resting state scripts
# assumes BIDS directory structure
# TODOS:
# need a different way to determine scannerID. e.g., dicom header?
function Usage {
  echo ""
  echo "Usage: processRestingState_wrapper.sh --epi=rawEpiFile --roiList=roilist"
  echo "--epi path/to/BIDS/sub-GEA161/ses-activepre/func/sub-GEA161_ses-activepre_task-rest_bold.nii.gz"
  echo "--t1 path/to/BIDS/derivatives/fmriprep/sub-GEA161/anat/sub-GEA161_T1w_preproc.nii.gz"
  echo "--t1_mask path/to/BIDS/derivatives/fmriprep/sub-GEA161/anat/sub-GEA161_T1w_brainmask.nii.gz"
  echo "--roiList file with list of rois. must include path to roi file."
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

function softwareCheck()
{

  if [ "$(which afni)" == "" ]; then
      echo "afni is either not downloaded or not defined in your path, exiting script"
      exit 1
  fi

  if [ "$(which fsl)" == "" ]; then
      echo "fsl is either not downloaded or not defined in your path, exiting script"
      exit 1
  fi

  if [ "$(which freesurfer)" == "" ]; then
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
# default
clob=false
export -f clobber


function RPI_orient() {
    local infile=$1 &&\
    [ ! -z  "${infile}" ] ||\
    ( printf '%s\n' "${FUNCNAME[0]}, input not defined" && return 1 )

    #Determine qform-orientation to properly reorient file to RPI (MNI) orientation
	xorient=`fslhd ${infile} | grep "^qform_xorient" | awk '{print $2}' | cut -c1`
	yorient=`fslhd ${infile} | grep "^qform_yorient" | awk '{print $2}' | cut -c1`
	zorient=`fslhd ${infile} | grep "^qform_zorient" | awk '{print $2}' | cut -c1`

	native_orient=${xorient}${yorient}${zorient}

	echo "native orientation = ${native_orient}"

	if [ "${native_orient}" != "RPI" ]; then

	  case ${native_orient} in

		#L PA IS
		LPI)
			flipFlag="-x y z"
			;;
		LPS)
			flipFlag="-x y -z"
	    		;;
		LAI)
			flipFlag="-x -y z"
	    		;;
		LAS)
			flipFlag="-x -y -z"
	    		;;

		#R PA IS
		RPS)
			flipFlag="x y -z"
	    		;;
		RAI)
			flipFlag="x -y z"
	    		;;
		RAS)
			flipFlag="x -y -z"
	    		;;

		#L IS PA
		LIP)
			flipFlag="-x z y"
	    		;;
		LIA)
			flipFlag="-x -z y"
	    		;;
		LSP)
			flipFlag="-x z -y"
	    		;;
		LSA)
			flipFlag="-x -z -y"
	    		;;

		#R IS PA
		RIP)
			flipFlag="x z y"
	    		;;
		RIA)
			flipFlag="x -z y"
	    		;;
		RSP)
			flipFlag="x z -y"
	    		;;
		RSA)
			flipFlag="x -z -y"
	    		;;

		#P IS LR
		PIL)
			flipFlag="-z x y"
	    		;;
		PIR)
			flipFlag="z x y"
	    		;;
		PSL)
			flipFlag="-z x -y"
	    		;;
		PSR)
			flipFlag="z x -y"
	    		;;

		#A IS LR
		AIL)
			flipFlag="-z -x y"
	    		;;
		AIR)
			flipFlag="z -x y"
	    		;;
		ASL)
			flipFlag="-z -x -y"
	    		;;
		ASR)
			flipFlag="z -x -y"
	    		;;

		#P LR IS
		PLI)
			flipFlag="-y x z"
	    		;;
		PLS)
			flipFlag="-y x -z"
	    		;;
		PRI)
			flipFlag="y x z"
	    		;;
		PRS)
			flipFlag="y x -z"
	    		;;

		#A LR IS
		ALI)
			flipFlag="-y -x z"
	    		;;
		ALS)
			flipFlag="-y -x -z"
	    		;;
		ARI)
			flipFlag="y -x z"
	    		;;
		ARS)
			flipFlag="y -x -z"
	    		;;

		#I LR PA
		ILP)
			flipFlag="-y z x"
	    		;;
		ILA)
			flipFlag="-y -z x"
	    		;;
		IRP)
			flipFlag="y z x"
	    		;;
		IRA)
			flipFlag="y -z x"
	    		;;

		#S LR PA
		SLP)
			flipFlag="-y z -x"
	    		;;
		SLA)
			flipFlag="-y -z -x"
	    		;;
		SRP)
			flipFlag="y z -x"
	    		;;
		SRA)
			flipFlag="y -z -x"
	    		;;

		#I PA LR
		IPL)
			flipFlag="-z y x"
	    		;;
		IPR)
			flipFlag="z y x"
	    		;;
		IAL)
			flipFlag="-z -y x"
	    		;;
		IAR)
			flipFlag="z -y x"
	    		;;

		#S PA LR
		SPL)
			flipFlag="-z y -x"
	    		;;
		SPR)
			flipFlag="z y -x"
	    		;;
		SAL)
			flipFlag="-z -y -x"
	    		;;
		SAR)
			flipFlag="z -y -x"
	    		;;
	  esac

	  echo "flipping by ${flipFlag}"

	  #Reorienting image and checking for warning messages
	  warnFlag=`fslswapdim ${infile} ${flipFlag} ${infile%.nii.gz}_RPI.nii.gz`
	  warnFlagCut=`echo ${warnFlag} | awk -F":" '{print $1}'`

	  #Reorienting the file may require swapping out the flag orientation to match the .img block
	  if [[ $warnFlagCut == "WARNING" ]]; then
		fslorient -swaporient ${infile%.nii.gz}_RPI.nii.gz
	  fi

	else

	  echo "No need to reorient.  Dataset already in RPI orientation."

	  if [ ! -e ${infile%.nii.gz}_RPI.nii.gz ]; then

	    cp ${infile} ${infile%.nii.gz}_RPI.nii.gz

	  fi

	fi
}



if [ $# -lt 2 ] ; then Usage; exit 0; fi
while [ $# -ge 1 ] ; do
  iarg=$(get_opt1 $1);
  case "$iarg"
in
  --epi)
      inFile=`get_arg1 $1`;
      export inFile;
      if [ "$inFile" == "" ]; then
        echo "Error: The restingStateImage (-E) is a required option"
        exit 1
      fi
      shift;;
  --t1)
      inFile=`get_arg1 $1`;
      export inFile;
      if [ "$inFile" == "" ]; then
        echo "Error: The restingStateImage (-E) is a required option"
        exit 1
      fi
      shift;;
  --t1_mask)
      inFile=`get_arg1 $1`;
      export inFile;
      if [ "$inFile" == "" ]; then
        echo "Error: The restingStateImage (-E) is a required option"
        exit 1
      fi
      shift;;
  --roiList)
      roilist=$(get_arg1 $1);
      shift;;
  --compcor)
      compcorFlag=1;
      aromaArg="--aroma";
      export compcorFlag;
      shift;;
  --usefmap)
      fieldMapFlag=1;
      shift;;
  --clobber)
      clob=true;
      shift;;
  -h)
      Usage;
      ;;
  *)
      echo "ERROR: Invalid option"
      Usage;
      ;;
    esac
done

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# if no user-defined roilist, default to first .nii.gz file found in ROIs dir
if [[ "${roilist}" == "" ]]; then
  find "${scriptdir}"/ROIs -type f -name "*.nii.gz" -print -quit > "${scriptdir}"/roiList_tmp.txt
  roilist="${scriptdir}"/roiList_tmp.txt
fi

bidsDir="${inFile//\/sub*}" # bids directory e.g., /vosslabhpc/Projects/Bike_ATrain/Imaging/BIDS
subID="$(echo "${inFile}" | grep -o "sub-[a-z0-9A-Z]*" | head -n 1 | sed -e "s|sub-||")" # gets subID from inFile
sesID="$(echo "${inFile}" | grep -o "ses-[a-z0-9A-Z]*" | head -n 1 | sed -e "s|ses-||")" # gets sesID from inFile
subDir="${bidsDir}/sub-${subID}" # e.g., /vosslabhpc/Projects/Bike_ATrain/Imaging/BIDS/sub-GEA161
scanner="$(echo "${subID}" | cut -c -2)" # extract scannerID from subID, works when scannerID is embedded in subID. TODO: need a different way to determine scannerID. e.g., dicom header?
rsOut="${bidsDir}/derivatives/rsOut/sub-${subID}/ses-${sesID}"

# load variables needed for processing

# check orientation of t1 and change to RPI if needed
RPI_orient ${t1}
RPI_orient ${t1_mask}

# t1
subjectT1_dir=$(dirname ${t1})
subjectT1_name=$(basename ${t1%%.nii*})
subjectT1_mask=$(basename ${t1_mask%%.nii*})

# make the t1_brain image
fslmaths ${t1} -mul ${t1_mask} ${subjectT1_dir}/${t1}_brain.nii.gz
t1_brain="${subjectT1_dir}/${t1}_brain.nii.gz"


if [[ "${fieldMapFlag}" = 1 ]]; then
  if [ "${scanner}" == "GE" ]; then
    fmap_prepped="$(find "${subDir}"/ses-"${sesID}"/fmap -type f -name "*fieldmap.nii.gz")"
    fmap_mag="$(find "${subDir}"/ses-"${sesID}"/fmap -type f -name "*magnitude.nii.gz")"
    fmap_mag_stripped="$(find "${subDir}"/ses-"${sesID}"/fmap -type f -name "*magnitude_stripped.nii.gz")"
    dwellTime="$(grep "dwellTime=" "$(find "${subDir}"/ses-"${sesID}"/func -type f -name "*rest_bold_info.txt")" | awk -F"=" '{print $2}' | tail -1)"
  elif [ "${scanner}" == "SE" ]; then
    fmap_prepped="$(find "${subDir}"/ses-"${sesID}"/fmap -maxdepth 1 -type f -name "*fieldmap_prepped.nii.gz")"
    fmap_mag="$(find "${subDir}"/ses-"${sesID}"/fmap -maxdepth 1 -type f -name "*magnitude1.nii.gz")"
    fmap_mag_stripped="$(find "${subDir}"/ses-"${sesID}"/fmap/mag1/ -type f -name "*mag1*_stripped.nii.gz" -print -quit)"
    dwellTime=0.00056
  fi
fi
 
  softwareCheck # check dependencies

  printf "\\n%s\\nBeginning preprocesssing ...\\n" "$(date)"

  mkdir -p "${rsOut}"

  {
  echo "t1=${t1_brain}"
  echo "t1Skull=${t1}"
  echo "t1Mask=${t1_mask}"
  echo "peDir=-y"
  echo "epiDwell=${dwellTime}"
  echo "epiTR=2"
  echo "epiTE=30"
  } >> "${rsOut}"/rsParams

  # copy raw rest image from BIDS to derivatives/rsOut_legacy/subID/sesID/
  rsync -a "${inFile}" "${rsOut}"/

  if [ ! -z "${fmap_prepped}" ] && [ "${fieldMapFlag}" == 1 ]; then # process with fmap
    echo "fieldMapCorrection=1" >> "${rsOut}"/rsParams
    #skull strip mag image
    if [ -z "${fmap_mag_stripped}" ]; then
      printf "\\n%s\\nSkull stripping fmap magnitude image..." "$(date)"
      bet "${fmap_mag}" "${fmap_mag//.nii.gz/_stripped.nii.gz}" -m -n -f 0.3 -B
      fslmaths "$(find "${subDir}"/ses-"${sesID}"/fmap -type f -name "*magnitude*stripped_mask.nii.gz")" -ero -bin "${fmap_mag//.nii.gz/_stripped_mask_eroded.nii.gz}" -odt char
      fslmaths "${fmap_mag}" -mas "${fmap_mag//.nii.gz/_stripped_mask_eroded.nii.gz}" "${fmap_mag//.nii.gz/_stripped.nii.gz}"
      fmap_mag_stripped="${fmap_mag//.nii.gz/_stripped.nii.gz}"
    fi
    
    "${scriptdir}"/qualityCheck.sh --epi="$(find "${rsOut}" -maxdepth 1 -type f -name "*rest_bold*.nii.gz")" \
      --t1brain="${t1_brain}" \
      --t1="${t1}" \
      --fmap="${fmap_prepped}" \
      --fmapmag="${fmap_mag}" \
      --fmapmagbrain="${fmap_mag_stripped}" \
      --dwelltime="${dwellTime}" \
      --pedir=-y \
      --regmode=6dof

    clobber "${rsOut}"/preproc/nonfiltered_smooth_data.nii.gz &&\
    "${scriptdir}"/restingStatePreprocess.sh --epi="${rsOut}"/mcImg_stripped.nii.gz \
      --t1brain="${t1_brain}" \
      --tr=2 \
      --te=30 \
      --smooth=6 \
      --usefmap \
      "${aromaArg}"

  elif [[ "${fieldMapFlag}" != 1 ]] || [[ -z "${fmap_prepped}" ]]; then
    printf "Process without fieldmap."
    "${scriptdir}"/qualityCheck.sh \
      --epi="$(find "${rsOut}" -maxdepth 1 -type f -name "*rest_bold*.nii.gz")" \
      --t1brain="${t1_brain}" \
      --t1="${t1}" \
      --dwelltime="${dwellTime}" \
      --pedir=-y \
      --regmode=6dof

    clobber "${rsOut}"/preproc/nonfiltered_smooth_data.nii.gz &&\
    "${scriptdir}"/restingStatePreprocess.sh \
      --epi="${rsOut}"/mcImg_stripped.nii.gz \
      --t1brain="${t1_brain}" \
      --tr=2 \
      --te=30 \
      --smooth=6 \
      "${aromaArg}"
  fi

  if [ "${compcorFlag}" -eq 1 ]; then
    epiDataFilt="${rsOut}"/ica_aroma/denoised_func_data_nonaggr.nii.gz
    epiDataFiltReg="${rsOut}"/nuisanceRegression/compcor/denoised_func_data_nonaggr_bp_res4d_normandscaled.nii.gz
    compcorArg="--compcor"
    {
    echo "$rsOut/SNR/CSF_pve_to_RS_thresh.nii.gz"; \
    echo "$rsOut/SNR/WM_pve_to_RS_thresh_ero.nii.gz"; } > "$rsOut"/nuisanceList.txt
  else
    epiDataFilt="$rsOut"/preproc/nonfiltered_smooth_data.nii.gz
    epiDataFiltReg="${rsOut}"/nuisanceRegression/classic/nonfiltered_smooth_data_bp_res4d_normandscaled.nii.gz
    compcorArg=""
    {
    echo "${scriptdir}/ROIs/latvent.nii.gz"; \
    echo "${scriptdir}/ROIs/global.nii.gz"; \
    echo "${scriptdir}/ROIs/wmroi.nii.gz"; } > "$rsOut"/nuisanceList.txt
  fi

  clobber "${epiDataFiltReg}" &&\
  "${scriptdir}/"removeNuisanceRegressor.sh \
    --epi="$epiDataFilt" \
    --t1brain="${t1_brain}" \
    --nuisanceList="$rsOut"/nuisanceList.txt \
    --lp=.08 \
    --hp=.008 \
    "${compcorArg}"

  clobber "${rsOut}"/motionScrub/"$(basename "${epiDataFiltReg/.nii/_ms.nii}")" &&\
  "${scriptdir}"/motionScrub.sh --epi="${epiDataFiltReg}"

  "${scriptdir}"/seedVoxelCorrelation.sh \
    --epi="${epiDataFiltReg}" \
    --motionscrub \
    --roiList="${roilist}" \
    "${compcorArg}"

  # prevents permissions denied error when others run new seeds
  parallel chmod 774 ::: "$(find "${rsOut}" -type f \( -name "highres2standard.nii.gz" -o -name "seeds*.txt" -o -name "rsParams*" -o -name "run*.m" -o -name "highres.nii.gz" -o -name "standard.nii.gz" -o -name "analysisResults.html" \))"
fi
