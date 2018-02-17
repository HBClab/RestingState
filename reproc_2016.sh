#!/bin/bash

########################################################################
# ICA-AROMA, bandpass denoised data, nuisance regression (segmented at sub level)
#     Nuisance regression 2 iterations:
#        1. grey matter regressor (.90 partial volume), 5 white matter regressors, 5 CSF regressors
#        2. 5 white matter regressors, 5 CSF regressors
########################################################################
SGE_ROOT='';export SGE_ROOT


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


function softwareCheck()
{
  fsl_check=$(which fsl)
  afni_check=$(which afni)
  freesurfer_check=$(which freesurfer)
	aroma_check=$(which ICA_AROMA.py)

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

	if [ "$(which ICA_AROMA.py)" == "" ]; then
      echo "ICA_AROMA is either not downloaded or not defined in your path, exiting script"
      exit 1
  fi
}

function bandpass()
{
	local inData=$1
	local mask=$2
  local hpf=$3
  local lpf=$4
  local inDir=$(dirname ${inData})

  #defaults
  if [ "$hpf" == "" ]; then
    hpf=.008
  fi

  if [ "$lpf" == "" ]; then
    lpf=.08
  fi

  clobber ${inDir}/$(basename "${inData%%.nii*}")_bp.nii.gz &&\
  rm -rf ${inDir}/*_mean.nii.gz 2> /dev/null &&\
  rm -rf ${inDir}/tmp_bp.nii.gz 2> /dev/null &&\
	3dBandpass -prefix $inDir/tmp_bp.nii.gz -mask ${mask} ${hpf} ${lpf} ${inData} &&\
	3dTstat -mean -prefix $inDir/orig_mean.nii.gz ${inData} &&\
	3dTstat -mean -prefix $inDir/bp_mean.nii.gz $inDir/tmp_bp.nii.gz &&\
	3dcalc -a $inDir/tmp_bp.nii.gz -b $inDir/orig_mean.nii.gz -c $inDir/bp_mean.nii.gz -expr "a+b-c" -prefix ${inDir}/$(basename "${inData%%.nii*}")_bp.nii.gz
}
export -f bandpass

function medianScale()
{
  local inFile=$1
  local maskFile=$2
  local outDir=$(dirname $inFile)

  # if [ ! -s "{$inFile}" ]; then
  #   >&2 echo "${inFile} doesn't exist! exiting."
  #   exit 1
  # else
    echo "scaling over median intensity"
    median_intensity=$(fslstats $inFile -k $maskFile -p 50)
    scaling=$(echo "scale=16; 10000/${median_intensity}" | bc)
    fslmaths $inFile -mul $scaling $outDir/nonfiltered_smooth_data_intnorm.nii.gz
  # fi
}
export -f medianScale

function feat_regFix()
{
  local nuisancefeat="${1}"
  local scriptDir="${2}"
  local epiDir="${3}"
  local epiVoxTot="${4}"
  local te="${5}"
  local numtimepoint="${6}"
  local tr="${7}"
  local dwellTime="${8}"
  local peDirNEW="${9}"
  local fsf="${10}"
  local preprocfeat=preproc.feat

  ###### FEAT registration correction ########################################



  #http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FEAT/FAQ
  #ss: "How can I insert a custom registration into a FEAT analysis?"

  regDir=$epiDir/${nuisancefeat}/reg

  #Remove all FEAT files (after backup), repopulate with proper files
  if [ -d $epiDir/${nuisancefeat}/reg ]; then
    echo "...Fixing FEAT registration QC images. ${nuisancefeat}"
    # mv $regDir $epiDir/${nuisancefeat}/regORIG
		rm -r $epiDir/${nuisancefeat}/reg
  fi
	##Copy over appropriate reg directory from melodic.ica or preproc.feat processing
	rsync -a $epiDir/${preprocfeat}/reg $epiDir/${nuisancefeat}

  #NUISANCEDIR
  nuisanceDir=$epiDir/${nuisancefeat}
  local fsf_regFix="dummy_$(basename ${fsf} .fsf | sed 's/reg//')_regFix_5.0.10.fsf"
  if [ -e ${scriptDir}/${fsf_regFix} ]; then
    #Backup original design file
    rsync -a $epiDir/${nuisancefeat}/design.fsf $epiDir/${nuisancefeat}/designORIG.fsf

    cat $scriptDir/${fsf_regFix} | sed 's|SUBJECTPATH|'${epiDir}'|g' | \
                                         sed 's|VOXTOT|'${epiVoxTot}'|g' | \
                                         sed 's|NUISANCEDIR|'${nuisanceDir}'|g' | \
                                         sed 's|SCANTE|'${te}'|g' | \
                                         sed 's|SUBJECTVOLS|'${numtimepoint}'|g' | \
                                         sed 's|SUBJECTTR|'${tr}'|g' | \
                                         sed 's|EPIDWELL|'${dwellTime}'|g' | \
                                         sed 's|PEDIR|\'${peDirNEW}'|g' | \
                                         sed 's|FSLDIR|'${FSLDIR}'|g' > ${fsf%.*}_regFix.fsf

      #Re-run feat
      if [ ! -e $epiDir/${nuisancefeat}/old/designORIG.fsf ]; then
        echo "...Rerunning FEAT (nuisancereg(post-stats only))"
        feat ${fsf%.*}_regFix.fsf

        #Log output to HTML file
        echo "<a href=\"$epiDir/${nuisancefeat}/report.html\">FSL Nuisance Regressor Results</a>" >> $epiDir/analysisResults.html
      fi
  else
    echo "fsf doesn't exist!"
		exit 1
  fi
}
export -f feat_regFix

function dataScale()
{
  ###### Post-FEAT data-scaling ########################################
  local inDir=$1
  cd $inDir/stats

  echo "...Scaling data by 1000"

  #Backup file
  if [ -e $inDir/stats/res4d.nii.gz ]; then
    if [ ! -e $inDir/stats/res4d_orig.nii.gz ]; then
      rsync -a res4d.nii.gz res4d_orig.nii.gz
    fi
  else
    echo "$inDir/stats/res4d.nii.gz doesn't exist! exiting"
     return 1
  fi

  #For some reason, this mask isn't very good.  Use the good mask top-level
  if [ ! -e mask1000.nii.gz ]; then
    echo "...Copy Brain mask"
    rsync -a ../../mcImgMean_mask.nii.gz mask.nii.gz
    fslmaths mask -mul 1000 mask1000 -odt float
  fi

  #normalize res4d here
  echo "...Normalize Data"
  if [ ! -s res4d_tmean.nii.gz ]; then
    fslmaths res4d -Tmean res4d_tmean
  fi

  if [ ! -s res4d_std.nii.gz ]; then
    fslmaths res4d -Tstd res4d_std
  fi

  if [ ! -s res4d_dmean.nii.gz ]; then
    fslmaths res4d -sub res4d_tmean res4d_dmean
  fi

  if [ ! -s res4d_normed.nii.gz ]; then
    fslmaths res4d_dmean -div res4d_std res4d_normed
  fi

  if [ ! -s res4d_normandscaled ]; then
    fslmaths res4d_normed -add mask1000 res4d_normandscaled -odt float
  fi
}
export -f dataScale

function printCommandLine {
    echo "Usage: reproc_2016.sh -i epiDir -A path/to/T1_seg -R roilist -c clobber (optional)"
    echo " where:"
    echo "-i    Directory where the reconstructed EPI lives"
		echo "-A    Directory where the segmented T1 lives (optional)"
		echo "-R		file containing paths to ROIs for seedcorrelation"
		echo "-c		Overwrite existing files"
    exit 1
}


function motionScrub()
{
##################################################################################################################
# Motion Scrubbing (Censoring TRs with too much movement (Power 2012 Neuroimage)
#     1. Scrubbing
#       a. 0=No Scrubbing
#       b. 1=Motion Scrubbing
#       c. 2=No Scrubbing, Motion Scrubbing in parallel
##################################################################################################################

local epiData=$1
local nuisancefeat=$2
local filename=run_motionscrub.m


if [ "$epiData" == "" ]; then
  echo "Error: The restingStateImage (-E) is a required option."
  exit 1
fi

local indir=`dirname $epiData`

echo "Running motionScrub on $nuisancefeat ..."

cd $indir

# Extract image dimensions from the NIFTI File
local numXdim=`fslinfo $epiData | grep ^dim1 | awk '{print $2}'`
local numYdim=`fslinfo $epiData | grep ^dim2 | awk '{print $2}'`
local numZdim=`fslinfo $epiData | grep ^dim3 | awk '{print $2}'`
local numtimepoint=`fslinfo $epiData | grep ^dim4 | awk '{print $2}'`

#### Motion scrubbing ############

echo "...Scrubbing data"
cat > $filename << EOF
% It is matlab script
addpath('${scriptDir}')
niftiScripts=['${scriptDir}','/Octave/nifti'];
addpath(niftiScripts)
funcvoldim=[${numXdim} ${numYdim} ${numZdim} ${numtimepoint}];
motionscrub('${indir}','${nuisancefeat}',funcvoldim)
quit
EOF

# Run script using Matlab or Octave
haveMatlab=`which matlab`
if [ "$haveMatlab" == "" ]; then
  octave --no-window-system $indir/$filename
else
  matlab -nodisplay -r "run $indir/$filename"
fi

#################################

#### Process Summary ############
echo "...Summarizing Results"

##Want to summarize motion-scrubbing output
echo "ID,total_volumes,deleted_volumes,prop_deleted,resid_vols" > ${indir}/motion_scrubbing_info.txt

##Echo out the pertinent info for the motion-scrubbed/processed subjects

numvols=`fslinfo ${indir}/nuisancereg.feat/stats/res4d_normandscaled.nii | grep ^dim4 | awk '{print $2}'`
delvols=`cat ${indir}/nuisancereg.feat/stats/deleted_vols.txt | wc | awk '{print $2}'`
propdel=`echo ${numvols} ${delvols} | awk '{print ($2/$1)}'`
residvols=`echo ${numvols} ${delvols} | awk '{print ($1-$2)}'`
echo "${indir},${numvols},${delvols},${propdel},${residvols}" >> ${indir}/motion_scrubbing_info.txt

#Echo out motionscrub info to rsParams file
echo "epiNormMS=${indir}/nuisancereg.feat/stats/res4d_normandscaled_motionscrubbed.nii" >> $indir/rsParams

echo "<hr>" >> ${indir}/analysisResults.html
echo "<h2>Motion Scrubbing</h2>" >> ${indir}/analysisResults.html
echo "<b>Total Volumes</b>: $numvols<br>" >> ${indir}/analysisResults.html
echo "<b>Deleted Volumes</b>: $delvols<br>" >> ${indir}/analysisResults.html
echo "<b>Remaining Volumes</b>: $residvols<br>" >> ${indir}/analysisResults.html

scrubDataCheck=`cat $indir/$nuisancefeat/stats/deleted_vols.txt | head -1`
if [[ $scrubDataCheck != "" ]]; then
  echo "<b>Scrubbed TR</b>: `cat ${indir}/nuisancereg.feat/stats/deleted_vols.txt | awk '{$1=$1}1'`<br>" >> ${indir}/analysisResults.html
fi

#################################

echo "motionScrub Complete"
echo ""
echo ""
}

################################################################
#Global SNR Estimation
function SNRcalc() {
    cd $(dirname $1)
    echo "...Calculating signal to noise measurements"

    fslmaths $1 -Tmean $(basename $1 .nii.gz)_mean
    #calculate standard deviation image of motion corrected functional series
    fslmaths $1 -Tstd $(basename $1 .nii.gz)_Std
    #ratio of mean over standard deviation
    fslmaths $(basename $1 .nii.gz)_mean -div $(basename $1 .nii.gz)_Std $(basename $1 .nii.gz)_SNR
    #mask the SNR img to keep only brain voxels
    fslmaths $(basename $1 .nii.gz)_SNR -mas $epiDir/mcImgMean_mask.nii.gz $(basename $1 .nii.gz)_SNR

    fslstats $(basename $1 .nii.gz)_SNR -M >> SNR_calc.txt

}

while getopts “hi:A:R:c” OPTION
do
    case $OPTION in
  i)
      epiDir=$OPTARG
      ;;
  A)
      t1Dir=$OPTARG
      ;;
	R)
			roilist=$OPTARG
			;;
  c)
      clob=true
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



if [ "${epiDir}" == "" ]; then
  >&2 echo "no input dir detected. exiting"
  exit 1
fi

softwareCheck # check dependencies

analysis=nuisancereg_compcor_wGMR
analysisFix=nuisanceregFix_compcor_wGMR
nuisancefeat=${analysis}.feat

analysis2=nuisancereg_compcor
analysisFix2=nuisanceregFix_compcor
nuisancefeat2=${analysis2}.feat

analysis3=nuisancereg_compcor_wGMRv1
analysisFix3=nuisanceregFix_compcor_WGMRv1
nuisancefeat3=${analysis3}.feat

fsf=${analysis}.fsf
fsf2=${analysis2}.fsf
fsf3=${analysis3}.fsf


scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# if [ "$(which parallel)" == "" ]; then
#     echo "GNU parallel is either not downloaded or not defined in your path, exiting script"
#     exit 1
# fi

# scaling by median intensity
clobber $epiDir/preproc.feat/nonfiltered_smooth_data_intnorm.nii.gz &&\
medianScale $epiDir/preproc.feat/nonfiltered_smooth_data.nii.gz $epiDir/mcImgMean_mask.nii.gz

# ICA-AROMA
clobber $epiDir/ica_aroma/denoised_func_data_nonaggr.nii.gz &&\
if [ -d $epiDir/ica_aroma ]; then rm -rf $epiDir/ica_aroma; fi &&\
python ICA_AROMA.py -i $epiDir/preproc.feat/nonfiltered_smooth_data_intnorm.nii.gz -o $epiDir/ica_aroma -mc $epiDir/mcImg.par -w $epiDir/EPItoT1optimized/EPItoMNI_warp.nii.gz

if [ ! -e $epiDir/ica_aroma/denoised_func_data_nonaggr.nii.gz ]; then
  >&2 echo "$epiDir/ica_aroma/denoised_func_data_nonaggr.nii.gz not found! exiting"
  exit 1
fi

# track ratio of noise components/total components
if [ -e $epiDir/ica_aroma/noise_ratio.csv ]; then
  rm $epiDir/ica_aroma/noise_ratio.csv
fi

numTotComps=$(tail -n +2 $epiDir/ica_aroma/classification_overview.txt | wc -l)
numNoiseComps=$(sed 's/[^,]//g' $epiDir/ica_aroma/classified_motion_ICs.txt | wc -c)
ratio=$(echo "scale=2; ${numNoiseComps}/${numTotComps}" | bc)
clobber $epiDir/ica_aroma/noise_ratio.csv &&\
echo "$epiDir,$numNoiseComps,$numTotComps,$ratio" >> $epiDir/ica_aroma/noise_ratio.csv

# temporal SNR calculation
clobber $epiDir/SNR_calc.txt &&\
SNRcalc $epiDir/ica_aroma/denoised_func_data_nonaggr.nii.gz

# bandpass denoised EPI data
clobber $epiDir/ica_aroma/denoised_func_data_nonaggr_bp.nii.gz &&\
bandpass $epiDir/ica_aroma/denoised_func_data_nonaggr.nii.gz $epiDir/mcImgMean_mask.nii.gz .008 .08

clobber ${epiDir}/mcImg_smooth_denoised_bp.nii.gz &&\
cp $epiDir/ica_aroma/denoised_func_data_nonaggr_bp.nii.gz ${epiDir}/mcImg_smooth_denoised_bp.nii.gz
epiDataFilt=${epiDir}/mcImg_smooth_denoised_bp.nii.gz
epiVoxTot=`fslstats ${epiDataFilt} -v | awk '{print $1}'`


# warping nuisance ROIs  #### Nuisance ROI mapping ############
echo "...Warping Nuisance ROIs to EPI space"

if [ "${t1Dir}" = "" ]; then
  segDir="$(dirname ${epiDir})"/anat/tissueSeg
else
  segDir=${t1Dir}/tissueSeg
fi

snrDir=${epiDir}/SNR
preprocDir=${epiDir}/preproc.feat
epiWarpDir=${epiDir}/EPItoT1optimized
fieldmapFlag=`cat ${epiDir}/rsParams | grep "fieldMapCorrection=" | tail -1 | awk -F"=" '{print $2}'`

if [ "${fieldmapFlag}" == "1" ]; then
	echo "field map flag detected, using nonlinear transform"
	clobber $preprocDir/rois/WM_FAST_ts.txt &&\
	applywarp --in=$segDir/T1_pve_2.nii.gz --out=$snrDir/WM_pve_to_RS.nii.gz --ref=${epiDir}/mcImgMean.nii.gz --warp=${epiWarpDir}/T1toEPI_warp.nii.gz --interp=nn &&\
	fslmaths $snrDir/WM_pve_to_RS.nii.gz -thr .99 -bin $snrDir/WM_pve_to_RS_thresh.nii.gz &&\
	fslmaths $snrDir/WM_pve_to_RS_thresh.nii.gz -kernel box 8 -ero $snrDir/WM_pve_to_RS_thresh_ero.nii.gz &&\
	fslmeants -i $epiDataFilt -m $snrDir/WM_pve_to_RS_thresh_ero.nii.gz -o $preprocDir/rois/WM_FAST_ts.txt --eig --order=5

	clobber $preprocDir/rois/GM_FAST_ts.txt &&\
	applywarp --in=$segDir/T1_pve_1.nii.gz --out=$snrDir/GM_pve_to_RS.nii.gz --ref=${epiDir}/mcImgMean.nii.gz --warp=${epiWarpDir}/T1toEPI_warp.nii.gz --interp=nn &&\
	fslmaths $snrDir/GM_pve_to_RS.nii.gz -thr .90 -bin $snrDir/GM_pve_to_RS_thresh.nii.gz -odt char &&\
	fslmeants -i $epiDataFilt -m $snrDir/GM_pve_to_RS_thresh.nii.gz -o $preprocDir/rois/GM_FAST_ts.txt

	clobber $preprocDir/rois/CSF_FAST_ts.txt &&\
	applywarp --in=$segDir/T1_pve_0.nii.gz --out=$snrDir/CSF_pve_to_RS.nii.gz --ref=${epiDir}/mcImgMean.nii.gz --warp=${epiWarpDir}/T1toEPI_warp.nii.gz --interp=nn &&\
	fslmaths $snrDir/CSF_pve_to_RS.nii.gz -thr .99 -bin $snrDir/CSF_pve_to_RS_thresh.nii.gz &&\
	fslmeants -i $epiDataFilt -m $snrDir/CSF_pve_to_RS_thresh.nii.gz -o $preprocDir/rois/CSF_FAST_ts.txt --eig --order=5
else
	echo "no field map flag detected, using affine transform"
	clobber $preprocDir/rois/WM_FAST_ts.txt &&\
	flirt -in $segDir/T1_pve_2.nii.gz -ref ${epiDir}/mcImgMean.nii.gz -applyxfm -init ${epiWarpDir}/T1toEPI.mat -out $snrDir/WM_pve_to_RS.nii.gz -interp nearestneighbour &&\
	fslmaths $snrDir/WM_pve_to_RS.nii.gz -thr .99 -bin $snrDir/WM_pve_to_RS_thresh.nii.gz &&\
	fslmaths $snrDir/WM_pve_to_RS_thresh.nii.gz -kernel box 8 -ero $snrDir/WM_pve_to_RS_thresh_ero.nii.gz &&\
	fslmeants -i $epiDataFilt -m $snrDir/WM_pve_to_RS_thresh_ero.nii.gz -o $preprocDir/rois/WM_FAST_ts.txt --eig --order=5

	clobber $preprocDir/rois/GM_FAST_ts.txt &&\
	flirt -in $segDir/T1_pve_1.nii.gz -ref ${epiDir}/mcImgMean.nii.gz -applyxfm -init ${epiWarpDir}/T1toEPI.mat -out $snrDir/GM_pve_to_RS.nii.gz -interp nearestneighbour &&\
	fslmaths $snrDir/GM_pve_to_RS.nii.gz -thr .90 -bin $snrDir/GM_pve_to_RS_thresh.nii.gz -odt char &&\
	fslmeants -i $epiDataFilt -m $snrDir/GM_pve_to_RS_thresh.nii.gz -o $preprocDir/rois/GM_FAST_ts.txt

	clobber $preprocDir/rois/CSF_FAST_ts.txt &&\
	flirt -in $segDir/T1_pve_0.nii.gz -ref ${epiDir}/mcImgMean.nii.gz -applyxfm -init ${epiWarpDir}/T1toEPI.mat -out $snrDir/CSF_pve_to_RS.nii.gz -interp nearestneighbour &&\
	fslmaths $snrDir/CSF_pve_to_RS.nii.gz -thr .99 -bin $snrDir/CSF_pve_to_RS_thresh.nii.gz &&\
	fslmeants -i $epiDataFilt -m $snrDir/CSF_pve_to_RS_thresh.nii.gz -o $preprocDir/rois/CSF_FAST_ts.txt --eig --order=5
fi

clobber $snrDir/CSF_WM_mask.nii.gz &&\
fslmaths $snrDir/CSF_pve_to_RS_thresh.nii.gz -add $snrDir/WM_pve_to_RS_thresh.nii.gz $snrDir/CSF_WM_mask.nii.gz

clobber $snrDir/GM_mask.nii.gz &&\
fslmaths $epiDir/mcImgMean_mask -sub $snrDir/CSF_WM_mask.nii.gz -bin $snrDir/GM_mask.nii.gz -odt char

clobber $snrDir/GM_mask_final.nii.gz &&\
3dmerge -doall -prefix GM_mask_smooth.nii.gz -session $snrDir -1blur_fwhm 5 $snrDir/GM_mask.nii.gz -overwrite &&\
fslmaths $snrDir/GM_mask_smooth -add $snrDir/GM_mask.nii.gz -bin $snrDir/GM_mask_final.nii.gz -odt char

clobber $preprocDir/rois/GM_mask_ts.txt &&\
fslmeants -i $epiDataFilt -m $snrDir/GM_mask_final.nii.gz -o $preprocDir/rois/GM_mask_ts.txt


clobber $epiDir/powplot_mcImg_WM_mask.png &&\
${scriptDir}/PlotPow.sh -tr 2 $epiDataFilt $snrDir/WM_pve_to_RS_thresh_ero.nii.gz $epiDir/powplot_mcImg_WM_mask

clobber $epiDir/powplot_mcImg_CSF_mask.png &&\
${scriptDir}/PlotPow.sh -tr 2 $epiDataFilt $snrDir/CSF_pve_to_RS_thresh.nii.gz $epiDir/powplot_mcImg_CSF_mask

clobber $epiDir/powplot_mcImg_GM_FAST_mask.png &&\
${scriptDir}/PlotPow.sh -tr 2 $epiDataFilt $snrDir/GM_pve_to_RS_thresh.nii.gz $epiDir/powplot_mcImg_GM_FAST_mask

clobber $epiDir/powplot_mcImg_GM_mask_final.png &&\
${scriptDir}/PlotPow.sh -tr 2 $epiDataFilt $snrDir/GM_mask_final.nii.gz $epiDir/powplot_mcImg_GM_mask_final

#separate 5 eigenvectors into single files
for i in {1..5}; do
  for j in WM CSF; do
    rm $preprocDir/rois/${j}_FAST_${i}_ts.txt 2> /dev/null
    awk -v var="$i" '{print $var}' $preprocDir/rois/${j}_FAST_ts.txt > $preprocDir/rois/${j}_FAST_${i}_ts.txt
  done
done

nuisanceList="$(for i in {1..5}; do for j in WM CSF; do echo ${j}_FAST_${i};done;done) GM_FAST GM_mask"
> $epiDir/nuisance_rois.txt

for i in $nuisanceList; do
  echo $i >> $epiDir/nuisance_rois.txt
done

nuisanceroiList=$epiDir/nuisance_rois.txt
nuisanceCount=$(cat $nuisanceroiList | awk 'END {print NR}')
preprocfeat=preproc.feat
cd $epiDir

#### Calculate Nuisance Regressor time-series ############

# Create Regressors using Octave
echo "...Creating Regressors"
filename=run_normseedregressors.m;
cat > ${epiDir}/$filename << EOF

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
normseedregressors('${epiDir}',roiList,featdir,includemotion,0)
quit;
EOF

# Run script using Matlab or Octave
haveMatlab=`which matlab`
if [ "$haveMatlab" == "" ]; then
  octave --no-window-system $epiDir/$filename
else
  matlab -nodisplay -r "run $epiDir/$filename"
fi

#################################

#### Plotting Regressor time courses ######

echo "...Plotting Regressor time series"

for roi in $nuisanceList; do
  clobber $epiDir/${roi}_norm.png &&\
  fsl_tsplot -i $epiDir/tsregressorslp/${roi}_normalized_ts.txt -t "${roi} Time Series" -u 1 --start=1 -x 'Time Points (TR)' -w 800 -h 300 -o $epiDir/${roi}_norm.png
  echo "<br><br><img src=\"$epiDir/${roi}_norm.png\" alt=\"$roi nuisance regressor\"><br>" >> $epiDir/analysisResults.html
done

for i in CSF WM; do
  clobber $epiDir/${i}_regressors_ts_norm.png &&\
  pngappend $(find $epiDir -maxdepth 1 -type f -name "${i}_FAST*_norm.png" | tr '\n' '-' | sed -e 's|.png-/|.png - /|g' -e 's|.png-|.png|g') $epiDir/${i}_regressors_ts_norm.png
done

#################################


#### FEAT setup ############
echo "... FEAT setup"

cd $epiDir
logDir=$epiDir

#Set a few variables from data
  #epi_reg peDir setup (e.g. -y) is backwards from FEAT peDir (e.g. y-)
peDirBase=`cat $epiDir/rsParams | grep "peDir=" | tail -1 | awk -F"=" '{print $2}'`
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

dwellTimeBase=`cat $logDir/rsParams | grep "epiDwell=" | tail -1 | awk -F"=" '{print $2}'`
if [[ $dwellTimeBase == "" ]]; then
  dwellTime=0.00056
else
  dwellTime=$dwellTimeBase
fi

t1Data=`cat $logDir/rsParams | grep "^T1=" | tail -1 | awk -F"=" '{print $2}'`
te=`cat $logDir/rsParams | grep "epiTE=" | tail -1 | awk -F"=" '{print $2}'`
tr=`cat $logDir/rsParams | grep "epiTR=" | tail -1 | awk -F"=" '{print $2}'`

# cat $scriptDir/dummy_nuisance_compcor_wGMR.fsf | sed 's|SUBJECTPATH|'${epiDir}'|g' | \
#                                     sed 's|SUBJECTEPIPATH|'${epiDataFilt}'|g' | \
#                                     sed 's|SUBJECTT1PATH|'${t1Data}'|g' | \
#                                     sed 's|SCANTE|'${te}'|g' | \
#                                     sed 's|SUBJECTVOLS|'${numtimepoint}'|g' | \
#                                     sed 's|SUBJECTTR|'${tr}'|g' | \
#                                     sed 's|EPIDWELL|'${dwellTime}'|g' | \
#                                     sed 's|PEDIR|\'${peDirNEW}'|g' | \
#                                     sed 's|FSLDIR|'${FSLDIR}'|g' > ${epiDir}/${fsf}

cat $scriptDir/dummy_nuisance_compcor_5.0.10.fsf | sed 's|SUBJECTPATH|'${epiDir}'|g' | \
                                    sed 's|SUBJECTEPIPATH|'${epiDataFilt}'|g' | \
                                    sed 's|SUBJECTT1PATH|'${t1Data}'|g' | \
                                    sed 's|SCANTE|'${te}'|g' | \
																		sed 's|VOXTOT|'${epiVoxTot}'|g' | \
                                    sed 's|SUBJECTVOLS|'${numtimepoint}'|g' | \
                                    sed 's|SUBJECTTR|'${tr}'|g' | \
                                    sed 's|EPIDWELL|'${dwellTime}'|g' | \
                                    sed 's|PEDIR|\'${peDirNEW}'|g' | \
                                    sed 's|FSLDIR|'${FSLDIR}'|g' > ${epiDir}/${fsf2}

# cat $scriptDir/dummy_nuisance_compcor_wGMRv1.fsf | sed 's|SUBJECTPATH|'${epiDir}'|g' | \
#                                     sed 's|SUBJECTEPIPATH|'${epiDataFilt}'|g' | \
#                                     sed 's|SUBJECTT1PATH|'${t1Data}'|g' | \
#                                     sed 's|SCANTE|'${te}'|g' | \
#                                     sed 's|SUBJECTVOLS|'${numtimepoint}'|g' | \
#                                     sed 's|SUBJECTTR|'${tr}'|g' | \
#                                     sed 's|EPIDWELL|'${dwellTime}'|g' | \
#                                     sed 's|PEDIR|\'${peDirNEW}'|g' | \
#                                     sed 's|FSLDIR|'${FSLDIR}'|g' > ${epiDir}/${fsf3}
#
# cat $scriptDir/dummy_nuisance_classic_aroma.fsf | sed 's|SUBJECTPATH|'${epiDir}'|g' | \
#                                     sed 's|SUBJECTEPIPATH|'${epiDataFilt}'|g' | \
#                                     sed 's|SUBJECTT1PATH|'${t1Data}'|g' | \
#                                     sed 's|SCANTE|'${te}'|g' | \
#                                     sed 's|SUBJECTVOLS|'${numtimepoint}'|g' | \
#                                     sed 's|SUBJECTTR|'${tr}'|g' | \
#                                     sed 's|EPIDWELL|'${dwellTime}'|g' | \
#                                     sed 's|PEDIR|\'${peDirNEW}'|g' | \
#                                     sed 's|FSLDIR|'${FSLDIR}'|g' > ${epiDir}/nuisancereg_classic_aroma.fsf

#################################

#### FEAT Regression ######
#Run feat

#parallel --header : feat {fsf} ::: fsf $(for i in $nuisancefeat $nuisancefeat2 $nuisancefeat3; do if [ ! -f ${epiDir}/${i}/stats/res4d.nii.gz ]; then echo ${epiDir}/${i%.*}.fsf; fi; done)

# clobber ${epiDir}/nuisancereg_classic_aroma.feat/stats/res4d.nii.gz &&\
# feat ${epiDir}/nuisancereg_classic_aroma.fsf

clobber ${epiDir}/nuisancereg_compcor.feat/stats/res4d.nii.gz &&\
feat ${epiDir}/nuisancereg_compcor.fsf
#################################

#parallel --link --header : feat_regFix {in} $scriptDir $epiDir $epiVoxTot $te $numtimepoint $tr $dwellTime $peDirNEW {fsf} ::: in "${nuisancefeat}" "${nuisancefeat2}" "${nuisancefeat3}" ::: fsf "${epiDir}/${fsf}" "${epiDir}/${fsf2}" "${epiDir}/${fsf3}"
#parallel --header : dataScale {in} ::: in $epiDir/${nuisancefeat} $epiDir/${nuisancefeat2} $epiDir/${nuisancefeat3}

# feat_regFix nuisancereg_classic_aroma.feat $scriptDir $epiDir $epiVoxTot $te $numtimepoint $tr $dwellTime $peDirNEW "${epiDir}/nuisancereg_classic_aroma.fsf"
# dataScale $epiDir/nuisancereg_classic_aroma.feat

feat_regFix nuisancereg_compcor.feat $scriptDir $epiDir $epiVoxTot $te $numtimepoint $tr $dwellTime $peDirNEW "${epiDir}/nuisancereg_compcor.fsf"
dataScale $epiDir/nuisancereg_compcor.feat


# clobber $epiDir/nuisancereg_classic_aroma.feat/stats/res4d_normandscaled_motionscrubbed.nii &&\
# motionScrub $epiDir/RestingState.nii.gz nuisancereg_classic_aroma.feat

clobber $epiDir/nuisancereg_compcor.feat/stats/res4d_normandscaled_motionscrubbed.nii &&\
motionScrub $epiDir/RestingState.nii.gz nuisancereg_compcor.feat


for i in 1; do # 1=compcor, 2=compcor_wGMR, 3=compcor_wGMRv1, 4=classic_aroma, ""=classic

  ${scriptDir}/seedVoxelCorrelation.sh -E $epiDir/RestingState.nii.gz \
    -m 0 \
    -R ${roilist} \
    -f -n ${i}
done

#${scriptDir}/seedVoxelCorrelation.sh -E $epiDir/RestingState.nii.gz -m 0 \
#-R ${VossLabMount}/Projects/FAST/PreprocData/scripts/fast_crossx_seedlist_reproc.txt -n 4 -f
