#!/bin/bash

##################################################################################################################
# Time Series Correlation from Seed/ROI masks
#     1. Push Seed masks from MNI to EPI space
#     2. Calculate Time-series for each Seed of interest
#     3. Time-Series Correlation/Zmap Creation
#     4. Seed zmap QC (push to standard (MNI)
##################################################################################################################


# Check of all ROIs (from ROIs directory), that can be used for seeding
scriptPath=$(perl -e 'use Cwd "abs_path";print abs_path(shift)' $0)
scriptDir=$(dirname $scriptPath)



function Usage {
  echo "Usage: seedVoxelCorrelation.sh --epi=restingStateImage --roiList=roiList.txt --motionscrub --clobber"
  echo " where"
  echo "   --epi resting state image"
  echo "        *this is the residual 4d image after nuisance regression and data scaling (*_bp_res4d_normandscaled.nii.gz)"
  echo "   --motionscrub use motionscrubbed and non-motionscrubbed EPI (parallel output)"
  echo "   --roiList Data file with seed list, one seed per line"
  echo "        **Use ONLY one option, -r or -R, NOT both"
  echo "   --compcor Flag if CompCor reg was performed"
  echo "   --compcor_global Flag if CompCorGlobal reg was performed"
  echo "   --seedmaps Flag to output seedmaps (default is off)"
  echo "   --clobber overwrite previous results"
  echo ""
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

function get_filename() {
  local input=$1
  file=${input##*/}
  echo ${file%%.*}
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
export clob=false
export -f clobber

# Map the ROIs
function extractROIts()
{
  local roi=$1
  roiName=$(basename "$roi" .nii.gz)
	roiMask=$(find "$roiOutDir" -maxdepth 1 -type f -name "${roiName}_mask.nii.gz" | head -n 1)
	# Copy over Seed ROI
  clobber ${roiOutDir}/${roiName}_standard.nii.gz &&\
	cp ${roi} ${roiOutDir}/${roiName}_standard.nii.gz

	if [ "$(echo ${roiMask})" = "" ]; then

		echo "......Mapping $roiName from MNI (standard) to subject EPI (func) space"
		# Source MNI to EPI warp file
		export MNItoEPIWarp=$(find ${rawEpiDir}/EPItoT1optimized* -maxdepth 1 -name "MNItoEPI_warp.nii.gz")
    if [ -z "${MNItoEPIWarp}" ]; then
      echo "Error: MNItoEPIWarp not found"
      exit 1
    fi
		# Apply the nonlinear warp from MNI to EPI
		applywarp --ref=${epiData} --in=${roi} --out=${roiOutDir}/${roiName}_mask.nii.gz --warp=${MNItoEPIWarp} --mask=${preproc}/mask.nii.gz --datatype=float

		# Threshold and binarize output
		fslmaths ${roiOutDir}/${roiName}_mask.nii.gz -thr 0.5 ${roiOutDir}/${roiName}_mask.nii.gz
		fslmaths ${roiOutDir}/${roiName}_mask.nii.gz -bin ${roiOutDir}/${roiName}_mask.nii.gz
		roiMask=${roiOutDir}/${roiName}_mask.nii.gz
	else
  	echo "$roiName has already been mapped from MNI to EPI"
  	echo "roimask: ${roiMask}"

	fi

	# Check to see that resultant, warped file has any volume (if seed is too small, warped output may have a zero volume)

	seedVol=$(fslstats ${roiMask} -V | awk '{print $2}')
	if [[ $seedVol == 0.000000 ]]; then
		echo $roiName >> ${roiOutDir}/seedsTooSmall.txt
		rm ${roiOutDir}/${roiName}_mask.nii.gz
	else
		# Account for $motionscrubFlag
		# Extract the time-series per ROI
		# Will need the "normal" time-series, regardless of motion-scrubbing flag so, if condition = 1 or 2, write out regular time-series
		if [[ $motionscrubFlag == 0 ]]; then
				clobber ${roiOutDir}/${roiName}_residvol_ts.txt &&\
				fslmeants -i ${epiData} -o ${roiOutDir}/${roiName}_residvol_ts.txt -m ${roiMask}
		elif [[ $motionscrubFlag == 1 ]]; then
				clobber ${roiOutDir}/${roiName}_residvol_ts.txt &&\
				fslmeants -i ${epiData} -o ${roiOutDir}/${roiName}_residvol_ts.txt -m ${roiMask}
				clobber ${roiOutDir}/${roiName}_residvol_ms_ts.txt &&\
				fslmeants -i ${rawEpiDir}/motionScrub/"$(basename ${epiData/.nii/_ms.nii})" -o ${roiOutDir}/${roiName}_residvol_ms_ts.txt -m ${roiMask}
		fi

		# Output of fslmeants is a text file with space-delimited values.  There is only one "true" ts value (first column) and the blank space is interpreted as a "0" value in matlab.  Write to temp file then move (rewrite original)
		if [[ $motionscrubFlag == 0 ]]; then
			cat ${roiOutDir}/${roiName}_residvol_ts.txt | awk '{print $1}' > ${roiOutDir}/temp_${roiName}_residvol_ts.txt
			mv ${roiOutDir}/temp_${roiName}_residvol_ts.txt ${roiOutDir}/${roiName}_residvol_ts.txt
		elif [[ $motionscrubFlag == 1 ]]; then
			cat ${roiOutDir}/${roiName}_residvol_ts.txt | awk '{print $1}' > ${roiOutDir}/temp_${roiName}_residvol_ts.txt
			cat ${roiOutDir}/${roiName}_residvol_ms_ts.txt | awk '{print $1}' > ${roiOutDir}/temp_${roiName}_residvol_ms_ts.txt
			mv ${roiOutDir}/temp_${roiName}_residvol_ts.txt ${roiOutDir}/${roiName}_residvol_ts.txt
			mv ${roiOutDir}/temp_${roiName}_residvol_ms_ts.txt ${roiOutDir}/${roiName}_residvol_ms_ts.txt
		fi
		echo "$roiName" >> "$roiOutDir"/seeds.txt
	fi

}

export -f extractROIts


# Create underlay/overlay images for each seed
function roi_qc()
{
  local roi=$1
	echo $roi
	roiName=$(basename ${roi} .nii.gz)
	roiMask=$(find "$outDir" -maxdepth 3 -type f -name "${roiName}_mask.nii.gz" | head -n 1)
	if [ ! -f $seedQCdir/${roi}_axial.png ] || [ ! -f $seedQCdir/${roi}_sagittal.png ] || [ ! -f $seedQCdir/${roi}_coronal.png ]; then
		for splitdirection in x y z; do
		    echo "......Preparing $roi ($splitdirection)"

		    underlayBase="$rawEpiDir"/mcImgMean.nii.gz
		    overlayBase=${roiMask}

		    # Compute Center-Of-Gravity for seed mask to determine which axial slice to use for both underlay and overlay
		    # Adding 0.5 to COG for xyz dimensions to handle rounding issues
		    # Need to account for slices named 0007, 0017, 0107, etc. (have to be able to handle 4-digit numbers)
		    if [[ $splitdirection == "x" ]]; then
		      suffix=sagittal
		      sliceCutTEMP=$(fslstats $overlayBase -C | awk '{printf("%d\n",$1 + 0.5)}')
		      sliceCutLength=$(echo $sliceCutTEMP | awk '{print length($1)}')
		      if [[ $sliceCutLength == 1 ]]; then
		        sliceCut=000${sliceCutTEMP}
		      elif [[ $sliceCutLength == 2 ]]; then
		        sliceCut=00${sliceCutTEMP}
		      else
		        sliceCut=0${sliceCutTEMP}
		      fi
		    elif [[ $splitdirection == "y" ]]; then
		      suffix=coronal
		      sliceCutTEMP=$(fslstats $overlayBase -C | awk '{printf("%d\n",$2 + 0.5)}')
		      sliceCutLength=$(echo $sliceCutTEMP | awk '{print length($1)}')
		      if [[ $sliceCutLength == 1 ]]; then
		        sliceCut=000${sliceCutTEMP}
		      elif [[ $sliceCutLength == 2 ]]; then
		        sliceCut=00${sliceCutTEMP}
		      else
		        sliceCut=0${sliceCutTEMP}
		      fi
		    else
		      suffix=axial
		      sliceCutTEMP=$(fslstats $overlayBase -C | awk '{printf("%d\n",$3 + 0.5)}')
		      sliceCutLength=$(echo $sliceCutTEMP | awk '{print length($1)}')
		      if [[ $sliceCutLength == 1 ]]; then
		        sliceCut=000${sliceCutTEMP}
		      elif [[ $sliceCutLength == 2 ]]; then
		        sliceCut=00${sliceCutTEMP}
		      else
		        sliceCut=0${sliceCutTEMP}
		      fi
		    fi

		    # Split apart seed mask and example EPI image
		    fslsplit $underlayBase $seedQCdir/temp/underlay_split_${suffix} -${splitdirection}
		    fslsplit $overlayBase $seedQCdir/temp/overlay_split_${suffix} -${splitdirection}

		    # Set variables for underlay and overlay images
		    underlayImage=$(find "$seedQCdir" -name "underlay_split_${suffix}${sliceCut}.nii.gz")
		    overlayImage=$(find "$seedQCdir" -name "overlay_split_${suffix}${sliceCut}.nii.gz")
		    # Copy over underlay/overlay images, uncompress
		    # Will need to check for presence of unzipped NIFTI file (from previous runs (otherwise "clobber" won't work))
		    if [[ -e $seedQCdir/${roi}_underlay_${suffix}.nii ]]; then
		      if [[ ! -e $seedQCdir/oldSeeds ]]; then
		        mkdir $seedQCdir/oldSeeds
		      fi

		      mv $seedQCdir/${roi}_underlay_${suffix}.nii $seedQCdir/oldSeeds
		    fi

		    cp $underlayImage $seedQCdir/${roi}_underlay_${suffix}.nii.gz
		    if [[ -e $seedQCdir/${roi}_overlay_${suffix}.nii ]]; then
		      if [[ ! -e $seedQCdir/oldSeeds ]]; then
		        mkdir $seedQCdir/oldSeeds
		      fi

		      mv $seedQCdir/${roi}_overlay_${suffix}.nii $seedQCdir/oldSeeds
		    fi

		    cp $overlayImage $seedQCdir/${roi}_overlay_${suffix}.nii.gz

		    # Need to reorient coronal and sagittal images in order for matlab to process correctly (axial is already OK)
		    # Coronal images will also need the orientation swapped to update header AND image info
		    if [ $suffix == "sagittal" ]; then
		      fslswapdim $seedQCdir/${roi}_underlay_${suffix}.nii.gz y z x $seedQCdir/${roi}_underlay_${suffix}.nii.gz
		      fslswapdim $seedQCdir/${roi}_overlay_${suffix}.nii.gz y z x $seedQCdir/${roi}_overlay_${suffix}.nii.gz
		    elif [ $suffix == "coronal" ]; then
		      fslswapdim $seedQCdir/${roi}_underlay_${suffix}.nii.gz x z y $seedQCdir/${roi}_underlay_${suffix}.nii.gz
		      fslorient -swaporient $seedQCdir/${roi}_underlay_${suffix}.nii.gz
		      fslswapdim $seedQCdir/${roi}_overlay_${suffix}.nii.gz x z y $seedQCdir/${roi}_overlay_${suffix}.nii.gz
		      fslorient -swaporient $seedQCdir/${roi}_overlay_${suffix}.nii.gz
		    fi

		    # Need to gunzip the files for use with matlab
		    gunzip -f $seedQCdir/${roi}_underlay_${suffix}.nii.gz
		    gunzip -f $seedQCdir/${roi}_overlay_${suffix}.nii.gz
	  	done
	else
		echo "Under/overlay niftis already exist for ${roi}! Skipping..."
	fi
}

export -f roi_qc

 function corrmap2mni()
  {
    local roi=$1
    echo "...Mapping Correlation For $roi to MNI"
    # Adjust for motion scrubbing
    if [[ $motionscrubFlag == 0 ]]; then
      # No motionscrubbing
      if [ -e ${roi}.png ]; then
        rm ${roi}.png
      fi

      echo here
      # Nonlinear warp from EPI to MNI
      clobber ${seedcorrDir}/${roi}_corrmap_standard.nii &&\
      applywarp --in=${seedcorrDir}/${roi}_corrmap_native.nii \
      --ref=${preproc}/reg/standard.nii.gz \
      --out=${seedcorrDir}/${roi}_corrmap_standard.nii \
      --warp=${preproc}/reg/example_func2standard_warp.nii.gz \
      --datatype=float
      echo applywarp done
      # Mask out data with MNI mask
      fslmaths ${seedcorrDir}/${roi}_corrmap_standard -mas $FSLDIR/data/standard/MNI152_T1_2mm_brain_mask ${seedcorrDir}/${roi}_corrmap_standard_masked

      
      # Creating new plots with fsl_tsplot
      # ~2.2% plotting difference between actual Ymin and Ymax values (higher and lower), with fsl_tsplot
      yMax=$(cat ${roiOutDir}/${roi}_residvol_ts.txt | sort -r | tail -1 | awk '{print ($1+($1*0.0022))}')
      yMin=$(cat ${roiOutDir}/${roi}_residvol_ts.txt | tail -1 | awk '{print ($1-($1*0.0022))}')

      clobber "$roiOutDir"/${roi}.png &&\
      fsl_tsplot -i ${roiOutDir}/${roi}_residvol_ts.txt -t "$roi Time Series" -u 1 --start=1 -x 'Time Points (TR)' --ymin=$yMin --ymax=$yMax -w 800 -h 300 -o "$roiOutDir"/${roi}.png

      echo "<br><img src=\"$roiOutDir/${roi}.png\" alt=\"$roi seed\"><br>" >> "$rawEpiDir"/analysisResults.html

    elif [[ $motionscrubFlag == 1 ]]; then
      # Non-motionscrubbed data
      if [ -e ${roi}.png ]; then
        rm ${roi}.png
      fi
      if [ -e ${roi}_ms.png ]; then
        rm ${roi}_ms.png
      fi


      # Nonlinear warp from EPI to MNI
      clobber ${roiOutDir}/${roi}_corrmap_ms_standard.nii &&\
      applywarp --in=${seedcorrDir}/${roi}_corrmap_ms_native.nii \
      --ref=${preproc}/reg/standard.nii.gz \
      --out=${seedcorrDir}/${roi}_corrmap_ms_standard.nii \
      --warp=${preproc}/reg/example_func2standard_warp.nii.gz \
      --datatype=float

      # Mask out data with MNI mask
      fslmaths ${seedcorrDir}/${roi}_corrmap_ms_standard -mas $FSLDIR/data/standard/MNI152_T1_2mm_brain_mask ${seedcorrDir}/${roi}_corrmap_ms_standard_masked

      # Look for the presence of deleted volumes.  ONLY create "spike" (ms) images if found, otherwise default to non-motionscrubbed images
      scrubDataCheck=$(cat ${rawEpiDir}/motionScrub/deleted_vols.txt | head -1)

      if [[ $scrubDataCheck != "" ]]; then
        # Presence of scrubbed volumes

        # Creating new plots with fsl_tsplot
        # ~2.2% plotting difference between actual Ymin and Ymax values (higher and lower), with fsl_tsplot
        yMax=$(cat ${roiOutDir}/${roi}_residvol_ms_ts.txt | sort -r | tail -1 | awk '{print ($1+($1*0.0022))}')
        yMin=$(cat ${roiOutDir}/${roi}_residvol_ms_ts.txt | tail -1 | awk '{print ($1-($1*0.0022))}')

        # Log the "scrubbed TRs"
        xNum=$(cat ${roiOutDir}/${roi}_residvol_ms_ts.txt | wc -l)
        count=1
        while [ $count -le $xNum ]; do
          tsPlotIn=$(cat ${roiOutDir}/${roi}_residvol_ms_ts.txt | head -${count} | tail -1)

          delPlotCheck=$(cat ${rawEpiDir}/motionScrub/deleted_vols.txt | awk '{$1=$1}1' | grep -E '(^| )'${count}'( |$)')
          if [ "$delPlotCheck" == "" ]; then
            delPlot=$yMin
          else
            delPlot=$yMax
          fi
          echo $delPlot >> ${roiOutDir}/${roi}_censored_TRplot.txt
        let count=count+1
        done

        #Plot of "scrubbed" data
        clobber "$roiOutDir"/${roi}_ms.png &&\
        fsl_tsplot -i ${roiOutDir}/${roi}_residvol_ms_ts.txt -t "$roi Time Series (Scrubbed)" -u 1 --start=1 -x 'Time Points (TR)' --ymin=$yMin --ymax=$yMax -w 800 -h 300 -o "$roiOutDir"/${roi}_ms.png

        echo "<br><img src=\"$roiOutDir/${roi}.png\" alt=\"${roi} seed\"><img src=\"$roiOutDir/${roi}_ms.png\" alt=\"${roi}_ms seed\"><br>" >> "$rawEpiDir"/analysisResults.html

      else
        # Absence of scrubbed volumes

        # Creating new plots with fsl_tsplot
        # ~2.2% plotting difference between actual Ymin and Ymax values (higher and lower), with fsl_tsplot
        yMax=$(cat ${roiOutDir}/${roi}_residvol_ms_ts.txt | sort -r | tail -1 | awk '{print ($1+($1*0.0022))}')
        yMin=$(cat ${roiOutDir}/${roi}_residvol_ms_ts.txt | tail -1 | awk '{print ($1-($1*0.0022))}')

        fsl_tsplot -i ${roiOutDir}/${roi}_residvol_ms_ts.txt -t "$roi Time Series" -u 1 --start=1 -x 'Time Points (TR)' --ymin=$yMin --ymax=$yMax -w 800 -h 300 -o "$roiOutDir"/${roi}.png

        echo "<br><img src=\"$roiOutDir/${roi}.png\" alt=\"$roi seed\"><br>" >> "$rawEpiDir"/analysisResults.html
      fi
    fi
  }

  export -f corrmap2mni

# Parse Command line arguments

##########
## MAIN ##
##########


# Parse Command line arguments

if [ $# -lt 2 ] ; then Usage; exit 0; fi
while [ $# -ge 1 ] ; do
    iarg=$(get_opt1 $1);
    case "$iarg"
	in
    --epi)
  	    export epiData=`get_arg1 $1`;
        if [ "$epiData" == "" ]; then
          echo "Error: The restingStateImage (-E) is a required option"
          exit 1
        fi
  	    shift;;
    --roiList)
      export roiInFile=$(get_arg1 $1);
      IFS=$'\r\n' GLOBIGNORE='*' command eval  'roiList=($(cat ${roiInFile}))';
      shift;;
    --compcor)
      export compcorFlag=1;
      shift;;
    --compcor_global)
      export compcor_globalFlag=1;
      shift;;
    --seedmaps)
      export seedmapFlag=1;
      shift;;
    --motionscrub)
      export motionscrubFlag=1;
      shift;;
    --clobber)
      export clob=true;
      shift;;
    -h)
      Usage;
      exit 0;;
    *)
      echo "Unrecognised option $1" 1>&2
      exit 1
     esac
done


# A few default parameters (if input not specified, these parameters are assumed)

if [[ -z $motionscrubFlag ]]; then
export motionscrubFlag=0
fi

if [[ -z $seedmapFlag ]]; then
export seedmapFlag=0
fi


# If new seeds are added, echo them out to the rsParams file (only if they don't already exist in the file)
# Making a *strong* assumption that any ROI lists added after initial processing won't reuse the first ROI (e.g. pccrsp)

# exit if input data doesn't exist
if [ ! -e ${epiData} ]; then
  echo "ERROR: epiData does not exist! check input file..."
  exit
fi

indir=$(dirname $epiData)
export rawEpiDir="${indir//\/nuisanceRegression*}"
export preproc="${rawEpiDir}"/preproc
logDir="${rawEpiDir}"


if [[ "${compcorFlag}" = 1 ]]; then
  outDir=${rawEpiDir}/seedCorrelation/compcor
elif [[ "${compcor_globalFlag}" = 1 ]]; then
  outDir=${rawEpiDir}/seedCorrelation/compcor_global
else
  outDir=${rawEpiDir}/seedCorrelation/classic
fi
export outDir
export roiOutDir=${outDir}/rois
mkdir -p "$roiOutDir"

seedTestBase=$(cat "$rawEpiDir"/rsParams | grep "seeds=" | awk -F"=" '{print $2}' | awk -F"-r " '{for (i=2; i<=NF; i++) print $i}')
seedTest=$(echo $seedTestBase | awk '{print $1}')
roiTest=$(echo "${roiList[@]}" | awk '{print $1}')
cd $outDir || exit

for i in "${roiList[@]}"
do
  seeds="$seeds -r $i"
done

if [[ "$seedTest" != "$roiTest" ]]; then
  echo "seeds=$seeds" >> "$rawEpiDir"/rsParams
fi


if [ $motionscrubFlag == 0 ]; then
  filename=run_firstlevelseeding_parallel.m
elif [ $motionscrubFlag = 1 ]; then
  filename=run_firstlevelseeding_parallel.m
  filename2=run_firstlevelseeding_parallel_ms.m
fi

# Echo out all input parameters into a log
echo "$scriptPath" >> $logDir/rsParams_log
echo "------------------------------------" >> $logDir/rsParams_log
echo "-E $epiData" >> $logDir/rsParams_log
echo "-m $motionscrubFlag" >> $logDir/rsParams_log
if [[ $roiInd == 1 ]]; then
  echo "$seeds" >> $logDir/rsParams_log
else
  echo "-R $roiInFile" >> $logDir/rsParams_log
fi
echo "$(date)" >> $logDir/rsParams_log
echo "" >> $logDir/rsParams_log
echo "" >> $logDir/rsParams_log

echo "Running $0 ..."

#### Mapping ROIs To Functional Space ############
echo "...Transforming ROIs to EPI space"

cd "$rawEpiDir" || exit
> "$roiOutDir"/seeds.txt
> "$roiOutDir"/seeds_ms.txt

# Map the ROIs
parallel --progress extractROIts ::: $(cat ${roiInFile})


roiList2=$(cat "$roiOutDir"/seeds.txt)

#################################



#### Seed Transform QC Images ############
echo "...QC Image Setup"

# Create QC images of seed/ROI overlaid on RestingState EPI.  Place in top level directory and report in HTML file
# Create underlay/overlay NIFTI files for QC check
# Create a temp directory
export seedQCdir=${roiOutDir}/seedQC
if [ ! -e $seedQCdir/temp ]; then
  mkdir -p $seedQCdir/temp
fi

# Create underlay/overlay images for each seed
parallel --progress roi_qc ::: $(cat "$roiOutDir"/seeds.txt)



# Create an output directory for QC seed images
seedQCOutdir="$roiOutDir"/seedQC
if [ ! -e $seedQCOutdir ]; then
  mkdir $seedQCOutdir
fi

> "$roiOutDir"/seeds_forQC.txt

for i in $(cat "$roiOutDir"/seeds.txt); do
	if [ ! -f $seedQCOutdir/${i}_axial.png ] || [ ! -f $seedQCOutdir/${i}_coronal.png ] || [ ! -f $seedQCOutdir/${i}_sagittal.png ]; then
		echo "${i}" >> "$roiOutDir"/seeds_forQC.txt
	else
		echo "png images for QC already exist for $i! Skipping..."
	fi
done

if [ -s "$roiOutDir"/seeds_forQC.txt ] && [ ! "$(head -n 1 "$roiOutDir"/seeds_forQC.txt 2> /dev/null)" = "" ]; then

	# Create overlaps of seed_mask registered to EPI space using Octave
	echo "...Creating QC Images of ROI/Seed Registration To Functional Space"
	filenameQC="$roiOutDir"/run_seedregistrationcheck.m;
cat > $filenameQC << EOF

% It is matlab script
close all;
clear all;
addpath('${scriptDir}');
niftiScripts=['${scriptDir}','/Octave/nifti'];
addpath(niftiScripts);statsScripts=['${scriptDir}','/Octave/statistics'];
statsScripts=['${scriptDir}','/Octave/statistics'];
addpath(statsScripts);
fid=fopen('$roiOutDir/seeds_forQC.txt');
roiList=textscan(fid,'%s');
fclose(fid);
seedDir='$seedQCdir';
imageDir='$seedQCOutdir';
seedregistrationcheck(seedDir,roiList,imageDir)
quit;
EOF


	# Run script using Matlab or Octave
	haveMatlab=$(which matlab)
	if [ "$haveMatlab" == "" ]; then
	  octave --no-window-system $filenameQC
	else
	  matlab -nodisplay -r "run $filenameQC"
	fi
else
	echo "no seeds to QC"
fi

# Remove temp directory of "split" files.  Keep only underaly and overlay base images
rm -rf $seedQCdir/temp

#################################



#### Output Images To HTML File ############

# Display Coronal,Sagittal,Axial on one line
# Put header of seed type

echo "<hr>" >> ${indir}/analysisResults.html
# echo "<h2>Seed Registration QC</h2>" >> ${indir}/analysisResults.html
echo "<h2>Seed Registration QC (Neurological View, Right=Right)</h2>" >> ${indir}/analysisResults.html
for roi in $roiList2
do
  echo "<br><b>$roi</b><br>" >> ${indir}/analysisResults.html
  echo "<img src=\"$seedQCOutdir/${roi}_coronal.png\" alt=\"${roi}_coronal seed QC\"><img src=\"$seedQCOutdir/${roi}_sagittal.png\" alt=\"${roi}_sagittal seed QC\"><img src=\"$seedQCOutdir/${roi}_axial.png\" alt=\"${roi}_axial seed QC\"><br>" >> "$rawEpiDir"/analysisResults.html
done

#################################



#### Seed Voxel Correlation (Setup) ############
if [ "${seedmapFlag}" -eq 1 ]; then
  echo "...Seed Voxel Correlation Setup"
  export seedcorrDir=${outDir}/seedmaps
  mkdir -p ${seedcorrDir}
  cd ${seedcorrDir} || exit
  # Dimensions of EPI data
  numXdim=$(fslinfo $epiData | grep ^dim1 | awk '{print $2}')
  numYdim=$(fslinfo $epiData | grep ^dim2 | awk '{print $2}')
  numZdim=$(fslinfo $epiData | grep ^dim3 | awk '{print $2}')

  cp "$roiOutDir"/seeds.txt "$roiOutDir"/seeds_orig.txt
  > "$roiOutDir"/seeds_ms.txt
  > "$roiOutDir"/seeds.txt

  # check if seeding results exist, re-populate seeds.txt with non existing seeds
  for roi in $(cat "$roiOutDir"/seeds_orig.txt); do
  	if [[ $motionscrubFlag == 0 ]] && [ ! -f $seedcorrDir/${roi}_corrmap_native.nii ] && [ ! -f $seedcorrDir/${roi}_corrmap_standard.nii ]; then
  		echo $roi >> "$roiOutDir"/seeds.txt
  	fi
  	if [[ $motionscrubFlag == 1 ]]; then
  		if [ ! -f $seedcorrDir/${roi}_corrmap_native.nii ] && [ ! -f $seedcorrDir/${roi}_corrmap_standard.nii ]; then
  			echo $roi >> "$roiOutDir"/seeds.txt
  		fi
  		if [ ! -f $seedcorrDir/${roi}_corrmap_ms_native.nii ] && [ ! -f $seedcorrDir/${roi}_corrmap_ms_standard.nii ]; then
  			echo $roi >> "$roiOutDir"/seeds_ms.txt
  		fi
  	fi
  done


  # Perform the Correlation

#################################

  if [ ! "$(head -n 1 "$roiOutDir"/seeds.txt 2> /dev/null)" = ""  ] || [ ! "$(head -n 1 "$roiOutDir"/seeds_ms.txt 2> /dev/null)" = ""  ]; then
      #### Seed Voxel Correlation (Execution) ############
      echo "...Correlating Seeds With Time Series Data"
      
      
      parallel --header : 3dTcorr1D -prefix ${seedcorrDir}/{roi}_corrmap_native -Fisher ${epiData} ${roiOutDir}/{roi}_residvol_ts.txt ::: roi $(cat "$roiOutDir"/seeds.txt)
      parallel --header : 3dAFNItoNIFTI ${seedcorrDir}/{roi}_corrmap_native+orig -prefix ${seedcorrDir}/{roi}_corrmap_native.nii ::: roi $(cat "$roiOutDir"/seeds.txt)

    if [[ $motionscrubFlag == 1 ]]; then
      parallel --header : 3dTcorr1D -prefix ${seedcorrDir}/{roi}_corrmap_ms_native -Fisher ${epiData} ${roiOutDir}/{roi}_residvol_ms_ts.txt ::: roi $(cat "$roiOutDir"/seeds_ms.txt)
      parallel --header : 3dAFNItoNIFTI ${seedcorrDir}/{roi}_corrmap_ms_native+orig -prefix ${seedcorrDir}/{roi}_corrmap_ms_native.nii ::: roi $(cat "$roiOutDir"/seeds_ms.txt)
    fi

  else
  	echo "no seeds to correlate."
  fi
#################################

#### Zstat Results (to T1/MNI) ############


  echo "...Creating zstat Results Directory"

  # HTML setup
  echo "<hr><h2>Seed Time Series</h2>" >> "$rawEpiDir"/analysisResults.html

  # warp corrmaps to MNI  
  parallel corrmap2mni ::: $(cat "$roiOutDir"/seeds_orig.txt)

fi
#################################
# workaround to prevent permissions 
if [ ${seedmapFlag} -eq 1 ]; then
  parallel chmod 774 ::: "$(find "${roiOutDir}" -maxdepth 1 -type f \( -name "seeds*.txt" -o -name "run*.m" \))" "$(find "${rawEpiDir}" -maxdepth 1 -type f -name "rsParams*")"
fi

echo "$0 Complete"
echo "Please make sure that the ROI folders were created in the ${roiOutDir}/ folder."
echo "If resultant warped seeds (to MNI) were too small, they were NOT processed.  Check ${rawEpiDir}/seedsTooSmall for exclusions."
echo "If motionscrubbing was set to 1 or 2, make sure that motionscrubbed data was created."
echo "OCTAVE/Matlab wouldn't give an error even if this step was not successfully done."
echo ""
echo ""
