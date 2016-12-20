#!/bin/bash

########################################################################
# Melodic ICA creation, possible highpass filtering, smoothing
#     1. Highpass filtering (if chosen).  Filter *should* be applied to nuisance regressors downstream		
#     2. Smoothing (conversion from mm to sigma)
#     4. ICA signal/noise classifiers
########################################################################

scriptPath=`perl -e 'use Cwd "abs_path";print abs_path(shift)' $0`
scriptDir=`dirname $scriptPath`
fsf=melodic.fsf
melodicDir=melodic.ica


function printCommandLine {
  echo "Usage: restingStateMelodic.sh -E restingStateImage -A T1Image -t tr -T te -s smooth -f -H highpass -c"
  echo ""
  echo "   where:"
  echo "   -E Resting State file (Motion-corrected), smoothed"
  echo "     *Should be the output from restingStateMelodic"
  echo "   -A T1 file"
  echo "     *T1 (skull-stripped) should be from output of dataPrep script"
  echo "     *EPI should be from output of qualityCheck script"
  echo "   -t TR time (seconds)"
  echo "     *Default is 2s"
  echo "   -T TE (milliseconds)"
  echo "     *Default is 30 ms"
  echo "   -s spatial smoothing filter size (mm)"
  echo "     *Default is 6"
  echo "   -f (fieldMap registration correction)"
  echo "     *Set this if FieldMap correction was used for BBR to properly update the FEAT registrations"
  echo "   -H highpass filter frequency (Hz) (e.g. 0.008 Hz (25.5 sigma / 120 s))"
  echo "     *If NOT set, no filter will be applied to the EPI data"
  echo "   -c option will overwrite previous results"
  exit 1
}



# Parse Command line arguements
while getopts “hE:A:H:t:T:s:fH:cv” OPTION
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
    t)
      tr=$OPTARG
      ;;
    T)
      te=$OPTARG
      ;;
    s)
      smooth=$OPTARG
      ;;
    f)
      fieldMapFlag=1
      ;;
    H)
      highpassArg=$OPTARG
      filterFlag=1
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




#Check for proper input, error with message if data is not found
if [ "$epiData" == "" ]; then
  echo "Error: The Motion-corrected restingStateImage (-E) is a required option"
  exit 1
fi

if [ "$t1Data" == "" ]; then
  echo "Error: The MNI-oriented T1 (-a) is a required option"
  exit 1
fi

if [ "$FSLDIR" == "" ]; then
  echo "Error: The Environmental variable FSLDIR must be set"
  exit 1
fi



#A few default parameters (if input not specified, these parameters are assumed)
if [[ $te == "" ]]; then
  te=30
fi

if [[ $tr == "" ]]; then
  tr=2
fi

if [[ $overwriteFlag == "" ]]; then
  overwriteFlag=0
fi

if [[ $smooth == "" ]]; then
  smooth=6
fi

if [[ $fieldMapFlag == "" ]]; then
  fieldMapFlag=0
fi

if [[ $filterFlag == "" ]]; then
  filterFlag=0
fi

if [[ $highpassArg == "" ]]; then
  highpassArg=0
fi


  


#Path setup
t1Dir=`dirname $t1Data`
t1name=`basename $t1Data`

epiDir=`dirname $epiData`
epiname=`basename $epiData`
epiDelimCount=`echo $epiname | awk -F"." '{print NF}' | awk -F"." '{print $1}'`
epiSuffix=`echo $epiname | awk -F"." -v var=$epiDelimCount '{print $var}'`  

#Source input (~func) directory
indir=$epiDir
logDir=$indir


#Set a few variables from data
dwellTimeBase=`cat $logDir/rsParams | grep "epiDwell=" | tail -1 | awk -F"=" '{print $2}'`
if [[ $dwellTimeBase == "" ]]; then
  dwellTime=0.00056
else
  dwellTime=$dwellTimeBase
fi

#epi_reg peDir setup (e.g. -y) is backwards from FEAT peDir (e.g. y-)
peDirBase=`cat $logDir/rsParams | grep "peDir=" | tail -1 | awk -F"=" '{print $2}'`
peDirTmp1=`echo $peDirBase | cut -c1`
peDirTmp2=`echo $peDirBase | cut -c2`
if [[ $peDirBase == "" ]]; then
  peDirNEW="y-"
else
  if [[ "$peDirTmp1" == "-" ]]; then
    peDirNEW="${peDirTmp2}${peDirTmp1}"
  else
    peDirNEW="${peDirBase}"
  fi
fi




##Echo out all input parameters into a log
echo "$scriptPath" >> $logDir/rsParams_log
echo "------------------------------------" >> $logDir/rsParams_log
echo "-E $epiData" >> $logDir/rsParams_log
echo "-A $t1Data" >> $logDir/rsParams_log
echo "-t $tr" >> $logDir/rsParams_log
echo "-T $te" >> $logDir/rsParams_log
echo "-s $smooth" >> $logDir/rsParams_log
if [[ $fieldMapFlag == 1 ]]; then
  echo "-f" >> $logDir/rsParams_log
fi
if [[ $filterFlag == 1 ]]; then
  echo "-H $highpassArg" >> $logDir/rsParams_log
fi
if [[ $overwriteFlag == 1 ]]; then
  echo "-c" >> $logDir/rsParams_log
fi
echo "`date`" >> $logDir/rsParams_log
echo "" >> $logDir/rsParams_log
echo "" >> $logDir/rsParams_log

#If user defines overwrite, note in rsParams file
if [[ $overwriteFlag == 1 ]]; then
  echo "_restingStateMelodic_clobber" >> $logDir/rsParams
fi





echo "Running $0 ..."





  #Check for overwrite permissions
  if [ -e $indir/${melodicDir} ]; then
      if [ $overwriteFlag == 1 ]; then

        #Overwrite the data
	rm -rf $indir/${melodicDir}

        ###Redo processing

        cd $indir

        ###### Highpass filter EPI data ############################################

        if [[ $filterFlag == 1 ]]; then
          echo "...Bandpass Filtering EPI data"
          #Filtering ONLY if highpass is set
            #Vanilla settings for filtering: L=.08, H=.008 (2.5 sigma to 25.5 sigma / 120 s)
              #Set ftop to 99999 to ensure that a highpass filter is run (ftop > Nyquist = highpass)

          3dBandpass -prefix bandpass_preMelodic.nii.gz $highpassArg 99999 ${epiData}

          #echo out a flag to rsParams (so as not to redo highpass with removeNuisanceRegressors)
          echo "highpassFiltMelodic=$highpassArg" >> $logDir/rsParams

          #Log Bandpass results
          echo "<hr><h2>Bandpass Filtering, Melodic (Hz)</h2>" >> analysisResults.html
          echo "<b>Highpass Filter</b>: ${highpassArg}<br>" >> analysisResults.html

        fi

        ################################################################



        ###### FEAT (melodic) ######################################################
        echo "...Running FEAT (melodic)"

        #Check to see if data has been highpass filtered
        if [[ $filterFlag == 1 ]]; then
          epiDataMel=$indir/bandpass_preMelodic.nii.gz
        else
          epiDataMel=$epiData
        fi

        #Set a few variables from data
        #epi_reg peDir setup (e.g. -y) is backwards from FEAT peDir (e.g. y-)
        peDirBase=`cat $logDir/rsParams | grep "peDir=" | tail -1 | awk -F"=" '{print $2}'`
        peDirTmp1=`echo $peDirBase | cut -c1`
        peDirTmp2=`echo $peDirBase | cut -c2`
        if [[ "$peDirTmp1" == "-" ]]; then
          peDirNEW="${peDirTmp2}${peDirTmp1}"
        else
          peDirNEW="${peDirBase}"
        fi

        numtimepoint=`fslinfo $epiData | grep ^dim4 | awk '{print $2}'`

        dwellTime=`cat $logDir/rsParams | grep "epiDwell=" | tail -1 | awk -F"=" '{print $2}'`


        cat $scriptDir/dummy_melodic.fsf | sed 's|SUBJECTPATH|'${epiDir}'|g'  | \
                                           sed 's|SUBJECTEPIPATH|'${epiDataMel}'|g' | \
                                           sed 's|SUBJECTT1PATH|'${t1Data}'|g' | \
                                           sed 's|SCANDWELL|'${dwellTime}'|g' | \
                                           sed 's|SCANTE|'${te}'|g' | \
                                           sed 's|SUBJECTVOLS|'${numtimepoint}'|g' | \
                                           sed 's|SUBJECTSMOOTH|'${smooth}'|g' | \
                                           sed 's|SUBJECTTR|'${tr}'|g' | \
                                           sed 's|FSLDIR|'${FSLDIR}'|g' | \
                                           sed 's|PEDIR|\'${peDirNEW}'|g' > ${epiDir}/${fsf}


        ### Run Feat
        feat $indir/${fsf}

  
        #Create a time-series mean of $epiData
        fslmaths $epiData -Tmean $indir/$melodicDir/mean_func.nii.gz

        #Binarize mean image and make a mask
        fslmaths $indir/$melodicDir/mean_func.nii.gz -bin $indir/$melodicDir/mask.nii.gz -odt char

        #Threshold output by mean mask, rename original data
        mv $indir/$melodicDir/filtered_func_data.nii.gz $indir/$melodicDir/filtered_func_data_orig.nii.gz
        fslmaths $indir/$melodicDir/filtered_func_data_orig.nii.gz -mul $indir/$melodicDir/mask.nii.gz $indir/$melodicDir/melodic_func_data.nii.gz

        ################################################################



        ###### FEAT registration correction ########################################
        echo "...Fixing FEAT registration QC images."

          #http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FEAT/FAQ
            #ss: "How can I insert a custom registration into a FEAT analysis?"

        regDir=$indir/$melodicDir/reg

        #Remove all FEAT files (after backup), repopulate with proper files
        cp -r $regDir $indir/$melodicDir/regORIG
        rm -f $regDir/*
    
        ##Copy over appropriate files from previous processing
        #T1 (highres)
        fslmaths $t1Data $regDir/highres.nii.gz
        t1toMNI=`cat $indir/rsParams | grep "T1toMNI=" | tail -1 | awk -F"=" '{print $2}'`
        fslmaths $t1toMNI $regDir/highres2standard.nii.gz

        #EPI (example_func)
        fslmaths $epiData $regDir/example_func.nii.gz
        epitoT1=`cat $indir/rsParams | grep "EPItoT1=" | tail -1 | awk -F"=" '{print $2}'`
        fslmaths $epitoT1 $regDir/example_func2highres.nii.gz
        epitoMNI=`cat $indir/rsParams | grep "EPItoMNI=" | tail -1 | awk -F"=" '{print $2}'`
        fslmaths $epitoMNI $regDir/example_func2standard.nii.gz

        #MNI (standard)
        fslmaths $FSLDIR/data/standard/avg152T1_brain.nii.gz $regDir/standard.nii.gz
    
        #Transforms
          #EPItoT1/T1toEPI (Check for presence of FieldMap Correction)
          epiWarpDirtmp=`cat $indir/rsParams | grep "EPItoT1Warp=" | tail -1 | awk -F"=" '{print $2}'`
            epiWarpDir=`dirname $epiWarpDirtmp`  

          if [[ $fieldMapFlag == 1 ]]; then
            #Copy the EPItoT1 warp file
            cp  $epiWarpDir/EPItoT1_warp.nii.gz $regDir/example_func2highres_warp.nii.gz
          else
            #Only copy the affine .mat files
            cp $epiWarpDir/EPItoT1_init.mat $regDir/example_func2initial_highres.mat
            cp $epiWarpDir/EPItoT1.mat $regDir/example_func2highres.mat    
          fi

          #T1toMNI
          T1WarpDirtmp=`cat $indir/rsParams | grep "MNItoT1IWarp=" | tail -1 | awk -F"=" '{print $2}'`
            T1WarpDir=`dirname $T1WarpDirtmp`

          cp $T1WarpDir/T1_to_MNIaff.mat $regDir/highres2standard.mat
          cp $T1WarpDir/coef_T1_to_MNI152.nii.gz $regDir/highres2standard_warp.nii.gz

          #EPItoMNI
          cp $epiWarpDir/EPItoMNI_warp.nii.gz $regDir/example_func2standard_warp.nii.gz


        #Forgoing "updatefeatreg" and just recreating the appropriate pics with slicer/pngappend
        cd $regDir

        #example_func2highres
        echo "......func2highres"
        slicer example_func2highres.nii.gz highres.nii.gz -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png
        pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png example_func2highres1.png

        slicer highres.nii.gz example_func2highres.nii.gz -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png
        pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png example_func2highres2.png

        pngappend example_func2highres1.png - example_func2highres2.png example_func2highres.png

        rm sl*.png
                                                                                                                                                                            
        #highres2standard
        echo "......highres2standard"
        slicer highres2standard.nii.gz standard.nii.gz -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png
        pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png highres2standard1.png

        slicer standard.nii.gz highres2standard.nii.gz -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png
        pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png highres2standard2.png

        pngappend highres2standard1.png - highres2standard2.png highres2standard.png

        rm sl*.png

        #example_func2standard
        echo "......func2standard"
        slicer example_func2standard.nii.gz standard.nii.gz -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png
        pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png example_func2standard1.png

        slicer standard.nii.gz example_func2standard.nii.gz -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png
        pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png example_func2standard2.png

        pngappend example_func2standard1.png - example_func2standard2.png example_func2standard.png

        rm sl*.png

        ################################################################



        ###### ICA Component Setup #################################################
        echo "....Setup for ICA Classification"

        cd $indir/${melodicDir}/filtered_func_data.ica

        ##Inserting sections from Chelsea Wong's (cwong26@illinois.edu) script, ICApreproc.
          #These sections attempt to classify the IC as either signal or noise and incorporate some of the previous steps
          #After running this script, the user then needs to load up the IC's in the matlab function, ICA_gui.m
          #Chelsea's ICA matlab script *should* run the denoising steps after IC signal/noise classification

          #Use output of MELODIC to attempt to manually classify signal and noise based on Kelly et. al. ("Visual Inspection of Independent Components: Defining a Procedure for Artifact Removal from fMRI Data (2010, Journal of Neuroscience Methods))
 

        repDir=$indir/${melodicDir}/filtered_func_data.ica/report
        zstatDir=$indir/${melodicDir}/filtered_func_data.ica/stats
        tissueDir=$t1Dir/tissueSeg
        outDir=$indir/${melodicDir}


        #Echo out name of MELODIC output (for use with ICA_denoise.sh)
        echo "epiMelodic=$indir/$melodicDir/melodic_func_data.nii.gz" >> $logDir/rsParams


        #Create a directory where IC's will be registered to the T1 (individual space) 
        mkdir $indir/${melodicDir}/filtered_func_data.ica/statsreg
        statsregDir=$indir/${melodicDir}/filtered_func_data.ica/statsreg
        cd $indir/${melodicDir}/filtered_func_data.ica/stats

        #Finding number of components
        comptmp=`ls | grep "thresh" | wc -l`
        components=`seq $comptmp`


        echo "Starting Component Activation Segmentation......"

        #Looping through IC's, thresholding to segmented tissue classes, determining non-brain signal
          #Check for FieldMap correction to apply warp or .mat from ICA to T1

        for c in $components; do
          #registering component thresh_zstat image to structural image

          #Look for EPItoT1
          epiWarpDirtmp=`cat $indir/rsParams | grep "EPItoT1Warp=" | tail -1 | awk -F"=" '{print $2}'`
            epiWarpDir=`dirname $epiWarpDirtmp`

          if [[ fieldMapFlag == 1 ]]; then
            #FieldMap correction wtih BBR, warp file 
            applywarp --ref=${t1Data} --in=$zstatDir/thresh_zstat${c}.nii.gz --out=$statsregDir/thresh_zstat${c}_hr.nii.gz --warp=$epiWarpDir/EPItoT1_warp.nii.gz --datatype=float --interp=trilinear
          else
            #No FieldMap correction, affine matrix
            flirt -in $zstatDir/thresh_zstat${c}.nii.gz -ref $t1Data -init $epiWarpDir/EPItoT1.mat -out $statsregDir/thresh_zstat${c}_hr.nii.gz -datatype float -applyxfm -interp trilinear
          fi


          #Loop through tissue classes
          for t in 0 1 2; do

            if [[ $t -eq 0 ]]; then
              tissue=csf
              tissOut=CSF
            elif [[ $t -eq 1 ]]; then
              tissue=gm
              tissOut=GM
            else
              tissue=wm
              tissOut=WM
            fi

            #segmenting registered component image by multiplying with segmented structural images
              #Tissue segmented files should be in /anat/tissueSeg directory

            fslmaths $statsregDir/thresh_zstat${c}_hr.nii.gz -mul $tissueDir/T1_seg_${t}.nii.gz $statsregDir/thresh_zstat${c}_hr_${tissue}.nii.gz

            #outputing number of active voxels above z=2.3 and total number of voxels to textfiles
            echo 'component' ${c} ${tissOut} `fslstats $statsregDir/thresh_zstat${c}_hr_${tissue}.nii.gz -l 2.3 -V` >>  $statsregDir/ICAsegact.txt
          done

          #Output voxels above z=2.3 for non-segmented IC
          echo 'component' ${c} 'combined' `fslstats $statsregDir/thresh_zstat${c}_hr.nii.gz -l 2.3 -V` >>  $statsregDir/ICAthreshact.txt

          #for matlab (ICA_gui.m)
          echo ${c} `fslstats $statsregDir/thresh_zstat${c}_hr_csf.nii.gz -l 2.3 -V` `fslstats $statsregDir/thresh_zstat${c}_hr_gm.nii.gz -l 2.3 -V` `fslstats $statsregDir/thresh_zstat${c}_hr_wm.nii.gz -l 2.3 -V` `fslstats $statsregDir/thresh_zstat${c}_hr.nii.gz -l 2.3 -V` >> $statsregDir/ICAsegact_MATLAB.txt
        done


        cat $statsregDir/ICAsegact_MATLAB.txt | awk '{print $1 "\t" ($2/$8)*100 "\t" ($4/$8)*100 "\t" ($6/$8)*100 "\t" 100-((($2/$8)*100)+(($4/$8)*100)+(($6/$8)*100))}'>> $statsregDir/segmented_percentact.txt     

        echo "......Done With Component Activation Segmentation"


        ##Threshold Frequency Powerspectrum
        echo "Starting Frequency Thresholding......"
  
        mkdir $indir/${melodicDir}/filtered_func_data.ica/freq_thresh
        freqDir=$indir/${melodicDir}/filtered_func_data.ica/freq_thresh

        #Determine number of Cylces for each IC
        numlines=`cat $repDir/f1.txt | wc -l`

        i=1
        while [[ $i -le $numlines ]]; do
          #Determine corresponding frequency for each Cycle:  1/((#Vols * TR)/Cyle)
            #e.g.  at cycle number 60:
              # 1/(120*2)/60 = 0.25 Hz
          Hzconv=`echo $i $tr $numtimepoint | awk '{print (1/(($2*$3)/$1))}'`
          echo ${Hzconv} >> $indir/${melodicDir}/filtered_func_data.ica/freq_thresh/Hzconv.txt
        let i+=1
        done

        #Look at Hzconv text file, apply threshold, determine corresponding cylce for cutoff below that threshold (applied to IC's later)
        thresh=0.1
        Hzcut=`cat $epiDir/${melodicDir}/filtered_func_data.ica/freq_thresh/Hzconv.txt | awk -v var=${thresh} '{if ($1 > var) print NR}' | head -1`

        #Determine # of ICs
        numFiles=`ls $repDir/f*txt | wc -l`
	    
        #Loop through each IC, threshold, determind prop of Frequency above cutoff	    
        j=1
        while [[ $j -le $numFiles ]]; do
          numlines=`cat $repDir/f${j}.txt | wc -l`
          cat $repDir/f${j}.txt | sed -n "${Hzcut},${numlines}p" >> $freqDir/f${j}_powerAboveThresh.txt
          totPower=`cat $repDir/f${j}.txt | awk '{ sum += $1 } END { print sum }'`
          threshPower=`cat $freqDir/f${j}_powerAboveThresh.txt | awk '{ sum += $1 } END { print sum }'`
          threshProp=`echo $threshPower $totPower | awk '{print (($1/$2)*100)}'`
          echo "${j} ${threshProp}" >> $freqDir/f_thresh.txt
        let j+=1
        done

        echo "......Done With Frequency Thresholding"



        #Copy over motion correction parameters (qualityCheck.sh), to be used as an underlay with ICA components during signal/noise determination
        mkdir $indir/${melodicDir}/filtered_func_data.ica/mc
        cp $indir/mcImg.par $indir/${melodicDir}/filtered_func_data.ica/mc/mcImg.par
        cp $indir/mcImg_abs.rms $indir/${melodicDir}/filtered_func_data.ica/mc/abs.rms
        cp $indir}/mcImg_rel.rms $indir/${melodicDir}/filtered_func_data.ica/mc/rel.rms

        ################################################################

      else
	  echo "$0 has already been run. Use the -c option to overwrite results"
	  exit 1
      fi
  else
    ##First instance of Melodic

    cd $indir

    ###### Highpass filter EPI data ############################################

    if [[ $filterFlag == 1 ]]; then
      echo "...Bandpass Filtering EPI data"
      #Filtering ONLY if highpass is set
        #Vanilla settings for filtering: L=.08, H=.008 (2.5 sigma to 25.5 sigma / 120 s)
          #Set ftop to 99999 to ensure that a highpass filter is run (ftop > Nyquist = highpass)

      3dBandpass -prefix bandpass_preMelodic.nii.gz $highpassArg 99999 ${epiData}

      #echo out a flag to rsParams (so as not to redo highpass with removeNuisanceRegressors)
      echo "highpassFiltMelodic=$highpassArg" >> $logDir/rsParams

      #Log Bandpass results
      echo "<hr><h2>Bandpass Filtering, Melodic (Hz)</h2>" >> analysisResults.html
      echo "<b>Highpass Filter</b>: ${highpassArg}<br>" >> analysisResults.html

    fi

    ################################################################



    ###### FEAT (melodic) ######################################################
    echo "...Running FEAT (melodic)"

    #Check to see if data has been highpass filtered
    if [[ $filterFlag == 1 ]]; then
      epiDataMel=$indir/bandpass_preMelodic.nii.gz
    else
      epiDataMel=$epiData
    fi

    #Set a few variables from data
    #epi_reg peDir setup (e.g. -y) is backwards from FEAT peDir (e.g. y-)
    peDirBase=`cat $logDir/rsParams | grep "peDir=" | tail -1 | awk -F"=" '{print $2}'`
    peDirTmp1=`echo $peDirBase | cut -c1`
    peDirTmp2=`echo $peDirBase | cut -c2`
    if [[ "$peDirTmp1" == "-" ]]; then
      peDirNEW="${peDirTmp2}${peDirTmp1}"
    else
      peDirNEW="${peDirBase}"
    fi

    numtimepoint=`fslinfo $epiData | grep ^dim4 | awk '{print $2}'`

    dwellTime=`cat $logDir/rsParams | grep "epiDwell=" | tail -1 | awk -F"=" '{print $2}'`


    cat $scriptDir/dummy_melodic.fsf | sed 's|SUBJECTPATH|'${epiDir}'|g'  | \
                                       sed 's|SUBJECTEPIPATH|'${epiDataMel}'|g' |  \
                                       sed 's|SUBJECTT1PATH|'${t1Data}'|g' | \
                                       sed 's|SCANDWELL|'${dwellTime}'|g' | \
                                       sed 's|SCANTE|'${te}'|g' | \
                                       sed 's|SUBJECTVOLS|'${numtimepoint}'|g' | \
                                       sed 's|SUBJECTSMOOTH|'${smooth}'|g' | \
                                       sed 's|SUBJECTTR|'${tr}'|g' | \
                                       sed 's|FSLDIR|'${FSLDIR}'|g' | \
                                       sed 's|PEDIR|\'${peDirNEW}'|g' > ${epiDir}/${fsf}


    ### Run Feat
    feat $indir/${fsf}

  
    #Create a time-series mean of $epiData
    fslmaths $epiData -Tmean $indir/$melodicDir/mean_func.nii.gz

    #Binarize mean image and make a mask
    fslmaths $indir/$melodicDir/mean_func.nii.gz -bin $indir/$melodicDir/mask.nii.gz -odt char

    #Threshold output by mean mask, rename original data
    mv $indir/$melodicDir/filtered_func_data.nii.gz $indir/$melodicDir/filtered_func_data_orig.nii.gz
    fslmaths $indir/$melodicDir/filtered_func_data_orig.nii.gz -mul $indir/$melodicDir/mask.nii.gz $indir/$melodicDir/melodic_func_data.nii.gz

    ################################################################



    ###### FEAT registration correction ########################################
    echo "...Fixing FEAT registration QC images."

      #http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FEAT/FAQ
        #ss: "How can I insert a custom registration into a FEAT analysis?"

    regDir=$indir/$melodicDir/reg

    #Remove all FEAT files (after backup), repopulate with proper files
    cp -r $regDir $indir/$melodicDir/regORIG
    rm -f $regDir/*
    
    ##Copy over appropriate files from previous processing
    #T1 (highres)
    fslmaths $t1Data $regDir/highres.nii.gz
    t1toMNI=`cat $indir/rsParams | grep "T1toMNI=" | tail -1 | awk -F"=" '{print $2}'`
    fslmaths $t1toMNI $regDir/highres2standard.nii.gz

    #EPI (example_func)
    fslmaths $epiData $regDir/example_func.nii.gz
    epitoT1=`cat $indir/rsParams | grep "EPItoT1=" | tail -1 | awk -F"=" '{print $2}'`
    fslmaths $epitoT1 $regDir/example_func2highres.nii.gz
    epitoMNI=`cat $indir/rsParams | grep "EPItoMNI=" | tail -1 | awk -F"=" '{print $2}'`
    fslmaths $epitoMNI $regDir/example_func2standard.nii.gz

    #MNI (standard)
    fslmaths $FSLDIR/data/standard/avg152T1_brain.nii.gz $regDir/standard.nii.gz
    
    #Transforms
      #EPItoT1/T1toEPI (Check for presence of FieldMap Correction)
      epiWarpDirtmp=`cat $indir/rsParams | grep "EPItoT1Warp=" | tail -1 | awk -F"=" '{print $2}'`
        epiWarpDir=`dirname $epiWarpDirtmp`  

      if [[ $fieldMapFlag == 1 ]]; then
        #Copy the EPItoT1 warp file
        cp  $epiWarpDir/EPItoT1_warp.nii.gz $regDir/example_func2highres_warp.nii.gz
      else
        #Only copy the affine .mat files
        cp $epiWarpDir/EPItoT1_init.mat $regDir/example_func2initial_highres.mat
        cp $epiWarpDir/EPItoT1.mat $regDir/example_func2highres.mat    
      fi

      #T1toMNI
      T1WarpDirtmp=`cat $indir/rsParams | grep "MNItoT1IWarp=" | tail -1 | awk -F"=" '{print $2}'`
        T1WarpDir=`dirname $T1WarpDirtmp`

      cp $T1WarpDir/T1_to_MNIaff.mat $regDir/highres2standard.mat
      cp $T1WarpDir/coef_T1_to_MNI152.nii.gz $regDir/highres2standard_warp.nii.gz

      #EPItoMNI
      cp $epiWarpDir/EPItoMNI_warp.nii.gz $regDir/example_func2standard_warp.nii.gz


    #Forgoing "updatefeatreg" and just recreating the appropriate pics with slicer/pngappend
    cd $regDir

    #example_func2highres
    echo "......func2highres"
    slicer example_func2highres.nii.gz highres.nii.gz -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png
    pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png example_func2highres1.png

    slicer highres.nii.gz example_func2highres.nii.gz -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png
    pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png example_func2highres2.png

    pngappend example_func2highres1.png - example_func2highres2.png example_func2highres.png

    rm sl*.png
                                                                                                                                                                            
    #highres2standard
    echo "......highres2standard"
    slicer highres2standard.nii.gz standard.nii.gz -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png
    pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png highres2standard1.png

    slicer standard.nii.gz highres2standard.nii.gz -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png
    pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png highres2standard2.png

    pngappend highres2standard1.png - highres2standard2.png highres2standard.png

    rm sl*.png

    #example_func2standard
    echo "......func2standard"
    slicer example_func2standard.nii.gz standard.nii.gz -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png
    pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png example_func2standard1.png

    slicer standard.nii.gz example_func2standard.nii.gz -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png
    pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png example_func2standard2.png

    pngappend example_func2standard1.png - example_func2standard2.png example_func2standard.png

    rm sl*.png

    ################################################################



    ###### ICA Component Setup #################################################
    echo "....Setup for ICA Classification"

    cd $indir/${melodicDir}/filtered_func_data.ica

    ##Inserting sections from Chelsea Wong's (cwong26@illinois.edu) script, ICApreproc.
      #These sections attempt to classify the IC as either signal or noise and incorporate some of the previous steps
      #After running this script, the user then needs to load up the IC's in the matlab function, ICA_gui.m
      #Chelsea's ICA matlab script *should* run the denoising steps after IC signal/noise classification

      #Use output of MELODIC to attempt to manually classify signal and noise based on Kelly et. al. ("Visual Inspection of Independent Components: Defining a Procedure for Artifact Removal from fMRI Data (2010, Journal of Neuroscience Methods))
 

    repDir=$indir/${melodicDir}/filtered_func_data.ica/report
    zstatDir=$indir/${melodicDir}/filtered_func_data.ica/stats
    tissueDir=$t1Dir/tissueSeg
    outDir=$indir/${melodicDir}


    #Echo out name of MELODIC output (for use with ICA_denoise.sh)
    echo "epiMelodic=$indir/$melodicDir/melodic_func_data.nii.gz" >> $logDir/rsParams


    #Create a directory where IC's will be registered to the T1 (individual space) 
    mkdir $indir/${melodicDir}/filtered_func_data.ica/statsreg
    statsregDir=$indir/${melodicDir}/filtered_func_data.ica/statsreg
    cd $indir/${melodicDir}/filtered_func_data.ica/stats

    #Finding number of components
    comptmp=`ls | grep "thresh" | wc -l`
    components=`seq $comptmp`


    echo "Starting Component Activation Segmentation......"

    #Looping through IC's, thresholding to segmented tissue classes, determining non-brain signal
      #Check for FieldMap correction to apply warp or .mat from ICA to T1

    for c in $components; do
      #registering component thresh_zstat image to structural image

      #Look for EPItoT1
      epiWarpDirtmp=`cat $indir/rsParams | grep "EPItoT1Warp=" | tail -1 | awk -F"=" '{print $2}'`
        epiWarpDir=`dirname $epiWarpDirtmp`

      if [[ fieldMapFlag == 1 ]]; then
        #FieldMap correction wtih BBR, warp file 
        applywarp --ref=${t1Data} --in=$zstatDir/thresh_zstat${c}.nii.gz --out=$statsregDir/thresh_zstat${c}_hr.nii.gz --warp=$epiWarpDir/EPItoT1_warp.nii.gz --datatype=float --interp=trilinear
      else
        #No FieldMap correction, affine matrix
        flirt -in $zstatDir/thresh_zstat${c}.nii.gz -ref $t1Data -init $epiWarpDir/EPItoT1.mat -out $statsregDir/thresh_zstat${c}_hr.nii.gz -datatype float -applyxfm -interp trilinear
      fi


      #Loop through tissue classes
      for t in 0 1 2; do

        if [[ $t -eq 0 ]]; then
          tissue=csf
          tissOut=CSF
        elif [[ $t -eq 1 ]]; then
          tissue=gm
          tissOut=GM
        else
          tissue=wm
          tissOut=WM
        fi

        #segmenting registered component image by multiplying with segmented structural images
          #Tissue segmented files should be in /anat/tissueSeg directory

        fslmaths $statsregDir/thresh_zstat${c}_hr.nii.gz -mul $tissueDir/T1_seg_${t}.nii.gz $statsregDir/thresh_zstat${c}_hr_${tissue}.nii.gz

        #outputing number of active voxels above z=2.3 and total number of voxels to textfiles
        echo 'component' ${c} ${tissOut} `fslstats $statsregDir/thresh_zstat${c}_hr_${tissue}.nii.gz -l 2.3 -V` >>  $statsregDir/ICAsegact.txt
      done

      #Output voxels above z=2.3 for non-segmented IC
      echo 'component' ${c} 'combined' `fslstats $statsregDir/thresh_zstat${c}_hr.nii.gz -l 2.3 -V` >>  $statsregDir/ICAthreshact.txt

      #for matlab (ICA_gui.m)
      echo ${c} `fslstats $statsregDir/thresh_zstat${c}_hr_csf.nii.gz -l 2.3 -V` `fslstats $statsregDir/thresh_zstat${c}_hr_gm.nii.gz -l 2.3 -V` `fslstats $statsregDir/thresh_zstat${c}_hr_wm.nii.gz -l 2.3 -V` `fslstats $statsregDir/thresh_zstat${c}_hr.nii.gz -l 2.3 -V` >> $statsregDir/ICAsegact_MATLAB.txt
    done


    cat $statsregDir/ICAsegact_MATLAB.txt | awk '{print $1 "\t" ($2/$8)*100 "\t" ($4/$8)*100 "\t" ($6/$8)*100 "\t" 100-((($2/$8)*100)+(($4/$8)*100)+(($6/$8)*100))}'>> $statsregDir/segmented_percentact.txt     

    echo "......Done With Component Activation Segmentation"


    ##Threshold Frequency Powerspectrum
    echo "Starting Frequency Thresholding......"
  
    mkdir $indir/${melodicDir}/filtered_func_data.ica/freq_thresh
    freqDir=$indir/${melodicDir}/filtered_func_data.ica/freq_thresh

    #Determine number of Cylces for each IC
    numlines=`cat $repDir/f1.txt | wc -l`

    i=1
    while [[ $i -le $numlines ]]; do
      #Determine corresponding frequency for each Cycle:  1/((#Vols * TR)/Cyle)
        #e.g.  at cycle number 60:
          # 1/(120*2)/60 = 0.25 Hz
      Hzconv=`echo $i $tr $numtimepoint | awk '{print (1/(($2*$3)/$1))}'`
      echo ${Hzconv} >> $indir/${melodicDir}/filtered_func_data.ica/freq_thresh/Hzconv.txt
    let i+=1
    done

    #Look at Hzconv text file, apply threshold, determine corresponding cylce for cutoff below that threshold (applied to IC's later)
    thresh=0.1
    Hzcut=`cat $epiDir/${melodicDir}/filtered_func_data.ica/freq_thresh/Hzconv.txt | awk -v var=${thresh} '{if ($1 > var) print NR}' | head -1`

    #Determine # of ICs
    numFiles=`ls $repDir/f*txt | wc -l`
	    
    #Loop through each IC, threshold, determind prop of Frequency above cutoff	    
    j=1
    while [[ $j -le $numFiles ]]; do
      numlines=`cat $repDir/f${j}.txt | wc -l`
      cat $repDir/f${j}.txt | sed -n "${Hzcut},${numlines}p" >> $freqDir/f${j}_powerAboveThresh.txt
      totPower=`cat $repDir/f${j}.txt | awk '{ sum += $1 } END { print sum }'`
      threshPower=`cat $freqDir/f${j}_powerAboveThresh.txt | awk '{ sum += $1 } END { print sum }'`
      threshProp=`echo $threshPower $totPower | awk '{print (($1/$2)*100)}'`
      echo "${j} ${threshProp}" >> $freqDir/f_thresh.txt
    let j+=1
    done

    echo "......Done With Frequency Thresholding"



    #Copy over motion correction parameters (qualityCheck.sh), to be used as an underlay with ICA components during signal/noise determination
    mkdir $indir/${melodicDir}/filtered_func_data.ica/mc
    cp $indir/mcImg.par $indir/${melodicDir}/filtered_func_data.ica/mc/mcImg.par
    cp $indir/mcImg_abs.rms $indir/${melodicDir}/filtered_func_data.ica/mc/abs.rms
    cp $indir/mcImg_rel.rms $indir/${melodicDir}/filtered_func_data.ica/mc/rel.rms

    ################################################################

  fi




###################RUN PART II########################################




  echo "$0 Complete"
  echo "Please check output ICs in $indir/${melodicDir} and classify as either signal or noise (use the matlab program: ICA_gui)"
  echo "   use: $scriptDir/runICAgui.sh"
  echo ""
  echo ""



