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
scriptPath=$(perl -e 'use Cwd "abs_path";print abs_path(shift)' $0)
scriptDir=$(dirname $scriptPath)
knownNuisanceRois=$(ls -1 $scriptDir/ROIs/*nii* | awk -F"/" '{print $NF}' | awk -F"." '{print $1}')

SGE_ROOT='';export SGE_ROOT

function printCommandLine {
  echo "Usage: removeNuisanceRegressor.sh -E restingStateImage -A T1Image -n nuisanceROI -t tr -T te -H highpass -L lowpass -c"
  echo "            -OR-"
  echo "Usage: removeNuisanceRegressor.sh -E restingStateImage -A T1Image -n nuisanceROI -t tr -T te -H highpass -L lowpass -M -c"
  echo ""
  echo " where"
  echo "  -E Resting State file"
  echo "     *If using 'Classic' mode (no ICA Denoising), specify 'nonfiltered_func_data.nii.gz' from preproc.feat directory"
  echo "     *If using MELODIC/Denoising, use 'denoised_func_data.nii.gz' from melodic.ica directory"
  echo "  -A T1 file (skull-stripped)"
  echo "     *T1 should be from output of dataPrep script, EPI shoule be from output of ICA_denoise script"
  echo "  -n ROI for nuisance regression (can be used multiple times)"
  echo "     *e.g. -n global -n latvent -n wmroi"
  echo "  -N Data file with nuisance ROI list, one seed per line"
  echo "     **Use ONLY one option, -n or -N, NOT both"
  echo "  -L lowpass filter frequency (Hz) (e.g. 0.08 Hz (2.5 sigma))"
  echo "  -H highpass filter frequency (Hz) (e.g. 0.008 Hz (25.5 sigma / 120 s))"
  echo "    *If low/highpass filters are unset (or purposely set to both be '0'), the 0 and Nyquist frequencies will"
  echo "     still be removed (allpass filter)"
  echo "  -M highpass filter ONLY for Nuisance Regressors"
  echo "    *Set this flag ONLY if you ran a highpass filter on the EPI data during Melodic proceseing"
  echo "  -t TR time (seconds)"
  echo "  -T TE (milliseconds) (default to 30 ms)"
  echo "  -c clobber/overwrite previous results"
  echo ""
  echo "Existing nuisance ROIs:"
  echo "$knownNuisanceRois"
  exit 1
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

# Parse Command line arguments
while getopts "hE:A:n:N:L:H:Mt:T:c" OPTION
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
    n)
      nuisanceList=$(echo $nuisanceList $OPTARG)
      nuisanceInd=1
      ;;
    N)
      nuisanceList=$(cat $OPTARG)
      nuisanceInFile=$OPTARG
      ;;
    L)
      lowpassArg=$OPTARG
      ;;
    H)
      highpassArg=$OPTARG
      ;;
    M)
      highpassMelodic=1
      ;;
    t)
      tr=$OPTARG
      ;;
    T)
      te=$OPTARG
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





#Check for required input
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

for roi in $nuisanceList
do
  testRoi=$(echo $knownNuisanceRois | grep $roi)
  if [ "$testRoi" == "" ]; then
    echo "Error: Invalid Nuisance ROI specified (${roi})"
    echo "Valid Nuisance ROIs: $knownNuisanceRois"
    exit 1
  fi
done

if [[ "$nuisanceList" == "" ]]; then
  echo "Error: At least one Nuisance ROI must be specified using the -n options"
  exit 1
fi




# A few default parameters (if input not specified, these parameters are assumed)
if [[ $overwriteFlag == "" ]]; then
  overwriteFlag=0
fi

if [[ $tr == "" ]]; then
  tr=2
fi

if [[ $te == "" ]]; then
  te=30
fi

if [[ lowpassArg == "" ]]; then
  lowpassArg=0
fi

if [[ highpassArg == "" ]]; then
  highpassArg=0
fi

if [[ $highpassMelodic == "" ]]; then
  highpassMelodic=0
fi

# Vanilla settings for filtering: L=.08, H=.008

# Source input (~func) directory
indirTmp=$(dirname $epiData)
indir=$(dirname $indirTmp)
preprocfeat=$(echo $indirTmp | awk -F"/" '{print $NF}')
logDir=$indir

# Set flag depending on whether Melodic was run or not (to determine which directory to pull "reg" files from)
# "Classic" processing = nonfiltered_smooth_data.nii.gz ('nonfiltered')
# Melodic processing = denoised_func_data.nii.gz ('denoised')
epiBase=$(basename $epiData | awk -F"_" '{print $1}')
if [[ $epiBase == "denoised" ]]; then
  melFlag=1
fi

# If new nuisance regressors were added, echo them out to the rsParams file (only if they don't already exist in the file)
# Making a *strong* assumption that any nuisanceROI lists added after initial processing won't reuse the first ROI (e.g. pccrsp)
nuisanceTestBase=$(cat $logDir/rsParams | grep "nuisanceROI=" | awk -F"=" '{print $2}' | awk -F"-n " '{for (i=2; i<=NF; i++) print $i}')
nuisanceTest=$(echo $nuisanceTestBase | awk '{print $1}')
roiTest=$(echo $nuisanceList | awk '{print $1}')

for i in $nuisanceList
do
  nuisanceROI="$nuisanceROI -n $i"
done

if [[ "$nuisanceTest" != "$roiTest" ]]; then
  echo "nuisanceROI=$nuisanceROI" >> $logDir/rsParams
fi

# Echo out nuisance ROIs to a text file in input directory.

if [ -e $indir/nuisance_rois.txt ]; then
  rm $indir/nuisance_rois.txt
fi

for i in $nuisanceList
do
  echo $i >> $indir/nuisance_rois.txt
done

nuisanceroiList=$indir/nuisance_rois.txt
nuisanceCount=$(cat $nuisanceroiList | awk 'END {print NR}')

# Echo out all input parameters into a log
echo "$scriptPath" >> $logDir/rsParams_log
echo "------------------------------------" >> $logDir/rsParams_log
echo "-E $epiData" >> $logDir/rsParams_log
echo "-A $t1Data" >> $logDir/rsParams_log
if [[ $nuisanceInd == 1 ]]; then
  echo "$nuisanceROI" >> $logDir/rsParams_log
else
  echo "-N $nuisanceInFile" >> $logDir/rsParams_log
fi
echo "-L $lowpassArg" >> $logDir/rsParams_log
echo "-H $highpassArg" >> $logDir/rsParams_log
echo "-t $tr" >> $logDir/rsParams_log
echo "-T $te" >> $logDir/rsParams_log
if [[ $overwriteFlag == 1 ]]; then
  echo "-c" >> $logDir/rsParams_log
fi
echo "$(date)" >> $logDir/rsParams_log
echo "" >> $logDir/rsParams_log
echo "" >> $logDir/rsParams_log

# If user defines overwrite, note in rsParams file
if [[ $overwriteFlag == 1 ]]; then
  echo "_removeNuisanceRegressor_clobber" >> $logDir/rsParams
fi

echo "Running $0 ..."

roiList=$(echo $nuisanceList)

# Fix loop to remove directory and redo (if overWrite), first time processing, or echo with exit

cd $indir
if [[ -e ${nuisancefeat} ]]; then
  if [[ $overwriteFlag == 1 ]]; then
    # Cleanup of old files
    rm *_norm.png run_normseedregressors.m
    rm -rf nuisancereg.*
    rm -rf tsregressorslp

    # Re-run full analysis
    cd $indir/${preprocfeat}
    if [ ! -e rois ]; then
      mkdir rois
    fi

    # Check to see if Melodic highpass filtering had already been run.  Don't want to highpass filter the EPI data twice
    if [[ $highpassMelodic == 1 ]]; then
      # ONLY lowpass (or allpass) filtering possible for EPI

      #### Bandpass EPI Data With AFNI Tools, before nuisance regression ############
      # Vanilla settings for filtering: L=.08, H=.008 (2.5 sigma to 25.5 sigma / 120 s)
      # Since filtereing was removed from previous steps, a new file:
      # If filtering is set, filtered_func_data must be created
      # If filtering is not set, nonfiltered_func_data must be scaled by 1000
      echo "...Bandpass Filtering EPI data"

      if [ $lowpassArg == 0 ]; then
        # Allpass filter (only 0 and Nyquist frequencies are removed)
        # Scale data by 1000

        3dBandpass -prefix bandpass.nii.gz 0 99999 ${epiData}
        mv bandpass.nii.gz filtered_func_data.nii.gz
        fslmaths $indir/mcImgMean_mask.nii.gz -mul 1000 mask1000.nii.gz -odt float
        fslmaths filtered_func_data.nii.gz -add mask1000 filtered_func_data.nii.gz -odt float
        epiDataFilt=$indir/${preprocfeat}/filtered_func_data.nii.gz

        # Log filtered file
        echo "lowpassFilt=$lowpassArg" >> $logDir/rsParams
        echo "_allpassFilt" >> $logDir/rsParams
        echo "epiDataFilt=$epiDataFilt" >> $logDir/rsParams
      else
        # Filtering and scaling (lowpass)
        # Scale data by 1000

        3dBandpass -prefix bandpass.nii.gz 0 $lowpassArg ${epiData}
        mv bandpass.nii.gz filtered_func_data.nii.gz
        fslmaths $indir/mcImgMean_mask.nii.gz -mul 1000 mask1000.nii.gz -odt float
        fslmaths filtered_func_data.nii.gz -add mask1000 filtered_func_data.nii.gz -odt float
        epiDataFilt=$indir/${preprocfeat}/filtered_func_data.nii.gz

        # Log filtered file
        echo "lowpassFilt=$lowpassArg" >> $logDir/rsParams
        echo "epiDataFilt=$epiDataFilt" >> $logDir/rsParams
      fi

    else
      # Highpass filtering an option for EPI data

      #### Bandpass EPI Data With AFNI Tools, before nuisance regression ############
      # Vanilla settings for filtering: L=.08, H=.008 (2.5 sigma to 25.5 sigma / 120 s)
      # Since filtereing was removed from previous steps, a new file:
      # If filtering is set, filtered_func_data must be created
      # If filtering is not set, nonfiltered_func_data must be scaled by 1000
      echo "...Bandpass Filtering EPI data"

      if [ $lowpassArg == 0 ] && [ $highpassArg == 0 ]; then
        # Allpass filter (only 0 and Nyquist frequencies are removed)
        # Scale data by 1000

        3dBandpass -prefix bandpass.nii.gz 0 99999 ${epiData}
        mv bandpass.nii.gz filtered_func_data.nii.gz
        fslmaths $indir/mcImgMean_mask.nii.gz -mul 1000 mask1000.nii.gz -odt float
        fslmaths filtered_func_data.nii.gz -add mask1000 filtered_func_data.nii.gz -odt float
        epiDataFilt=$indir/${preprocfeat}/filtered_func_data.nii.gz

       # Log filtered file
        echo "lowpassFilt=$lowpassArg" >> $logDir/rsParams
        echo "highpassFilt=$highpassArg" >> $logDir/rsParams
        echo "_allpassFilt" >> $logDir/rsParams
        echo "epiDataFilt=$epiDataFilt" >> $logDir/rsParams
      else
        # Filtering and scaling (either lowpass, highpass or both)
        # Scale data by 1000

        3dBandpass -prefix bandpass.nii.gz $highpassArg $lowpassArg ${epiData}
        mv bandpass.nii.gz filtered_func_data.nii.gz
        fslmaths $indir/mcImgMean_mask.nii.gz -mul 1000 mask1000.nii.gz -odt float
        fslmaths filtered_func_data.nii.gz -add mask1000 filtered_func_data.nii.gz -odt float
        epiDataFilt=$indir/${preprocfeat}/filtered_func_data.nii.gz

        # Log filtered file
        echo "lowpassFilt=$lowpassArg" >> $logDir/rsParams
        echo "highpassFilt=$highpassArg" >> $logDir/rsParams
        echo "epiDataFilt=$epiDataFilt" >> $logDir/rsParams
      fi
    fi

    #################################


    #### Nuisance ROI mapping ############
    echo "...Warping Nuisance ROIs to EPI space"

    for roi in $roiList
    do
      echo "......Mapping nuisance regressor $roi"

      # Need to use warp from MNI to EPI from qualityCheck
      MNItoEPIwarp=$(cat $logDir/rsParams | grep "MNItoEPIWarp=" | tail -1 | awk -F"=" '{print $2}')
      applywarp --ref=$indir/mcImgMean_stripped.nii.gz --in=${scriptDir}/ROIs/${roi}.nii.gz --out=rois/${roi}_native.nii.gz --warp=$MNItoEPIwarp --datatype=float
      fslmaths rois/${roi}_native.nii.gz -thr 0.5 rois/${roi}_native.nii.gz
      fslmaths rois/${roi}_native.nii.gz -bin rois/${roi}_native.nii.gz
      fslmeants -i $epiDataFilt -o rois/mean_${roi}_ts.txt -m rois/${roi}_native.nii.gz
    done

    #################################


    #### FEAT setup ############
    echo "... FEAT setup"

    cd $indir

    # Set a few variables from data
    # epi_reg peDir setup (e.g. -y) is backwards from FEAT peDir (e.g. y-)
    peDirBase=$(cat $logDir/rsParams | grep "peDir=" | tail -1 | awk -F"=" '{print $2}')
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

    dwellTimeBase=$(cat $logDir/rsParams | grep "epiDwell=" | tail -1 | awk -F"=" '{print $2}')
    if [[ $dwellTimeBase == "" ]]; then
      dwellTime=0.00056
    else
      dwellTime=$dwellTimeBase
    fi

    epiVoxTot=$(fslstats ${epiDataFilt} -v | awk '{print $1}')

    cat $scriptDir/dummy_nuisance_5.0.10.fsf | sed 's|SUBJECTPATH|'${indir}'|g' | \
                                        sed 's|SUBJECTEPIPATH|'${epiDataFilt}'|g' | \
                                        sed 's|VOXTOT|'${epiVoxTot}'|g' | \
                                        sed 's|SUBJECTT1PATH|'${t1Data}'|g' | \
                                        sed 's|SCANTE|'${te}'|g' | \
                                        sed 's|SUBJECTVOLS|'${numtimepoint}'|g' | \
                                        sed 's|SUBJECTTR|'${tr}'|g' | \
                                        sed 's|EPIDWELL|'${dwellTime}'|g' | \
                                        sed 's|PEDIR|\'${peDirNEW}'|g' | \
                                        sed 's|FSLDIR|'${FSLDIR}'|g' > ${indir}/${fsf}

    #################################



    #### Calculate Nuisance Regressor time-series ############

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
      octave --no-window-system $indir/$filename
    else
      matlab -nodisplay -r "run $indir/$filename"
    fi


    echo "<hr><h2>Nuisance Regressors</h2>" >> $indir/analysisResults.html

    #################################



    #### Bandpass Motion Regressors ######

    echo "...Bandpass filtering Motion Regressors"


    if [ $lowpassArg != 0 ] || [ $highpassArg != 0 ]; then
      # Filtering ONLY if low/highpass don't both = 0
      mclist='1 2 3 4 5 6'
      for mc in ${mclist}
      do
          cp ${indir}/tsregressorslp/mc${mc}_normalized.txt ${indir}/tsregressorslp/mc${mc}_normalized.1D
          1dBandpass $highpassArg $lowpassArg ${indir}/tsregressorslp/mc${mc}_normalized.1D > ${indir}/tsregressorslp/mc${mc}_normalized_filt.1D
          cat ${indir}/tsregressorslp/mc${mc}_normalized_filt.1D > ${indir}/tsregressorslp/mc${mc}_normalized.txt
      done
    else
      # Passband filter
      mclist='1 2 3 4 5 6'
      for mc in ${mclist}
      do
          cp ${indir}/tsregressorslp/mc${mc}_normalized.txt ${indir}/tsregressorslp/mc${mc}_normalized.1D
          1dBandpass 0 99999 ${indir}/tsregressorslp/mc${mc}_normalized.1D > ${indir}/tsregressorslp/mc${mc}_normalized_filt.1D
          cat ${indir}/tsregressorslp/mc${mc}_normalized_filt.1D > ${indir}/tsregressorslp/mc${mc}_normalized.txt
      done
    fi

    #################################



    #### Plotting Regressor time courses ######

    echo "...Plotting Regressor time series"

    for roi in $roiList
    do
      fsl_tsplot -i $indir/tsregressorslp/${roi}_normalized_ts.txt -t "${roi} Time Series" -u 1 --start=1 -x 'Time Points (TR)' -w 800 -h 300 -o $indir/${roi}_norm.png
      echo "<br><br><img src=\"$indir/${roi}_norm.png\" alt=\"$roi nuisance regressor\"><br>" >> $indir/analysisResults.html
    done

    #################################



    #### FEAT Regression ######

    # Run feat
    echo "...Running FEAT (nuisancereg)"
    feat ${indir}/${fsf}
    #################################



    ###### FEAT registration correction ########################################

    echo "...Fixing FEAT registration QC images."

    # http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FEAT/FAQ
    # ss: "How can I insert a custom registration into a FEAT analysis?"

    regDir=$indir/${nuisancefeat}/reg

    # Remove all FEAT files (after backup), repopulate with proper files
    cp -r $regDir $indir/${nuisancefeat}/regORIG
    rm -rf $regDir

    # Copy over appropriate reg directory from melodic.ica or preproc.feat processing
      #If Melodic was run, copy over that version of the registration, otherwise use the portion from preprocessing
    if [[ $melFlag == 1 ]]; then
      # Melodic was used (-P 2)
      # Copy over "melodic" registration directory
      cp -r $indir/${melodicfeat}/reg $indir/${nuisancefeat}

    else
      # Melodic was not used (-P 2a)
      # Copy over "preproc" registration directory
      cp -r $indir/${preprocfeat}/reg $indir/${nuisancefeat}
    fi

    # Backup original design file
    cp $indir/${nuisancefeat}/design.fsf $indir/${nuisancefeat}/designORIG.fsf


    # Rerun FEAT to fix only post-stats portions (with no registrations)
    # VOXTOT
    epiVoxTot=$(fslstats ${epiDataFilt} -v | awk '{print $1}')

    # NUISANCEDIR
    nuisanceDir=$indir/${nuisancefeat}

    cat $scriptDir/dummy_nuisance_regFix_5.0.10.fsf | sed 's|SUBJECTPATH|'${indir}'|g' | \
                                               sed 's|VOXTOT|'${epiVoxTot}'|g' | \
                                               sed 's|NUISANCEDIR|'${nuisanceDir}'|g' | \
                                               sed 's|SCANTE|'${te}'|g' | \
                                               sed 's|SUBJECTVOLS|'${numtimepoint}'|g' | \
                                               sed 's|SUBJECTTR|'${tr}'|g' | \
                                               sed 's|EPIDWELL|'${dwellTime}'|g' | \
                                               sed 's|PEDIR|\'${peDirNEW}'|g' | \
                                               sed 's|FSLDIR|'${FSLDIR}'|g' > ${indir}/${fsf2}

    # Re-run feat
    echo "...Rerunning FEAT (nuisancereg(post-stats only)0"
    feat ${indir}/${fsf2}

    # Log output to HTML file
    echo "<a href=\"$indir/${nuisancefeat}/report.html\">FSL Nuisance Regressor Results</a>" >> $indir/analysisResults.html

    #################################



    ###### Post-FEAT data-scaling ########################################

    cd $indir/${nuisancefeat}/stats

    # Backup file
    echo "...Scaling data by 1000"
    cp res4d.nii.gz res4d_orig.nii.gz

    # For some reason, this mask isn't very good.  Use the good mask top-level
    echo "...Copy Brain mask"
    cp $indir/mcImgMean_mask.nii.gz mask.nii.gz
    fslmaths mask -mul 1000 mask1000 -odt float

    # normalize res4d here
    echo "...Normalize Data"
    fslmaths res4d -Tmean res4d_tmean
    fslmaths res4d -Tstd res4d_std
    fslmaths res4d -sub res4d_tmean res4d_dmean
    fslmaths res4d_dmean -div res4d_std res4d_normed
    fslmaths res4d_normed -add mask1000 res4d_normandscaled -odt float

    # Echo out final file to rsParams file
    echo "epiNorm=$indir/$nuisancefeat/stats/res4d_normandscaled.nii.gz" >> $logDir/rsParams

    #################################

  else
    echo "$0 has already been run use the -c option to overwrite results"
    exit
  fi
else
  # First run of analysis

  cd $indir/${preprocfeat}
  if [ ! -e rois ]; then
    mkdir rois
  fi

  # Check to see if Melodic highpass filtering had already been run.  Don't want to highpass filter the EPI data twice
  if [[ $highpassMelodic == 1 ]]; then
    # ONLY lowpass (or allpass) filtering possible for EPI

    #### Bandpass EPI Data With AFNI Tools, before nuisance regression ############
    # Vanilla settings for filtering: L=.08, H=.008 (2.5 sigma to 25.5 sigma / 120 s)
    # Since filtereing was removed from previous steps, a new file:
    # If filtering is set, filtered_func_data must be created
    # If filtering is not set, nonfiltered_func_data must be scaled by 1000
    echo "...Bandpass Filtering EPI data"

    if [ $lowpassArg == 0 ]; then
      # Allpass filter (only 0 and Nyquist frequencies are removed)
      # Scale data by 1000

      3dBandpass -prefix bandpass.nii.gz 0 99999 ${epiData}
      mv bandpass.nii.gz filtered_func_data.nii.gz
      fslmaths $indir/mcImgMean_mask.nii.gz -mul 1000 mask1000.nii.gz -odt float
      fslmaths filtered_func_data.nii.gz -add mask1000 filtered_func_data.nii.gz -odt float
      epiDataFilt=$indir/${preprocfeat}/filtered_func_data.nii.gz

      # Log filtered file
      echo "lowpassFilt=$lowpassArg" >> $logDir/rsParams
      echo "_allpassFilt" >> $logDir/rsParams
      echo "epiDataFilt=$epiDataFilt" >> $logDir/rsParams
    else
      # Filtering and scaling (lowpass)
      # Scale data by 1000

      3dBandpass -prefix bandpass.nii.gz 0 $lowpassArg ${epiData}
      mv bandpass.nii.gz filtered_func_data.nii.gz
      fslmaths $indir/mcImgMean_mask.nii.gz -mul 1000 mask1000.nii.gz -odt float
      fslmaths filtered_func_data.nii.gz -add mask1000 filtered_func_data.nii.gz -odt float
      epiDataFilt=$indir/${preprocfeat}/filtered_func_data.nii.gz

      # Log filtered file
      echo "lowpassFilt=$lowpassArg" >> $logDir/rsParams
      echo "epiDataFilt=$epiDataFilt" >> $logDir/rsParams
    fi

  else
    # Highpass filtering an option for EPI data

    #### Bandpass EPI Data With AFNI Tools, before nuisance regression ############
    # Vanilla settings for filtering: L=.08, H=.008 (2.5 sigma to 25.5 sigma / 120 s)
    # Since filtereing was removed from previous steps, a new file:
    # If filtering is set, filtered_func_data must be created
    # If filtering is not set, nonfiltered_func_data must be scaled by 1000
    echo "...Bandpass Filtering EPI data"

    if [ $lowpassArg == 0 ] && [ $highpassArg == 0 ]; then
      # Allpass filter (only 0 and Nyquist frequencies are removed)
      # Scale data by 1000

      3dBandpass -prefix bandpass.nii.gz 0 99999 ${epiData}
      mv bandpass.nii.gz filtered_func_data.nii.gz
      fslmaths $indir/mcImgMean_mask.nii.gz -mul 1000 mask1000.nii.gz -odt float
      fslmaths filtered_func_data.nii.gz -add mask1000 filtered_func_data.nii.gz -odt float
      epiDataFilt=$indir/${preprocfeat}/filtered_func_data.nii.gz

     # Log filtered file
      echo "lowpassFilt=$lowpassArg" >> $logDir/rsParams
      echo "highpassFilt=$highpassArg" >> $logDir/rsParams
      echo "_allpassFilt" >> $logDir/rsParams
      echo "epiDataFilt=$epiDataFilt" >> $logDir/rsParams
    else
      # Filtering and scaling (either lowpass, highpass or both)
      # Scale data by 1000

      3dBandpass -prefix bandpass.nii.gz $highpassArg $lowpassArg ${epiData}
      mv bandpass.nii.gz filtered_func_data.nii.gz
      fslmaths $indir/mcImgMean_mask.nii.gz -mul 1000 mask1000.nii.gz -odt float
      fslmaths filtered_func_data.nii.gz -add mask1000 filtered_func_data.nii.gz -odt float
      epiDataFilt=$indir/${preprocfeat}/filtered_func_data.nii.gz

      # Log filtered file
      echo "lowpassFilt=$lowpassArg" >> $logDir/rsParams
      echo "highpassFilt=$highpassArg" >> $logDir/rsParams
      echo "epiDataFilt=$epiDataFilt" >> $logDir/rsParams
    fi
  fi

  # Log Bandpass results
  echo "<hr><h2>Bandpass Filtering (Hz)</h2>" >> analysisResults.html
  echo "<b>Lowpass Filter</b>: ${lowpassArg}<br>" >> analysisResults.html
  echo "<b>Highpass Filter</b>: ${highpassArg}<br>" >> analysisResults.html

  #################################



  #### Nuisance ROI mapping ############
  echo "...Warping Nuisance ROIs to EPI space"

  for roi in $roiList
  do
    echo "......Mapping nuisance regressor $roi"

    # Need to use warp from MNI to EPI from qualityCheck
    MNItoEPIwarp=$(cat $logDir/rsParams | grep "MNItoEPIWarp=" | tail -1 | awk -F"=" '{print $2}')
    applywarp --ref=$indir/mcImgMean_stripped.nii.gz --in=${scriptDir}/ROIs/${roi}.nii.gz --out=rois/${roi}_native.nii.gz --warp=$MNItoEPIwarp --datatype=float
    fslmaths rois/${roi}_native.nii.gz -thr 0.5 rois/${roi}_native.nii.gz
    fslmaths rois/${roi}_native.nii.gz -bin rois/${roi}_native.nii.gz
    fslmeants -i $epiDataFilt -o rois/mean_${roi}_ts.txt -m rois/${roi}_native.nii.gz
  done

  #################################



  #### FEAT setup ############
  echo "... FEAT setup"

  cd $indir

  # Set a few variables from data
  # epi_reg peDir setup (e.g. -y) is backwards from FEAT peDir (e.g. y-)
  peDirBase=$(cat $logDir/rsParams | grep "peDir=" | tail -1 | awk -F"=" '{print $2}')
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

  dwellTimeBase=$(cat $logDir/rsParams | grep "epiDwell=" | tail -1 | awk -F"=" '{print $2}')
  if [[ $dwellTimeBase == "" ]]; then
    dwellTime=0.00056
  else
    dwellTime=$dwellTimeBase
  fi

  epiVoxTot=$(fslstats ${epiDataFilt} -v | awk '{print $1}')

  cat $scriptDir/dummy_nuisance_5.0.10.fsf | sed 's|SUBJECTPATH|'${indir}'|g' | \
                                      sed 's|SUBJECTEPIPATH|'${epiDataFilt}'|g' | \
                                      sed 's|SUBJECTT1PATH|'${t1Data}'|g' | \
                                      sed 's|VOXTOT|'${epiVoxTot}'|g' | \
                                      sed 's|SCANTE|'${te}'|g' | \
                                      sed 's|SUBJECTVOLS|'${numtimepoint}'|g' | \
                                      sed 's|SUBJECTTR|'${tr}'|g' | \
                                      sed 's|EPIDWELL|'${dwellTime}'|g' | \
                                      sed 's|PEDIR|\'${peDirNEW}'|g' | \
                                      sed 's|FSLDIR|'${FSLDIR}'|g' > ${indir}/${fsf}

  #################################



  #### Calculate Nuisance Regressor time-series ############

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
    octave --no-window-system $indir/$filename
  else
    matlab -nodisplay -r "run $indir/$filename"
  fi


  echo "<hr><h2>Nuisance Regressors</h2>" >> $indir/analysisResults.html

  #################################



  #### Bandpass Motion Regressors ######

  echo "...Bandpass filtering Motion Regressors"


    if [ $lowpassArg != 0 ] || [ $highpassArg != 0 ]; then
      # Filtering ONLY if low/highpass don't both = 0
      mclist='1 2 3 4 5 6'
      for mc in ${mclist}
      do
          cp ${indir}/tsregressorslp/mc${mc}_normalized.txt ${indir}/tsregressorslp/mc${mc}_normalized.1D
          1dBandpass $highpassArg $lowpassArg ${indir}/tsregressorslp/mc${mc}_normalized.1D > ${indir}/tsregressorslp/mc${mc}_normalized_filt.1D
          cat ${indir}/tsregressorslp/mc${mc}_normalized_filt.1D | awk '{print $1}' > ${indir}/tsregressorslp/mc${mc}_normalized.txt
      done
    else
      # Passband filter
      mclist='1 2 3 4 5 6'
      for mc in ${mclist}
      do
          cp ${indir}/tsregressorslp/mc${mc}_normalized.txt ${indir}/tsregressorslp/mc${mc}_normalized.1D
          1dBandpass 0 99999 ${indir}/tsregressorslp/mc${mc}_normalized.1D > ${indir}/tsregressorslp/mc${mc}_normalized_filt.1D
          cat ${indir}/tsregressorslp/mc${mc}_normalized_filt.1D | awk '{print $1}' > ${indir}/tsregressorslp/mc${mc}_normalized.txt
      done
    fi

  #################################



  #### Plotting Regressor time courses ######

  echo "...Plotting Regressor time series"

  for roi in $roiList
  do
    fsl_tsplot -i $indir/tsregressorslp/${roi}_normalized_ts.txt -t "${roi} Time Series" -u 1 --start=1 -x 'Time Points (TR)' -w 800 -h 300 -o $indir/${roi}_norm.png
    echo "<br><img src=\"$indir/${roi}_norm.png\" alt=\"$roi nuisance regressor\"><br>" >> $indir/analysisResults.html
  done

  #################################



  #### FEAT Regression ######

  # Run feat
  echo "...Running FEAT (nuisancereg)"
  echo "here"
  feat ${indir}/${fsf}
  #################################



  ###### FEAT registration correction ########################################

  echo "...Fixing FEAT registration QC images."

  # http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FEAT/FAQ
  # ss: "How can I insert a custom registration into a FEAT analysis?"

  regDir=$indir/${nuisancefeat}/reg

  # Remove all FEAT files (after backup), repopulate with proper files
  cp -r $regDir $indir/${nuisancefeat}/regORIG
  rm -rf $regDir


  # Copy over appropriate reg directory from melodic.ica or preproc.feat processing
  # If Melodic was run, copy over that version of the registration, otherwise use the portion from preprocessing
    if [[ $melFlag == 1 ]]; then
      # Melodic was used (-P 2)
      # Copy over "melodic" registration directory
      cp -r $indir/${melodicfeat}/reg $indir/${nuisancefeat}

    else
      # Melodic was not used (-P 2a)
      # Copy over "preproc" registration directory
      cp -r $indir/${preprocfeat}/reg $indir/${nuisancefeat}
    fi

  # Backup original design file
  cp $indir/${nuisancefeat}/design.fsf $indir/${nuisancefeat}/designORIG.fsf


  # Rerun FEAT to fix only post-stats portions (with no registrations)
  # VOXTOT
  epiVoxTot=$(fslstats ${epiDataFilt} -v | awk '{print $1}')

  # NUISANCEDIR
  nuisanceDir=$indir/${nuisancefeat}

  cat $scriptDir/dummy_nuisance_regFix_5.0.10.fsf | sed 's|SUBJECTPATH|'${indir}'|g' | \
                                             sed 's|VOXTOT|'${epiVoxTot}'|g' | \
                                             sed 's|NUISANCEDIR|'${nuisanceDir}'|g' | \
                                             sed 's|SCANTE|'${te}'|g' | \
                                             sed 's|SUBJECTVOLS|'${numtimepoint}'|g' | \
                                             sed 's|SUBJECTTR|'${tr}'|g' | \
                                             sed 's|EPIDWELL|'${dwellTime}'|g' | \
                                             sed 's|PEDIR|\'${peDirNEW}'|g' | \
                                             sed 's|FSLDIR|'${FSLDIR}'|g' > ${indir}/${fsf2}

  # Re-run feat
  echo "...Rerunning FEAT (nuisancereg (post-stats only))"
  feat ${indir}/${fsf2}

  # Log output to HTML file
  echo "<a href=\"$indir/${nuisancefeat}/report.html\">FSL Nuisance Regressor Results</a>" >> $indir/analysisResults.html

  #################################



  ###### Post-FEAT data-scaling ########################################

  cd $indir/${nuisancefeat}/stats

  # Backup file
  echo "...Scaling data by 1000"
  cp res4d.nii.gz res4d_orig.nii.gz

  # For some reason, this mask isn't very good.  Use the good mask top-level
  echo "...Copy Brain mask"
  cp $indir/mcImgMean_mask.nii.gz mask.nii.gz
  fslmaths mask -mul 1000 mask1000 -odt float

  # normalize res4d here
  echo "...Normalize Data"
  fslmaths res4d -Tmean res4d_tmean
  fslmaths res4d -Tstd res4d_std
  fslmaths res4d -sub res4d_tmean res4d_dmean
  fslmaths res4d_dmean -div res4d_std res4d_normed
  fslmaths res4d_normed -add mask1000 res4d_normandscaled -odt float

  # Echo out final file to rsParams file
  echo "epiNorm=$indir/$nuisancefeat/stats/res4d_normandscaled.nii.gz" >> $logDir/rsParams

  #################################

fi



echo "$0 Complete"
echo ""
echo ""
