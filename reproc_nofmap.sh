#!/bin/bash

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

function feat_regFix()
{
  local nuisancefeat="${1}"
  local scriptDir="${2}"
  local rsOut="${3}"
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

  #Remove all FEAT files (after backup), repopulate with proper files
  if [ -d $rsOut/${nuisancefeat}/reg ]; then
    echo "...Fixing FEAT registration QC images. ${nuisancefeat}"
    mv $regDir $rsOut/${nuisancefeat}/regORIG
		rm -r $rsOut/${nuisancefeat}/reg
  fi
	##Copy over appropriate reg directory from melodic.ica or preproc.feat processing
	rsync -a $rsOut/${preprocfeat}/reg $rsOut/${nuisancefeat}

  #NUISANCEDIR
  nuisanceDir=$rsOut/${nuisancefeat}
  local fsf_regFix="dummy_$(basename ${fsf} .fsf | sed 's/reg//')_regFix_5.0.10_argon.fsf"
  if [ -e ${scriptDir}/${fsf_regFix} ]; then
    #Backup original design file
    rsync -a $rsOut/${nuisancefeat}/design.fsf $rsOut/${nuisancefeat}/designORIG.fsf

    cat $scriptDir/${fsf_regFix} | sed 's|SUBJECTPATH|'${rsOut}'|g' | \
                                         sed 's|VOXTOT|'${epiVoxTot}'|g' | \
                                         sed 's|NUISANCEDIR|'${nuisanceDir}'|g' | \
                                         sed 's|SCANTE|'${te}'|g' | \
                                         sed 's|SUBJECTVOLS|'${numtimepoint}'|g' | \
                                         sed 's|SUBJECTTR|'${tr}'|g' | \
                                         sed 's|EPIDWELL|'${dwellTime}'|g' | \
                                         sed 's|PEDIR|\'${peDirNEW}'|g' | \
                                         sed 's|FSLDIR|'${FSLDIR}'|g' > ${fsf%.*}_regFix.fsf

      #Re-run feat
      if [ ! -e $rsOut/${nuisancefeat}/old/designORIG.fsf ]; then
        echo "...Rerunning FEAT (nuisancereg(post-stats only))"
        feat ${fsf%.*}_regFix.fsf

        #Log output to HTML file
        echo "<a href=\"$rsOut/${nuisancefeat}/report.html\">FSL Nuisance Regressor Results</a>" >> $rsOut/analysisResults.html
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
  cd $inDir/stats || exit

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

cd $indir || exit

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
echo "epiNormMS=${nuisancefeat}/stats/res4d_normandscaled_motionscrubbed.nii" >> $indir/rsParams

echo "<hr>" >> ${indir}/analysisResults.html
echo "<h2>Motion Scrubbing</h2>" >> ${indir}/analysisResults.html
echo "<b>Total Volumes</b>: $numvols<br>" >> ${indir}/analysisResults.html
echo "<b>Deleted Volumes</b>: $delvols<br>" >> ${indir}/analysisResults.html
echo "<b>Remaining Volumes</b>: $residvols<br>" >> ${indir}/analysisResults.html

scrubDataCheck=`cat $indir/$nuisancefeat/stats/deleted_vols.txt | head -1`
if [[ $scrubDataCheck != "" ]]; then
  echo "<b>Scrubbed TR</b>: `cat ${indir}/${nuisancefeat}/stats/deleted_vols.txt | awk '{$1=$1}1'`<br>" >> ${indir}/analysisResults.html
fi

#################################

echo "motionScrub Complete"
echo ""
echo ""
}


# inFile is denoised_func_data_nonaggr_bp
inFile=$1

bidsDir=${inFile//\/sub*} # bids directory e.g., /vosslabhpc/Projects/Bike_ATrain/Imaging/BIDS
subID="$(echo ${inFile} | grep -o "sub-[a-z0-9A-Z]*" | head -n 1 | sed -e "s|sub-||")" # gets subID from inFile
sesID="$(echo ${inFile} | grep -o "ses-[a-z0-9A-Z]*" | head -n 1 | sed -e "s|ses-||")" # gets sesID from inFile
subDir="${bidsDir}/sub-${subID}" # e.g., /vosslabhpc/Projects/Bike_ATrain/Imaging/BIDS/sub-GEA161
rsOut="${bidsDir}/derivatives/rsOut_legacy/sub-${subID}/${sesID}"
epiWarpDir=${rsOut}/EPItoT1optimized_nofmap
scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

epiDataFilt=${rsOut}/mcImg_smooth_denoised_bp.nii.gz
epiVoxTot=$(fslstats ${epiDataFilt} -v | awk '{print $1}')

# load variables needed for processing

MBA_dir="$(dirname "$(find ${bidsDir}/derivatives/MBA/sub-${subID}/${sesID} -type f -print -quit)")" # find dir containing MBA output
echo "subDir is ${subDir}."
echo "MBA_dir is ${MBA_dir}."

if [[ ! -d "${MBA_dir}" ]]; then
  echo "ERROR: MBA directory not found in derivatives. Exiting."
  exit 1
else
  T1_RPI="$(find ${subDir}/ses-*/anat -type f -name "sub-${subID}_ses*_T1w.nii.gz")"
  T1_RPI_brain="$(find ${subDir}/ses-*/anat -type f -name "sub-${subID}_ses*_T1w_brain.nii.gz")"
  T1_brain_mask="$(find ${MBA_dir} -type f -name "sub-${subID}_ses*_T1w_mask_60_smooth.nii.gz")"
  wmseg="$(find ${MBA_dir} -type f -name "T1_MNI_brain_wmseg.nii.gz")"
fi

if [ -z "${T1_RPI}" ] || [ -z "${T1_RPI_brain}" ] || [ -z "${inFile}" ]; then
  printf "\n%s\nERROR: at least one prerequisite scan is missing. Exiting.\n" "$(date)" 1>&2
  exit 1
fi

printf "\n%s\nRunning epi_reg without field maps...\n" "$(date)"
mkdir -p ${epiWarpDir}
cp ${wmseg} ${epiWarpDir}/EPItoT1_nofmap_wmseg.nii.gz

clobber ${epiWarpDir}/EPItoT1_nofmap.mat &&\
epi_reg --epi=${rsOut}/mcImgMean.nii.gz --t1=${T1_RPI} --t1brain=${T1_RPI_brain} --wmseg=${epiWarpDir}/EPItoT1_nofmap_wmseg.nii.gz --out=${epiWarpDir}/EPItoT1_nofmap --noclean -v >> ${epiWarpDir}/EPItoT1_nofmap.out

# Invert the affine registration (to get T1toEPI)
clobber ${epiWarpDir}/T1toEPI_nofmap.mat &&\
convert_xfm -omat ${epiWarpDir}/T1toEPI_nofmap.mat -inverse $epiWarpDir/EPItoT1_nofmap.mat

# Apply the inverted (T1toEPI) mat file to the brain mask
clobber ${rsOut}/mcImgMean_mask_nofmap.nii.gz &&\
flirt -in ${T1_brain_mask} -ref ${rsOut}/mcImgMean.nii.gz -applyxfm -init ${epiWarpDir}/T1toEPI_nofmap.mat -out ${rsOut}/mcImgMean_mask_nofmap.nii.gz -interp nearestneighbour -datatype char

# Create a stripped version of the EPI (mcImg) file, apply the mat file
clobber ${epiWarpDir}/EPIstrippedtoT1_nofmap.nii.gz &&\
fslmaths ${rsOut}/mcImgMean.nii.gz -mas ${rsOut}/mcImgMean_mask_nofmap.nii.gz ${rsOut}/mcImgMean_nofmap_stripped.nii.gz &&\
flirt -in ${rsOut}/mcImgMean_nofmap_stripped.nii.gz -ref ${T1_RPI_brain} -applyxfm -init ${epiWarpDir{}/EPItoT1_nofmap.mat -out ${epiWarpDir}/EPIstrippedtoT1_nofmap.nii.gz

# Sum the nonlinear warp (MNItoT1_warp.nii.gz) with the affine transform (T1toEPI.mat) to get a warp from MNI to EPI
clobber ${epiWarpDir}/MNItoEPI_nofmap_warp.nii.gz &&\
convertwarp --ref=${rsOut}/mcImgMean.nii.gz --warp1=${MBA_dir}/T1forWarp/MNItoT1_warp.nii.gz --postmat=${epiWarpDir}/T1toEPI_nofmap.mat --out=${epiWarpDir}/MNItoEPI_nofmap_warp.nii.gz --relout

# warping nuisance ROIs  #### Nuisance ROI mapping ############
echo "...Warping Nuisance ROIs to EPI space "


segDir="$(find ${MBA_dir} -type d -name "tissueSeg")"
snrDir=${rsOut}/SNR
preprocDir=${rsOut}/preproc.feat

# warp highres to EPI
clobber $preprocDir/rois/WM_FAST_nofmap_ts.txt &&\
flirt -in $segDir/T1_pve_2.nii.gz -ref ${inFile} -applyxfm -init ${epiWarpDir}/T1toEPI_nofmap.mat -out $snrDir/WM_pve_to_RS_nofmap.nii.gz -interp nearestneighbour &&\
fslmaths $snrDir/WM_pve_to_RS_nofmap.nii.gz -thr .99 -bin $snrDir/WM_pve_to_RS_nofmap_thresh.nii.gz &&\
fslmaths $snrDir/WM_pve_to_RS_nofmap_thresh.nii.gz -kernel box 8 -ero $snrDir/WM_pve_to_RS_nofmap_thresh_ero.nii.gz &&\
fslmeants -i $epiDataFilt -m $snrDir/WM_pve_to_RS_nofmap_thresh_ero.nii.gz -o $preprocDir/rois/WM_FAST_nofmap_ts.txt --eig --order=5

clobber $preprocDir/rois/CSF_FAST_nofmap_ts.txt &&\
flirt -in $segDir/T1_pve_0.nii.gz -ref ${inFile} -applyxfm -init ${epiWarpDir}/T1toEPI_nofmap.mat -out $snrDir/CSF_pve_to_RS_nofmap.nii.gz -interp nearestneighbour &&\
fslmaths $snrDir/CSF_pve_to_RS_nofmap.nii.gz -thr .99 -bin $snrDir/CSF_pve_to_RS_nofmap_thresh.nii.gz &&\
fslmeants -i $epiDataFilt -m $snrDir/CSF_pve_to_RS_nofmap_thresh.nii.gz -o $preprocDir/rois/CSF_FAST_nofmap_ts.txt --eig --order=5

# warp MNI rois to EPI
rois=("wmroi" "global" "latvent")
for roi in "${rois[@]}"; do
  clobber $preprocDir/rois/mean_"${roi}"_nofmap_ts.txt &&\
  applywarp --ref=${inFile} --in="${scriptDir}"/ROIs/"${roi}".nii.gz --out=$preprocDir/rois/"${roi}"_native_nofmap.nii.gz --warp="${epiWarpDir}/MNItoEPI_nofmap_warp.nii.gz" --datatype=float &&\
  fslmaths $preprocDir/rois/"${roi}"_native_nofmap.nii.gz -thr 0.5 $preprocDir/rois/"${roi}"_native_nofmap.nii.gz &&\
  fslmaths $preprocDir/rois/"${roi}"_native_nofmap.nii.gz -bin $preprocDir/rois/"${roi}"_native_nofmap.nii.gz &&\
  fslmeants -i "$epiDataFilt" -o $preprocDir/rois/mean_"${roi}"_nofmap_ts.txt -m $preprocDir/rois/"${roi}"_native_nofmap.nii.gz
done

# separate 5 eigenvectors into single files
for i in {1..5}; do
  for j in WM CSF; do
    rm $preprocDir/rois/${j}_FAST_nofmap_${i}_ts.txt 2> /dev/null
    awk -v var="$i" '{print $var}' $preprocDir/rois/${j}_FAST_nofmap_ts.txt > $preprocDir/rois/${j}_FAST_nofmap_${i}_ts.txt
  done
done


nuisanceList="$(for i in {1..5}; do for j in WM CSF; do echo ${j}_FAST_nofmap_${i};done;done) wmroi_nofmap global_nofmap latvent_nofmap"
> $rsOut/nuisance_rois.txt

for i in $nuisanceList; do
  echo $i >> $rsOut/nuisance_rois.txt
done

nuisanceroiList=$rsOut/nuisance_rois.txt
nuisanceCount=$(cat $nuisanceroiList | awk 'END {print NR}')
preprocfeat=preproc.feat
cd $rsOut || exit

#### Calculate Nuisance Regressor time-series ############

# Create Regressors using Octave
# output is *_normalized_ts.txt
echo "...Creating Regressors"
filename=run_normseedregressors.m;
cat > ${rsOut}/$filename << EOF

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
normseedregressors('${rsOut}',roiList,featdir,includemotion,0)
quit;
EOF

# Run script using Matlab or Octave
haveMatlab=$(which matlab)
if [ "$haveMatlab" == "" ]; then
  octave --no-window-system $rsOut/$filename
else
  matlab -nodisplay -r "run $rsOut/$filename"
fi

#################################

#### Plotting Regressor time courses ######

echo "...Plotting Regressor time series"

for roi in $nuisanceList; do
  clobber $rsOut/${roi}_norm.png &&\
  fsl_tsplot -i $rsOut/tsregressorslp/${roi}_normalized_ts.txt -t "${roi} Time Series" -u 1 --start=1 -x 'Time Points (TR)' -w 800 -h 300 -o $rsOut/${roi}_norm.png
  echo "<br><br><img src=\"$rsOut/${roi}_norm.png\" alt=\"$roi nuisance regressor\"><br>" >> $rsOut/analysisResults.html
done

for i in CSF WM; do
  clobber $rsOut/${i}_regressors_ts_norm.png &&\
  pngappend "$(find $rsOut -maxdepth 1 -type f -name "${i}_FAST_nofmap*_norm.png" | tr '\n' '-' | sed -e 's|.png-/|.png - /|g' -e 's|.png-|.png|g')" $rsOut/${i}_nofmap_regressors_ts_norm.png
done

#################################


#### FEAT setup ############
echo "... FEAT setup"

fsf=nuisancereg_nofmap.fsf
fsf2=nuisancereg_compcor_nofmap.fsf

cd $rsOut || exit

# Set a few variables from data
# epi_reg peDir setup (e.g. -y) is backwards from FEAT peDir (e.g. y-)
peDirBase=$(cat $rsOut/rsParams | grep "peDir=" | tail -1 | awk -F"=" '{print $2}')
if [[ $peDirBase == "" ]]; then
  peDirNEW="y-"
else
  peDirTmp1=$(echo $peDirBase | cut -c1)
  peDirTmp2=$(echo $peDirBase | cut -c2)
  if [[ "$peDirTmp1" == "-" ]]; then
    peDirNEW="${peDirTmp2}${peDirTmp1}"
  else
    peDirNEW="${peDirBase}"
  fi
fi

numtimepoint=$(fslinfo $epiDataFilt | grep ^dim4 | awk '{print $2}')

dwellTimeBase=$(cat ${rsOut}/rsParams | grep "epiDwell=" | tail -1 | awk -F"=" '{print $2}')
if [[ $dwellTimeBase == "" ]]; then
  dwellTime=0.00056
else
  dwellTime=$dwellTimeBase
fi

te=$(cat ${rsOut}/rsParams | grep "epiTE=" | tail -1 | awk -F"=" '{print $2}')
tr=$(cat ${rsOut}/rsParams | grep "epiTR=" | tail -1 | awk -F"=" '{print $2}')

sed -e "s|SUBJECTPATH|${rsOut}|g" \
-e "s|SUBJECTEPIPATH|${epiDataFilt}|g" \
-e "s|VOXTOT|${epiVoxTot}|g" \
-e "s|SUBJECTT1PATH|${T1_RPI_brain}|g" \
-e "s|SCANTE|${te}|g" \
-e "s|SUBJECTVOLS|${numtimepoint}|g" \
-e "s|SUBJECTTR|${tr}|g" \
-e "s|EPIDWELL|${dwellTime}|g" \
-e "s|PEDIR|${peDirNEW}|g" \
-e "s|FSLDIR|${FSLDIR}|g" "$scriptDir"/dummy_nuisance_nofmap_5.0.10.fsf > "${rsOut}"/"${fsf}"


sed -e "s|SUBJECTPATH|${rsOut}|g" \
-e "s|SUBJECTEPIPATH|${epiDataFilt}|g" \
-e "s|VOXTOT|${epiVoxTot}|g" \
-e "s|SUBJECTT1PATH|${T1_RPI_brain}|g" \
-e "s|SCANTE|${te}|g" \
-e "s|SUBJECTVOLS|${numtimepoint}|g" \
-e "s|SUBJECTTR|${tr}|g" \
-e "s|EPIDWELL|${dwellTime}|g" \
-e "s|PEDIR|${peDirNEW}|g" \
-e "s|FSLDIR|${FSLDIR}|g" "$scriptDir"/dummy_nuisance_compcor_nofmap_5.0.10.fsf > "${rsOut}"/"${fsf2}"

#################################

#### FEAT Regression ######
# Run feat


parallel --header : feat {fsf} ::: fsf $(for i in nuisancereg_compcor_nofmap.feat nuisancereg_nofmap.feat; do if [ ! -f ${rsOut}/${i}/stats/res4d.nii.gz ]; then echo ${rsOut}/${i%.*}.fsf; fi; done)

#################################


parallel --link --header : feat_regFix {in} $scriptDir $rsOut $epiVoxTot $te $numtimepoint $tr $dwellTime $peDirNEW {fsf} ::: in "nuisancereg_nofmap.feat" "nuisancereg_compcor_nofmap.feat" ::: fsf "${rsOut}/${fsf}" "${rsOut}/${fsf2}"

parallel --header : dataScale {in} ::: in $rsOut/nuisancereg_nofmap.feat $rsOut/nuisancereg_compcor_nofmap.feat


clobber $rsOut/nuisancereg_nofmap.feat/stats/res4d_normandscaled_motionscrubbed.nii &&\
motionScrub $rsOut/RestingState.nii.gz nuisancereg.feat

for i in nuisancereg_nofmap.feat nuisancereg_compcor_nofmap.feat; do
  ${scriptDir}/seedVoxelCorrelation.sh -E $rsOut/RestingState.nii.gz \
    -m 0 \
    -r /Shared/vosslabhpc/Projects/Bike_ATrain/Imaging/BIDS/derivatives/seeds/BIKE_ATRAIN_vmPFC_NAcc_amyg.nii.gz \
    -n ${i}
done
