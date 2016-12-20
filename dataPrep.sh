#!/bin/bash

##################################################################################################################
# Data Preparation (extraction, orientation, naming) And Other inital processing for Resting State Analysis
#     1. T1 (Skull)		
#     2. T1 (skull-stripped)
#     3. EPI
#  ##Optional####
#     4. FieldMap (Phase)
#     5. FieldMap (Magnitude)
#     6. Field Map prepped (combination of Phase/Magnitude images)
##################################################################################################################

scriptPath=`perl -e 'use Cwd "abs_path";print abs_path(shift)' $0`
scriptDir=`dirname $scriptPath`


function printCommandLine {
  echo ""
  echo "Usage: dataPrep.sh -i datafile -o outputDirectory -c -t TR -T TE -f -F 2.46"
  echo ""
  echo "   where:"
  echo "   -i Data file having a space-separated list of anatomical and epi images"
  echo "         *Text file with five possible entries:"
  echo "           1) T1 (with skull)"
  echo "           2) T1 (skull-stripped)"
  echo "           3) EPI image"
  echo "        ##Optional########"
  echo "           4) fieldMap: Phase image"
  echo "           5) fieldMap: Magnitude image"
  echo ""
  echo "   -o output directory (will create /anat for T1 data, /func for EPI data) (default is to write to EPI input directory)"
  echo "   -c clobber/overwrite previous results"
  echo "   -t TR (seconds) (default to 2 s)"
  echo "   -T TE (milliseconds) (default to 30 ms)"
  echo "   -f Prepare fieldMaps for use with BBR"
  echo "   -F deltaTE of the fieldMap (in s) (default to 2.46 s)"
  echo "         *This scan be obtained from the difference in TE between the Phase and Magnitude images"
  echo "           e.g.:, TE(Phase)=2550, TE(Mag)=5010; deltaTE=2460 m (2.46s)"
  echo "       **If using DICOM as input for the FieldMap data, delaTE will be calculated from the header information."
  echo ""
  echo ""
  echo "     A few notes:"
  echo "       *If fieldMap correction is to be run, you must ALSO run the '-f' flag"  
  echo "       *The T1 files MUST be in NIFTI format"
  echo "         ** The skull-stripped file will be renamed T1_MNI_brain.  The image with skull will be renamed T1_MNI." 
  echo "       *If EPI is in DICOM format, it will be converted to NIFTI.  If already NIFTI, it will be checked for"
  echo "        naming convention and orientation."
  echo "       *TR, deltaTE will be sourced from DICOM header (will overwrite flag-settings)."
  echo ""
  exit 1
}



# Parse Command line arguments
while getopts “hi:o:t:T:fF:c” OPTION
do
  case $OPTION in
    h)
      printCommandLine
      ;;
    i)
      datafile=`perl -e 'use Cwd "abs_path";print abs_path(shift)' $OPTARG`
      ;;
    o)
      outDir=$OPTARG
      outFlag=1
      ;;
    t)
      tr=$OPTARG
      ;;
    T)
      te=$OPTARG
      ;;
    f)
      fieldMapFlag=1
      ;;
    F)
      deltaTE=$OPTARG
      ;;
    c)
      overwriteFlag=1
      ;;
    ?)
      printCommandLine
      ;;
     esac
done




#Quick check for input data.  Exit with error if data is missing
if [[ $datafile == "" ]]; then
  echo "Error: data file must be specified with the -i option"
  exit 1
fi



#Check for output directory flag and sub-directory creation if this is set
if [[ $outDir != "" ]]; then
  if [ ! -e $outDir/func ]; then
    mkdir -p $outDir/func
  fi
  if [ ! -e $outDir/anat ]; then
    mkdir -p $outDir/anat
  fi
  if [[ $fieldMapFlag == 1 ]]; then
    if [ ! -e $outDir/fieldMap ]; then
      mkdir -p $outDir/fieldMap
    fi
    if [ ! -e $outDir/func/EPItoT1optimized ]; then
      mkdir -p $outDir/func/EPItoT1optimized
    fi
  fi
fi



  #A few default parameters (if input not specified, these parameters are assumed)
  if [[ $overwriteFlag == "" ]]; then
    overwriteFlag=0
  fi

  if [[ $outFlag == "" ]]; then
    outFlag=0
  fi

  if [[ $tr == "" ]]; then
    tr=2
  fi

  if [[ $deltaTE == "" ]]; then
    deltaTE=2.46
  fi


#Assuming TR is entered as seconds (defualt is 2), for input to AFNI's "to3D"
trMsec=`echo $tr 1000 | awk '{print $1*$2}'`


echo "Running $0 ..."
 

index=1

#Eliminating the loop.  Making is so that only ONE subject can be in the "-i" datafile

#while [ 1 ]
#do

  ###### Basic Input/variables ########################################

  #Input files
  t1Skull=`sed -n "${index}p" $datafile | awk '{print $1}'`
  t1=`sed -n "${index}p" $datafile | awk '{print $2}'`
  epi=`sed -n "${index}p" $datafile | awk '{print $3}'`  
  if [[ $fieldMapFlag == 1 ]]; then
    fieldMapPhase=`sed -n "${index}p" $datafile | awk '{print $4}'`
    fieldMapMag=`sed -n "${index}p" $datafile | awk '{print $5}'`
  fi

  #Checking for appropriate input data
  if [ "$t1Skull" == "" ]; then
    echo "T1 (with skull) must be set in order to run this script."
    exit 1
  fi

  if [ "$t1" == "" ]; then
    echo "T1 (skull-stripped) must be set in order to run this script."
    exit 1
  fi

  if [ "$epi" == "" ]; then
    echo "EPI must be set in order to run this script."
    exit 1
  fi

  if [[ $fieldMapFlag == 1 ]]; then
    if [ "$fieldMapPhase" == "" ]; then
      echo "FieldMap (Phase) must be set in order to run this script."
      exit 1
    fi

    if [ "$fieldMapMag" == "" ]; then
      echo "FieldMap (Magnitude) must be set in order to run this script."
      exit 1
    fi
  fi




  
  #Base directory for input EPI, T1 & FieldMap
  epiDir=`dirname $epi`

  t1SkullDir=`dirname $t1Skull`
  t1Skullname=`basename $t1Skull`

  t1Dir=`dirname $t1`
  t1name=`basename $t1`

  if [[ $fieldMapFlag == 1 ]]; then

    fieldMapPhaseDir=`dirname $fieldMapPhase`
    fieldMapPhasename=`basename $fieldMapPhase`

    fieldMapMagDir=`dirname $fieldMapMag`
    fieldMapMagname=`basename $fieldMapMag`
  fi


  ##Echo out all input parameters into a log
  if [[ "$outDir" != "" ]]; then
    epiOutDirTEMP=$outDir/func    
  else
    epiOutDirTEMP=$epiDir  
  fi
  logDir=$epiOutDirTEMP
  echo "$scriptPath" >> $logDir/rsParams_log
  echo "------------------------------------" >> $logDir/rsParams_log
  echo "-i $datafile" >> $logDir/rsParams_log
  if [[ $outFlag == 1 ]]; then
    echo "-o $outDir" >> $logDir/rsParams_log
  fi
  if [[ $overwriteFlag == 1 ]]; then
    echo "-c" >> $logDir/rsParams_log
  fi
  echo "-t $tr" >> $logDir/rsParams_log  
  if [[ $fieldMapFlag == 1 ]]; then
    echo "-f" >> $logDir/rsParams_log
    echo "-F $deltaTE" >> $logDir/rsParams_log
  fi
  echo "`date`" >> $logDir/rsParams_log
  echo "" >> $logDir/rsParams_log
  echo "" >> $logDir/rsParams_log


  #Directory for processed EPI/T1/FieldMap
  if [[ "$outDir" != "" ]]; then
    epiOutDir=$outDir/func
    t1OutDir=$outDir/anat
    t1SkullOutDir=$outDir/anat
    if [[ $fieldMapFlag == 1 ]]; then
      fieldMapPhaseOutDir=$outDir/fieldMap
      fieldMapMagOutDir=$outDir/fieldMap
    fi
  else
    epiOutDir=$epiDir
    t1OutDir=$t1Dir
    t1SkullOutDir=$t1SkullDir
    if [[ $fieldMapFlag == 1 ]]; then
      fieldMapPhaseOutDir=$fieldMapPhaseDir
      fieldMapMagOutDir=$fieldMapMagDir
    fi
    outDir=$epiDir   
  fi


  #Place where bulk of donwstream processing will be saved to
  resultsDir=$epiOutDir

  #Saving variables for logging and for donwstream processing
  if [[ $overwriteFlag == 1 ]]; then
    echo "_dataPrep_clobber" >> $resultsDir/rsParams
  fi

  echo "resultsDir=$resultsDir" >> $resultsDir/rsParams

  ################################################################
  




  ###### T1 (Skull) ########################################

  #Begin processing T1Skull
  echo ""
  echo ""
  echo "....Preparing T1Skull data"
  echo ""
  echo ""  

  echo "Reorienting T1Skull to RPI"
  if [[ ! -e $t1SkullOutDir/FSLORIENT/T1_MNI.nii.gz ]]; then
    ##File doesn't exist
    if [[ ! -e $t1SkullOutDir/FSLORIENT ]]; then
      mkdir $t1SkullOutDir/FSLORIENT
    fi

    cd $t1SkullOutDir/FSLORIENT

    if [[ ! -e ${t1Skullname%.nii.gz}_MNI.nii.gz ]]; then
      cp $t1SkullDir/${t1Skullname} $t1SkullOutDir/FSLORIENT/tmpT1Skull.nii.gz
      #Convert to RPI orientation - call upon an external FSL reorienting script
      $scriptDir/fslreorient.sh tmpT1Skull.nii.gz
      mv tmpT1Skull_MNI.nii.gz T1_MNI.nii.gz

      if [[ $outFlag == 1 ]]; then
        cp T1_MNI.nii.gz $t1SkullOutDir
        cd $t1SkullOutDir
        rm -rf $t1SkullOutDir/FSLORIENT
      else
        t1SkullOutDir=$t1SkullOutDir/FSLORIENT
        rm $t1SkullOutDir/tmpT1Skull.nii.gz
        cd $t1SkullOutDir
      fi

    else        
      #Convert to RPI orientation - call upon an external FSL reorienting script
      $scriptDir/fslreorient.sh ${t1Skullname%.nii.gz}_MNI.nii.gz
      t1SkullOutDir=$t1SkullOutDir/FSLORIENT
    fi

    #Saving variables for logging and for donwstream processing
    echo "t1Skull=$t1SkullOutDir/T1_MNI.nii.gz" >> $resultsDir/rsParams
      
  else
    ##If user set overwrite (-c), overwrite previous file (file already exists)
    if [[ $overwriteFlag == 1 ]]; then
      if [[ ! -e $t1SkullOutDir/FSLORIENT ]]; then
        mkdir $t1SkullOutDir/FSLORIENT
      fi

      cd $t1SkullOutDir/FSLORIENT        
      cp $t1SkullOutDir/${t1Skullname} $t1SkullOutDir/FSLORIENT/tmpT1Skull.nii.gz

      #Convert to RPI orientation - call upon an external FSL reorienting script
      $scriptDir/fslreorient.sh tmpT1Skull.nii.gz
      mv tmpT1Skull_MNI.nii.gz T1_MNI.nii.gz

      if [[ $outFlag == 1 ]]; then
        cp T1_MNI.nii.gz $t1SkullOutDir
        rm -rf $t1SkullOutDir/FSLORIENT
      else
        t1SkullOutDir=$t1SkullOutDir/FSLORIENT
        rm $t1SkullOutDir/tmpT1Skull.nii.gz
        cd $t1SkullOutDir
      fi

      #Saving variables for logging and for donwstream processing
      echo "t1Skull=$t1SkullOutDir/T1_MNI.nii.gz" >> $resultsDir/rsParams
               
    else
      echo "overwrite flag (-c) not specified and T1Skull file already exists.  Skipping T1Skull setup"
    fi
  fi

  ################################################################





  ###### T1 (skull-stripped) ########################################

  #Begin processing T1
  echo ""
  echo ""
  echo "....Preparing T1 data"
  echo ""
  echo ""  

  echo "Reorienting T1 to RPI"
  if [[ ! -e $t1OutDir/FSLORIENT/T1_MNI_brain.nii.gz ]]; then
    ##File doesn't exist
    if [[ ! -e $t1OutDir/FSLORIENT ]]; then
      mkdir $t1OutDir/FSLORIENT
    fi

    cd $t1OutDir/FSLORIENT

    if [[ ! -e ${t1name%.nii.gz}_MNI_brain.nii.gz ]]; then
      cp $t1Dir/${t1name} $t1OutDir/FSLORIENT/tmpT1.nii.gz
      #Convert to RPI orientation - call upon an external FSL reorienting script
      $scriptDir/fslreorient.sh tmpT1.nii.gz
      mv tmpT1_MNI.nii.gz T1_MNI_brain.nii.gz

      if [[ $outFlag == 1 ]]; then
        cp T1_MNI_brain.nii.gz $t1OutDir
        cd $t1OutDir
        rm -rf $t1OutDir/FSLORIENT
      else
        t1OutDir=$t1OutDir/FSLORIENT
        rm $t1OutDir/tmpT1.nii.gz
        cd $t1OutDir
      fi
    else        
      #Convert to RPI orientation - call upon an external FSL reorienting script
      $scriptDir/fslreorient.sh ${t1name%.nii.gz}_MNI_brain.nii.gz
      t1OutDir=$t1OutDir/FSLORIENT
    fi

    #Create a brainMask from skullstripped T1
    fslmaths $t1OutDir/T1_MNI_brain.nii.gz -bin $t1OutDir/brainMask.nii.gz -odt char

    #Saving variables for logging and for donwstream processing
    echo "t1=$t1OutDir/T1_MNI_brain.nii.gz" >> $resultsDir/rsParams
    echo "t1Mask=$t1OutDir/brainMask.nii.gz" >> $resultsDir/rsParams
      
  else
    ##If user set overwrite (-c), overwrite previous file (file already exists)
    if [[ $overwriteFlag == 1 ]]; then
      if [[ ! -e $t1OutDir/FSLORIENT ]]; then
        mkdir $t1OutDir/FSLORIENT
      fi

      cd $t1OutDir/FSLORIENT        
      cp $t1OutDir/${t1name} $t1OutDir/FSLORIENT/tmpT1.nii.gz

      #Convert to RPI orientation - call upon an external FSL reorienting script
      $scriptDir/fslreorient.sh tmpT1.nii.gz
      mv tmpT1_MNI.nii.gz T1_MNI_brain.nii.gz

      if [[ $outFlag == 1 ]]; then
        cp T1_MNI_brain.nii.gz $t1OutDir
        rm -rf $t1OutDir/FSLORIENT
      else
        t1OutDir=$t1OutDir/FSLORIENT
        rm $t1OutDir/tmpT1.nii.gz
        cd $t1OutDir
      fi

      #Create a brainMask from skullstripped T1
      fslmaths $t1OutDir/T1_MNI_brain.nii.gz -bin $t1OutDir/brainMask.nii.gz -odt char

      #Saving variables for logging and for donwstream processing
      echo "t1=$t1OutDir/T1_MNI_brain.nii.gz" >> $resultsDir/rsParams
      echo "t1Mask=$t1OutDir/brainMask.nii.gz" >> $resultsDir/rsParams
               
    else
      echo "overwrite flag (-c) not specified and T1 file already exists.  Skipping T1 setup"
    fi
  fi

  ################################################################





  ###### EPI ########################################

  ##Pre setup for EPI files
  #Allowing for IMA and files other than DCM
  epiname=`basename $epi`
  epiDelimCount=`echo $epiname | awk -F"." '{print NF}' | awk -F"." '{print $1}'`
  epiSuffixTmp=`echo $epiname | awk -F"." -v var=$epiDelimCount '{print $var}'`

  #Check for .gz extension (may have to go one level in for the suffix)
  if [[ $epiSuffixTmp == "gz" ]]; then
    epiDelimCount2=`echo $epiDelimCount | awk '{print $1-1}'`
    epiSuffix=`echo $epiname | awk -F"." -v var=${epiDelimCount2} '{print $var}'`
  else
    epiSuffix=`echo $epiname | awk -F"." -v var=$epiDelimCount '{print $var}'`
  fi

  
  #Begin processing EPI data
  echo ""
  echo ""
  echo "....Preparing EPI data"
  echo ""
  echo ""


####CASE 1: If Resting state nifti file exists (and called RestingStateRaw.nii.gz  ####
  if  [ ! -e $epiOutDir/RestingStateRaw.nii* ]; then
    #RestingState file does not already exist

    #Check to see if input EPI is already processed/NIfTI format
      #Making a wild assumption that if it is NOT dcm or ima, it will be NIFTI (most likely .nii or nii.gz as the suffix)
    if [ $epiSuffix == "nii" ]; then

      echo ""
      echo ""
      echo "....Checking EPI data for correct orientation and naming convention"
      echo ""
      echo ""

      #NIFTI input      
        ##Version where input is NIFTI, needs to be oriented correctly and named properly
          #check to see if NIFTI EPI volume is in RPI orientaiton
            #Convert to RPI orientation, skullstrip (via AFNI)
      cd $epiOutDir

      #Output number of epiVols
      epiVols=`fslhd $epiDir/$epiname | grep "^dim4" | awk '{print $2}'`
      echo "epiNumVols=$epiVols" >> $resultsDir/rsParams
     #Log Default Phase Encoding Direction
        echo "peDir=-y" >> $resultsDir/rsParams
      
      #Reorient, rename
           ###Issues with lesioned subject having improper masks.  Using T1 mask, warped, in qualityControl script
      #Convert Raw EPI image to NIFTI, reorient to RPI (for use with Signal:Noise Calculation in qualityCheck.sh)
      3dcopy $epiDir/$epiname tmpRestingState
      3dresample -orient rpi -rmode Cu -prefix RestingStateRaw_tmp -inset tmpRestingState+orig
      3dAFNItoNIFTI -prefix RestingStateRaw.nii.gz RestingStateRaw_tmp+orig
      #bet RestingStateRaw.nii.gz tmp -m -n -f 0.3
      #fslmaths tmp_mask.nii.gz -bin RestingStateMask.nii.gz -odt char
      #fslmaths RestingStateRaw.nii.gz -mul RestingStateMask.nii.gz RestingState.nii.gz

      #Cleanup
      #rm *HEAD *BRIK #tmp_mask.nii.gz
      rm *HEAD *BRIK
         
      #epiFile=$epiOutDir/RestingState.nii.gz
      epiRaw=$epiOutDir/RestingStateRaw.nii.gz
      #epiMask=$epiOutDir/RestingStateMask.nii.gz      

####CASE 2: If no Resting state nifti file exists, go through IMAS or dcm's  ####
    else
      ###Assumption that this is raw DICOM/IMA data that needs to be converted to NIFTI, reoriented, skull-stripped, etc.
        ##Will create a reoriented/renamed AND skull-stripped version from DICOM/IMA
          #"Raw" version is NON skull-stripped (used for SNR calcs, etc. with qualityCheck.sc
      cd $epiDir
      images=`ls *${epiSuffix} | sort -t. -k 5 -n`
      numDcm=`echo $images | awk '{print NF}'`

      #Grab first DICOM image to strip some header info for use later
      dcmPic=`ls *${epiSuffix} | sort -t. -k 5 -n | head -1 | tail -1`

      #EPI Dwell Time (ms)
        #From https://www.jiscmail.ac.uk/cgi-bin/webadmin?A2=FSL;48be2924.1105
        #Find the bandwidth, phase encoding direction, dimension of the phase encode as well
          #dwellTime=1/(BW*peDim)
         ##Using AcquisitionMatrixText for $dimPE now
          #Echo Spacing = 1 / [(0019,1028) * (0051,100b component #1)]        

        #Bandwidth (Phase Encoding direction)
        #BWpe=`strings $dcmPic | grep -A1 "BandwidthPerPixelPhaseEncode" | head -2 | tail -1`

        filename=run_HeaderInfo.m;
cat > $filename << EOF
close all;
clear all;
addpath('${scriptDir}');
dicomScripts=['${scriptDir}','/Octave/dicom'];
addpath(dicomScripts);
dicomFilename='${dcmPic}';
header=dicominfo(dicomFilename);
[status,input] = dicom_get_header(header,'BandwidthPerPixelPhaseEncode')
quit;
EOF

  BWpeTMP=`matlab -nodisplay -r "run run_HeaderInfo.m"`
  BWpe=`echo $BWpeTMP | awk -F"=" '{print $NF}' | awk '{$1=$1}1' | awk '{print $1}'`
  rm run_HeaderInfo.m
          
        #Phase Encoding steps
        #dimpe=`strings $dcmPic | grep -A1 "PhaseEncodingLines" | head -1 | awk '{print $3}'`
          #dimpe=`strings $dcmPic | grep -A2 "AcquisitionMatrixText" | tail -1 | awk -F"*" '{print $1}'`
        #dimpe=`dicom_hdr $dcmPic | grep "0051 100b" | awk -F"//" '{print $NF}' | awk -F"*" '{print $1}'`

        filename=run_HeaderInfo.m;
cat > $filename << EOF
close all;
clear all;
addpath('${scriptDir}');
dicomScripts=['${scriptDir}','/Octave/dicom'];
addpath(dicomScripts);
dicomFilename='${dcmPic}';
header=dicominfo(dicomFilename);
[status,input] = dicom_get_header(header,'NumberOfPhaseEncodingSteps')
quit;
EOF

        dimpeTMP=`matlab -nodisplay -r "run run_HeaderInfo.m"`
        dimpe=`echo $dimpeTMP | awk -F"=" '{print $NF}' | awk '{$1=$1}1' | awk '{print $1}'`
        rm run_HeaderInfo.m

      #Dwell Time
      dwellTime=`echo $BWpe $dimpe | awk '{print (1/($1*$2))}'`

      #Phase Encoding direction, Part I
        #Expected output is x/y/z/-x/-y/-z (Not sure that z/-z would ever be used)

        #Search header for direction (ROW or COL)
          #Remove any trailing whitespace
        peType=`dicom_hdr $dcmPic | grep "ACQ Phase Encoding Direction" | awk -F"//" '{print $NF}' | awk '{$1=$1}1' | awk '{print $1}'`

        #Assign peChar (character) (x/y/z)
        if [[ "$peType" == "ROW" ]]; then
          peChar=x
        elif [[ "$peType" == "COL" ]]; then
          peChar=y
        else
          peChar=z
        fi
      

        #Check header for TR, TE (mS), override user flag with actual data
        trMsecNew=`strings $dcmPic | grep "alTR" | awk '{print ($3/1000)}'`
        trNew=`echo $trMsecNew | awk '{print ($1/1000)}'`
        te=`strings $dcmPic | grep "alTE" | awk '{print ($3/1000)}'`

      #Use sed to repopulate the rsParams_log if DICOM TR value is used
      trReplaceString=`cat $logDir/rsParams_log | grep "\-t $tr" | tail -1`
      sed -i "s/${trReplaceString}/\-t\ $trNew/g" $logDir/rsParams_log

        #Account for change of TR
        tr=$trNew
        trMsec=$trMsecNew
      

      #Output some info on EPI data
      echo "epiNumVols=$numDcm" >> $resultsDir/rsParams
      echo "epiDwell=$dwellTime" >> $resultsDir/rsParams
         
      #Number of slices
      numSlices=`strings $epi | grep "sSliceArray.lSize" | awk '{print $3}'`

      #Slice order acquisition (e.g. interleaving)
      sliceAcqOrder=`strings $epi | grep "sSliceArray.ucMode" | awk '{print $3}'`

      #If the overwrite flag is set, remove the AFNI RestingState files (to avoid conflict with to3d)
      if [[ $overwriteFlag == 1 ]]; then
        if [[ -e RestingState+orig.HEAD ]]; then
          rm RestingState+orig.HEAD
        fi
        if [[ -e RestingState+orig.BRIK ]]; then
          rm RestingState+orig.BRIK
        fi
      fi

      #Convert from DICOM to AFNI HEAD/BRIK
      if [ "$sliceAcqOrder" == "0x1" ]; then
        to3d -session $epiOutDir -prefix RestingState -time:zt $numSlices $numDcm $trMsec seq+z $images
      elif [ "$sliceAcqOrder" == "0x2" ]; then
        to3d -session $epiOutDir -prefix RestingState -overwrite -time:zt $numSlices $numDcm $trMsec seq-z $images
      else
        oddSlices=`echo ${numSlices}%2 | bc`
        if [ $oddSlices == 1 ]; then
          to3d -session $epiOutDir -prefix RestingState -overwrite -time:zt $numSlices $numDcm $trMsec alt+z $images
        else
          to3d -session $epiOutDir -prefix RestingState -overwrite -time:zt $numSlices $numDcm $trMsec alt+z2 $images
        fi
      fi

              
        #Phase Encoding direction, Part II
          #Phase encoding direction corresponds to the y-direction.  P>>A = postive, A>>P = negative
           #http://web.mit.edu/swg/Manual_FieldMap_v2.0.pdf
           #https://xwiki.nbirn.org:8443/bin/view/Function-BIRN/PhaseEncodeDirectionIssues
           #http://www.nmr.mgh.harvard.edu/~greve/dicom-unpack
            #Scan the AFNI .HEAD file for "[-orient"

        peSign=`3dinfo $epiOutDir/RestingState | grep "\[-orient" | awk -F"[" '{print $2}' | cut -c 9-11`
        peSignDirCheck=`echo $peSign | grep "P"`
         
        #Assign the direction with sign (only needed if negative)
          #If grep check of $peSign comes back as empty (direction is A>>P = negative), else direction is positive
        
        if [[ "$peSignDirCheck" == "" ]]; then
          peDir="-${peChar}"
        else
          peDir=$peChar
        fi

        #Log Phase Encoding Direction
        echo "peDir=$peDir" >> $resultsDir/rsParams

        ##I believe this logic is incorrect but left in for legacy
        #Making assumption that the sign will always be the end string after PhaseEncodingDirection
	  #e.g. PhaseEncodingDirectionPositive
          #Remove any trailing whitespaces
        #peSign=`strings $dcmPic | grep "PhaseEncodingDirection" | sed "s/PhaseEncodingDirection//" | awk '{$1=$1}1'`

        #Assign the direction with sign (only needed if negative)
        #if [[ "$peSign" == "Positive" ]]; then
          #peDir=$peChar
        #else
          #peDir="-${peChar}"
        #fi
     
      #Skull-strip the EPI
      cd $epiOutDir

            ###Issues with lesioned subject having improper masks.  Using T1 mask, warped, in qualityControl script
                  ###Using Bet with -f 0.3 instead of AFNI
      #Convert Raw EPI image to NIFTI, reorient to RPI (for use with Signal:Noise Calculation in qualityCheck.sh)
      3dresample -orient rpi -rmode Cu -prefix RestingStateRaw_tmp -inset RestingState+orig
      3dAFNItoNIFTI -prefix RestingStateRaw.nii.gz RestingStateRaw_tmp+orig
      #bet RestingStateRaw.nii.gz tmp -m -n -f 0.3
      #fslmaths tmp_mask.nii.gz -bin RestingStateMask.nii.gz -odt char
      #fslmaths RestingStateRaw.nii.gz -mul RestingStateMask.nii.gz RestingState.nii.gz

      #Cleanup
      #rm RestingState*+orig.* tmp_mask.nii.gz
      rm RestingState*+orig.*

      #epiFile=$epiOutDir/RestingState.nii.gz
      epiRaw=$epiOutDir/RestingStateRaw.nii.gz
      #epiMask=$epiOutDir/RestingStateMask.nii.gz
    fi

    #Saving variables for logging and for downstream processing
    if [[ $epiRaw != "" ]]; then
      echo "epiRaw=$epiRaw" >> $resultsDir/rsParams
    fi
    #echo "epiStripped=$epiFile" >> $resultsDir/rsParams
    #echo "epiMask=$epiMask" >> $resultsDir/rsParams  
    echo "epiTR=$tr" >> $resultsDir/rsParams
    echo "epiTE=$te" >> $resultsDir/rsParams
    
  else

     ####CASE 3: Resting state nifti file exists (but called RestingState.nii.gz) ####

    #RestingState.nii.gz file already exists
      #EPI (NIFTI) file already exists, make sure everything is properly aligned, etc.
      
    echo ""
    echo ""
    echo "....Checking EPI data for correct orientation and naming convention"
    echo ""
    echo ""

    #Remove the existing files
    if [ -e $epiOutDir/RestingState.nii.gz ]; then
      rm $epiOutDir/RestingState.nii.gz
    fi
    if [ -e $epiOutDir/RestingStateRaw.nii.gz ]; then
      rm $epiOutDir/RestingStateRaw.nii.gz
    fi
    #if [ -e $epiOutDir/RestingStateMask.nii.gz ]; then
      #rm $epiOutDir/RestingStateMask.nii.gz
    #fi



    #Check to see if input EPI is already processed/NIfTI format
      #Making a wild assumption that if it is NOT dcm or ima, it will be NIFTI (most likely .nii or nii.gz as the suffix)
    if [ $epiSuffix == "nii" ]; then

      echo ""
      echo ""
      echo "....Checking EPI data for correct orientation and naming convention"
      echo ""
      echo ""

      #NIFTI input      
        ##Version where input is NIFTI, needs to be oriented correctly and named properly
          #check to see if NIFTI EPI volume is in RPI orientaiton
            #Convert to RPI orientation, skullstrip (via AFNI)
      cd $epiOutDir

      #Output number of epiVols
      epiVols=`fslhd $epiDir/$epiname | grep "^dim4" | awk '{print $2}'`
      echo "epiNumVols=$epiVols" >> $resultsDir/rsParams
      #Log Default Phase Encoding Direction
        echo "peDir=-y" >> $resultsDir/rsParams


      #Reorient, rename and skullstrip
           ###Using Bet with -f 0.3 instead of AFNI
      #Convert Raw EPI image to NIFTI, reorient to RPI (for use with Signal:Noise Calculation in qualityCheck.sh)
      3dcopy $epiDir/$epiname tmpRestingState
      3dresample -orient rpi -rmode Cu -prefix RestingStateRaw_tmp -inset tmpRestingState+orig
      3dAFNItoNIFTI -prefix RestingStateRaw.nii.gz RestingStateRaw_tmp+orig
      #bet RestingStateRaw.nii.gz tmp -m -n -f 0.3
      #fslmaths tmp_mask.nii.gz -bin RestingStateMask.nii.gz -odt char
      #fslmaths RestingStateRaw.nii.gz -mul RestingStateMask.nii.gz RestingState.nii.gz

      #Cleanup
      rm *HEAD *BRIK tmp_mask.nii.gz   
         
      #epiFile=$epiOutDir/RestingState.nii.gz
      epiRaw=$epiOutDir/RestingStateRaw.nii.gz
      #epiMask=$epiOutDir/RestingStateMask.nii.gz      
      
 
     ####CASE 4: ####CASE 2: If no Resting state nifti file exists, go through IMAS or dcm's  ####

    else 
      ###Assumption that this is raw DICOM/IMA data that needs to be converted to NIFTI, reoriented, skull-stripped, etc.
        ##Will create a reoriented/renamed AND skull-stripped version from DICOM/IMA
          #"Raw" version is NON skull-stripped (used for SNR calcs, etc. with qualityCheck.sc
      cd $epiDir
      images=`ls *${epiSuffix} | sort -t. -k 5 -n`
      numDcm=`echo $images | awk '{print NF}'`

      #Grab first DICOM image to strip some header info for use later
      dcmPic=`ls *${epiSuffix} | sort -t. -k 5 -n | head -1 | tail -1`

      #EPI Dwell Time (ms)
        #From https://www.jiscmail.ac.uk/cgi-bin/webadmin?A2=FSL;48be2924.1105
        #Find the bandwidth, phase encoding direction, dimension of the phase encode as well
          #dwellTime=1/(BW*peDim)
         ##Using AcquisitionMatrixText for $dimPE now
          #Echo Spacing = 1 / [(0019,1028) * (0051,100b component #1)]        

        #Bandwidth (Phase Encoding direction)
        #BWpe=`strings $dcmPic | grep -A1 "BandwidthPerPixelPhaseEncode" | head -2 | tail -1`

        filename=run_HeaderInfo.m;
cat > $filename << EOF
close all;
clear all;
addpath('${scriptDir}');
dicomScripts=['${scriptDir}','/Octave/dicom'];
addpath(dicomScripts);
dicomFilename='${dcmPic}';
header=dicominfo(dicomFilename);
[status,input] = dicom_get_header(header,'BandwidthPerPixelPhaseEncode')
quit;
EOF

        BWpeTMP=`matlab -nodisplay -r "run run_HeaderInfo.m"`
        BWpe=`echo $BWpeTMP | awk -F"=" '{print $NF}' | awk '{$1=$1}1' | awk '{print $1}'`
        rm run_HeaderInfo.m
          
        #Phase Encoding steps
        #dimpe=`strings $dcmPic | grep -A1 "PhaseEncodingLines" | head -1 | awk '{print $3}'`
          #dimpe=`strings $dcmPic | grep -A2 "AcquisitionMatrixText" | tail -1 | awk -F"*" '{print $1}'`
        #dimpe=`dicom_hdr $dcmPic | grep "0051 100b" | awk -F"//" '{print $NF}' | awk -F"*" '{print $1}'`

        filename=run_HeaderInfo.m;
cat > $filename << EOF
close all;
clear all;
addpath('${scriptDir}');
dicomScripts=['${scriptDir}','/Octave/dicom'];
addpath(dicomScripts);
dicomFilename='${dcmPic}';
header=dicominfo(dicomFilename);
[status,input] = dicom_get_header(header,'NumberOfPhaseEncodingSteps')
quit;
EOF

        dimpeTMP=`matlab -nodisplay -r "run run_HeaderInfo.m"`
        dimpe=`echo $dimpeTMP | awk -F"=" '{print $NF}' | awk '{$1=$1}1' | awk '{print $1}'`
        rm run_HeaderInfo.m

      #Dwell Time
      dwellTime=`echo $BWpe $dimpe | awk '{print (1/($1*$2))}'`

      #Phase Encoding direction, Part I
        #Expected output is x/y/z/-x/-y/-z (Not sure that z/-z would ever be used)

        #Search header for direction (ROW or COL)
          #Remove any trailing whitespace
        peType=`dicom_hdr $dcmPic | grep "ACQ Phase Encoding Direction" | awk -F"//" '{print $NF}' | awk '{$1=$1}1' | awk '{print $1}'`

        #Assign peChar (character) (x/y/z)
        if [[ "$peType" == "ROW" ]]; then
          peChar=x
        elif [[ "$peType" == "COL" ]]; then
          peChar=y
        else
          peChar=z
        fi


        #Check header for TR, TE (mS), override user flag with actual data
        trMsecNew=`strings $dcmPic | grep "alTR" | awk '{print ($3/1000)}'`
        trNew=`echo $trMsecNew | awk '{print ($1/1000)}'`
        te=`strings $dcmPic | grep "alTE" | awk '{print ($3/1000)}'`

      #Use sed to repopulate the rsParams_log if DICOM TR value is used
      trReplaceString=`cat $logDir/rsParams_log | grep "\-t $tr" | tail -1`
      sed -i "s/${trReplaceString}/\-t\ $trNew/g" $logDir/rsParams_log

        #Account for change of TR
        tr=$trNew
        trMsec=$trMsecNew


      #Output some info on EPI data
      echo "epiNumVols=$numDcm" >> $resultsDir/rsParams
      echo "epiDwell=$dwellTime" >> $resultsDir/rsParams
        
         
      #Number of slices
      numSlices=`strings $epi | grep "sSliceArray.lSize" | awk '{print $3}'`

      #Slice order acquisition (e.g. interleaving)
      sliceAcqOrder=`strings $epi | grep "sSliceArray.ucMode" | awk '{print $3}'`

      #If the overwrite flag is set, remove the AFNI RestingState files (to avoid conflict with to3d)
      if [[ $overwriteFlag == 1 ]]; then
        if [[ -e RestingState+orig.HEAD ]]; then
          rm RestingState+orig.HEAD
        fi
        if [[ -e RestingState+orig.BRIK ]]; then
          rm RestingState+orig.BRIK
        fi
      fi

      #Convert from DICOM to AFNI HEAD/BRIK
      if [ "$sliceAcqOrder" == "0x1" ]; then
        to3d -session $epiOutDir -prefix RestingState -time:zt $numSlices $numDcm $trMsec seq+z $images
      elif [ "$sliceAcqOrder" == "0x2" ]; then
        to3d -session $epiOutDir -prefix RestingState -overwrite -time:zt $numSlices $numDcm $trMsec seq-z $images
      else
        oddSlices=`echo ${numSlices}%2 | bc`
        if [ $oddSlices == 1 ]; then
          to3d -session $epiOutDir -prefix RestingState -overwrite -time:zt $numSlices $numDcm $trMsec alt+z $images
        else
          to3d -session $epiOutDir -prefix RestingState -overwrite -time:zt $numSlices $numDcm $trMsec alt+z2 $images
        fi
      fi



        #Phase Encoding direction, Part II
          #Phase encoding direction corresponds to the y-direction.  P>>A = postive, A>>P = negative
           #http://web.mit.edu/swg/Manual_FieldMap_v2.0.pdf
           #https://xwiki.nbirn.org:8443/bin/view/Function-BIRN/PhaseEncodeDirectionIssues
           #http://www.nmr.mgh.harvard.edu/~greve/dicom-unpack
            #Scan the AFNI .HEAD file for "[-orient"

        peSign=`3dinfo $epiOutDir/RestingState | grep "\[-orient" | awk -F"[" '{print $2}' | cut -c 9-11`
        peSignDirCheck=`echo $peSign | grep "P"`

        #Assign the direction with sign (only needed if negative)
          #If grep check of $peSign comes back as empty (direction is A>>P = negative), else direction is positive
        
        if [[ "$peSignDirCheck" == "" ]]; then
          peDir="-${peChar}"
        else
          peDir=$peChar
        fi

        #Log Phase Encoding Direction
        echo "peDir=$peDir" >> $resultsDir/rsParams

        ##I believe this logic is incorrect but left in for legacy
        #Making assumption that the sign will always be the end string after PhaseEncodingDirection
	  #e.g. PhaseEncodingDirectionPositive
          #Remove any trailing whitespaces
        #peSign=`strings $dcmPic | grep "PhaseEncodingDirection" | sed "s/PhaseEncodingDirection//" | awk '{$1=$1}1'`

        #Assign the direction with sign (only needed if negative)
        #if [[ "$peSign" == "Positive" ]]; then
          #peDir=$peChar
        #else
          #peDir="-${peChar}"
        #fi
     
      #Skull-strip the EPI
      cd $epiOutDir

            ###Issues with lesioned subject having improper masks.  Using T1 mask, warped, in qualityControl script
                  ###Using Bet with -f 0.3 instead of AFNI
      #Convert Raw EPI image to NIFTI, reorient to RPI (for use with Signal:Noise Calculation in qualityCheck.sh)
      3dresample -orient rpi -rmode Cu -prefix RestingStateRaw_tmp -inset RestingState+orig
      3dAFNItoNIFTI -prefix RestingStateRaw.nii.gz RestingStateRaw_tmp+orig
      #bet RestingStateRaw.nii.gz tmp -m -n -f 0.3
      #fslmaths tmp_mask.nii.gz -bin RestingStateMask.nii.gz -odt char
      #fslmaths RestingStateRaw.nii.gz -mul RestingStateMask.nii.gz RestingState.nii.gz

      #Cleanup
      rm RestingState*+orig.* tmp_mask.nii.gz

      #epiFile=$epiOutDir/RestingState.nii.gz
      epiRaw=$epiOutDir/RestingStateRaw.nii.gz
      #epiMask=$epiOutDir/RestingStateMask.nii.gz
    fi

    #Saving variables for logging and for downstream processing
    echo "epiRaw=$epiRaw" >> $resultsDir/rsParams
    #echo "epiStripped=$epiFile" >> $resultsDir/rsParams
    #echo "epiMask=$epiMask" >> $resultsDir/rsParams  
    echo "epiTR=$tr" >> $resultsDir/rsParams
    echo "epiTE=$te" >> $resultsDir/rsParams


  fi

  ################################################################





  ###### FieldMap ########################################

  if [[ $fieldMapFlag == 1 ]]; then
    #Only process FieldMap data if flagged

   #Log processing via Fieldmap
   echo "fieldMapCorrection=1" >> $resultsDir/rsParams


    ###### FieldMap (Phase) ########################################

    ##Pre setup for FieldMap (Phase) files
    #Allowing for IMA and files other than DCM
    fieldMapPhasename=`basename $fieldMapPhase`
    fieldMapPhaseDelimCount=`echo $fieldMapPhasename | awk -F"." '{print NF}' | awk -F"." '{print $1}'`
    fieldMapPhaseSuffixTmp=`echo $fieldMapPhasename | awk -F"." -v var=$fieldMapPhaseDelimCount '{print $var}'`

    #Check for .gz extension (may have to go one level in for the suffix)
    if [[ $fieldMapPhaseSuffixTmp == "gz" ]]; then
      fieldMapPhaseDelimCount2=`echo $fieldMapPhaseDelimCount | awk '{print $1-1}'`
      fieldMapPhaseSuffix=`echo $fieldMapPhasename | awk -F"." -v var=${fieldMapPhaseDelimCount2} '{print $var}'`
    else
      fieldMapPhaseSuffix=`echo $fieldMapPhasename | awk -F"." -v var=${fieldMapPhaseDelimCount} '{print $var}'`
    fi


    #Begin processing FieldMap (Phase) data
    echo ""
    echo ""
    echo "....Preparing FieldMap (Phase) data"
    echo ""
    echo ""

    if  [ ! -e $fieldMapPhaseOutDir/fieldMapPhase_MNI.nii* ]; then

      #Check to see if input FieldMap (Phase) is already processed/NIfTI format
        #Making a wild assumption that if it is NOT dcm or ima, it will be NIFTI (most likely .nii or nii.gz as the suffix)
      if [ $fieldMapPhaseSuffix == "nii" ]; then
        echo ""
        echo ""
        echo "....Checking FieldMap (Phase) data for correct orientation and naming convention"
        echo ""
        echo ""

        #NIFTI input, just needs to be oriented correctly and named properly
        cd $fieldMapPhaseOutDir

        echo "...Reorienting FieldMap (Phase) to RPI"
        if [[ ! -e $fieldMapPhaseOutDir/FSLORIENT/fieldMapPhase_MNI.nii.gz ]]; then
          ##File doesn't exist
          if [[ ! -e $fieldMapPhaseOutDir/FSLORIENT ]]; then
            mkdir $fieldMapPhaseOutDir/FSLORIENT
          fi

          cd $fieldMapPhaseOutDir/FSLORIENT

          if [[ ! -e ${fieldMapPhasename%.nii.gz}_MNI_brain.nii.gz ]]; then
            cp $fieldMapPhaseDir/${fieldMapPhasename} $fieldMapPhaseOutDir/FSLORIENT/${fieldMapPhasename}
            #Convert to RPI orientation - call upon an external FSL reorienting script
            $scriptDir/fslreorient.sh ${fieldMapPhasename}
            mv ${fieldMapPhasename%.nii.gz}_MNI.nii.gz fieldMapPhase_MNI.nii.gz

            if [[ $outFlag == 1 ]]; then
              cp fieldMapPhase_MNI.nii.gz $fieldMapPhaseOutDir
              cd $fieldMapPhaseOutDir
              rm -rf $fieldMapPhaseOutDir/FSLORIENT
            else
              fieldMapPhaseOutDir=$fieldMapPhaseOutDir/FSLORIENT
              rm $fieldMapPhaseOutDir/${fieldMapPhasename}
              cd $fieldMapPhaseOutDir
            fi
          else        
            #Convert to RPI orientation - call upon an external FSL reorienting script
            $scriptDir/fslreorient.sh ${fieldMapPhasename%.nii.gz}_MNI_brain.nii.gz
            fieldMapPhaseOutDir=$fieldMapPhaseOutDir/FSLORIENT
          fi

          #Saving variables for logging and for donwstream processing
          echo "fieldMapPhase=$fieldMapPhaseOutDir/fieldMapPhase_MNI.nii.gz" >> $resultsDir/rsParams
     
        else
          ##If user set overwrite (-c), overwrite previous file (file already exists)
          if [[ $overwriteFlag == 1 ]]; then
            if [[ ! -e $fieldMapPhaseOutDir/FSLORIENT ]]; then
              mkdir $fieldMapPhaseOutDir/FSLORIENT
            fi

            cd $fieldMapPhaseOutDir/FSLORIENT        
            cp $fieldMapPhaseOutDir/${fieldMapPhasename} $fieldMapPhaseOutDir/FSLORIENT/${fieldMapPhasename}

            #Convert to RPI orientation - call upon an external FSL reorienting script
            $scriptDir/fslreorient.sh ${fieldMapPhasename}
            mv ${fieldMapPhasename%.nii.gz}_MNI.nii.gz fieldMapPhase_MNI.nii.gz

            if [[ $outFlag == 1 ]]; then
              cp fieldMapPhase_MNI.nii.gz $fieldMapPhaseOutDir
              rm -rf $fieldMapPhaseOutDir/FSLORIENT
            else
              fieldMapPhaseOutDir=$fieldMapPhaseOutDir/FSLORIENT
              rm $fieldMapPhaseOutDir/${fieldMapPhasename}
              cd $fieldMapPhaseOutDir
            fi

            #Saving variables for logging and for donwstream processing
            echo "fieldMapPhase=$fieldMapPhaseOutDir/fieldMapPhase_MNI.nii.gz" >> $resultsDir/rsParams
               
          else
            echo "overwrite flag (-c) not specified and FieldMap (Phase) file already exists.  Skipping FieldMap (Phase) setup"
          fi
        fi

      else
        ###Assumption that this is raw DICOM/IMA data that needs to be converted to NIFTI, reoriented, etc.
        cd $fieldMapPhaseDir
        
        #Grab first DICOM image to strip some header info for use later
        dcmPic=`ls *${fieldMapPhaseSuffix} | sort -t. -k 5 -n | head -1 | tail -1`

        #fieldMapPhase deltaTE (ms)
          #Grabs the third column (TE times for alTE[0] and alTE[1], subtracts them and divides by 1000 (conversion to seconds from ms))
        deltaTENew=`strings $dcmPic | grep "alTE" | awk 'p{print ($3-p)/1000}{p=$3}'`

        #Use sed to repopulate the rsParams_log if DICOM deltaTE value is used
        deltaTEReplaceString=`cat $logDir/rsParams_log | grep "\-F $deltaTE" | tail -1`
        sed -i "s/${deltaTEReplaceString}/\-F\ $deltaTENew/g" $logDir/rsParams_log

          #Account for change of deltaTE
          deltaTE=$deltaTENew

        #Output some info on fieldMapPhase data
        echo "deltaTE=$deltaTE" >> $resultsDir/rsParams
        
        #Convert from DICOM to NIfTI     
        mri_convert --in_type siemens_dicom --out_type nii $dcmPic $fieldMapPhaseOutDir/fieldMapPhase.nii.gz
         
        cd $fieldMapPhaseOutDir

        #Reorienting file to RPI
        if [[ ! -e $fieldMapPhaseOutDir/FSLORIENT ]]; then
          mkdir $fieldMapPhaseOutDir/FSLORIENT
        fi

        cd $fieldMapPhaseOutDir/FSLORIENT        
        cp $fieldMapPhaseOutDir/fieldMapPhase.nii.gz $fieldMapPhaseOutDir/FSLORIENT

        #Convert to RPI orientation - call upon an external FSL reorienting script
        $scriptDir/fslreorient.sh fieldMapPhase

        if [[ $outFlag == 1 ]]; then
          cp fieldMapPhase_MNI.nii.gz $fieldMapPhaseOutDir
          rm -rf $fieldMapPhaseOutDir/FSLORIENT
        else
          fieldMapPhaseOutDir=$fieldMapPhaseOutDir/FSLORIENT
          rm $fieldMapPhaseOutDir/fieldMapPhase.nii.gz
          cd $fieldMapPhaseOutDir
        fi

        #Saving variables for logging and for donwstream processing
        echo "fieldMapPhase=$fieldMapPhaseOutDir/fieldMapPhase_MNI.nii.gz" >> $resultsDir/rsParams
      fi

    else
      #Check for overwrite permissions
      if [[ $overwriteFlag == 1 ]]; then

        #Main script (processRestingState.sh) checks to see if things need to be/should be overwritten.  Assuming things have passed that stage
          #(and that "-c" overwrite flag is passed on if it SHOULD be)....
            #fieldMapPhase (NIFTI) file already exists, make sure everything is properly aligned, etc.      

        #Remove pre-existing files
        if [[ -e $fieldMapPhaseOutDir/FSLORIENT ]]; then
          rm -rf $fieldMapPhaseOutDir/FSLORIENT
        fi        
        if [[ -e $fieldMapPhaseOutDir/fieldMapPhase_MNI.nii* ]]; then
          rm $fieldMapPhaseOutDir/fieldMapPhase_MNI.nii*
        fi


        #Recreate files
        if [ $fieldMapPhaseSuffix == "nii" ]; then
          echo ""
          echo ""
          echo "....Checking FieldMap (Phase) data for correct orientation and naming convention"
          echo ""
          echo ""

          #NIFTI input, just needs to be oriented correctly and named properly
          cd $fieldMapPhaseOutDir

          echo "...Reorienting FieldMap (Phase) to RPI"
        
          mkdir $fieldMapPhaseOutDir/FSLORIENT
          
          cd $fieldMapPhaseOutDir/FSLORIENT

          
          cp $fieldMapPhaseDir/${fieldMapPhasename} $fieldMapPhaseOutDir/FSLORIENT/${fieldMapPhasename}
          #Convert to RPI orientation - call upon an external FSL reorienting script
          $scriptDir/fslreorient.sh ${fieldMapPhasename}
          mv ${fieldMapPhasename%.nii.gz}_MNI.nii.gz fieldMapPhase_MNI.nii.gz

          if [[ $outFlag == 1 ]]; then
            cp fieldMapPhase_MNI.nii.gz $fieldMapPhaseOutDir
            cd $fieldMapPhaseOutDir
            rm -rf $fieldMapPhaseOutDir/FSLORIENT
          else
            fieldMapPhaseOutDir=$fieldMapPhaseOutDir/FSLORIENT
            rm $fieldMapPhaseOutDir/${fieldMapPhasename}
            cd $fieldMapPhaseOutDir
          fi          

          #Saving variables for logging and for donwstream processing
          echo "fieldMapPhase=$fieldMapPhaseOutDir/fieldMapPhase_MNI.nii.gz" >> $resultsDir/rsParams

        else
          ###Assumption that this is raw DICOM/IMA data that needs to be converted to NIFTI, reoriented, etc.
          cd $fieldMapPhaseDir
        
          #Grab first DICOM image to strip some header info for use later
          dcmPic=`ls *${fieldMapPhaseSuffix} | sort -t. -k 5 -n | head -1 | tail -1`

          #fieldMapPhase deltaTE (ms)
            #Grabs the third column (TE times for alTE[0] and alTE[1], subtracts them and divides by 1000 (conversion to seconds from ms))
          deltaTENew=`strings $dcmPic | grep "alTE" | awk 'p{print ($3-p)/1000}{p=$3}'`

          #Use sed to repopulate the rsParams_log if DICOM deltaTE value is used
          deltaTEReplaceString=`cat $logDir/rsParams_log | grep "\-F $deltaTE" | tail -1`
          sed -i "s/${deltaTEReplaceString}/\-F\ $deltaTENew/g" $logDir/rsParams_log

            #Account for change of deltaTE
            deltaTE=$deltaTENew

          #Output some info on fieldMapPhase data
          echo "deltaTE=$deltaTE" >> $resultsDir/rsParams
        
          #Convert from DICOM to NIfTI     
          mri_convert --in_type siemens_dicom --out_type nii $dcmPic $fieldMapPhaseOutDir/fieldMapPhase.nii.gz
         
          cd $fieldMapPhaseOutDir

          #Reorienting file to RPI
          mkdir $fieldMapPhaseOutDir/FSLORIENT
        
          cd $fieldMapPhaseOutDir/FSLORIENT        
          cp $fieldMapPhaseOutDir/fieldMapPhase.nii.gz $fieldMapPhaseOutDir/FSLORIENT

          #Convert to RPI orientation - call upon an external FSL reorienting script
          $scriptDir/fslreorient.sh fieldMapPhase

          if [[ $outFlag == 1 ]]; then
            cp fieldMapPhase_MNI.nii.gz $fieldMapPhaseOutDir
            rm -rf $fieldMapPhaseOutDir/FSLORIENT
          else
            fieldMapPhaseOutDir=$fieldMapPhaseOutDir/FSLORIENT
            rm $fieldMapPhaseOutDir/fieldMapPhase.nii.gz
            cd $fieldMapPhaseOutDir
          fi

          #Saving variables for logging and for donwstream processing
          echo "fieldMapPhase=$fieldMapPhaseOutDir/fieldMapPhase_MNI.nii.gz" >> $resultsDir/rsParams
        fi

      else
        echo "overwrite flag (-c) not specified and FieldMap (Phase) file already exists.  Skipping FieldMap (Phase) setup"
      fi
    fi

    ################################################################





    ###### FieldMap (Magnitude) ########################################        

    ##Pre setup for FieldMap (Mag) files
    #Allowing for IMA and files other than DCM
    fieldMapMagname=`basename $fieldMapMag`
    fieldMapMagDelimCount=`echo $fieldMapMagname | awk -F"." '{print NF}' | awk -F"." '{print $1}'`
    fieldMapMagSuffixTmp=`echo $fieldMapMagname | awk -F"." -v var=$fieldMapMagDelimCount '{print $var}'`

    #Check for .gz extension (may have to go one level in for the suffix)
    if [[ $fieldMapMagSuffixTmp == "gz" ]]; then
      fieldMapMagDelimCount2=`echo $fieldMapMagDelimCount | awk '{print $1-1}'`
      fieldMapMagSuffix=`echo $fieldMapMagname | awk -F"." -v var=${fieldMapMagDelimCount2} '{print $var}'`
    else
      fieldMapMagSuffix=`echo $fieldMapMagname | awk -F"." -v var=${fieldMapMagDelimCount} '{print $var}'`
    fi


    #Begin processing FieldMap (Mag) data
    echo ""
    echo ""
    echo "....Preparing FieldMap (Mag) data"
    echo ""
    echo ""

    if  [ ! -e $fieldMapMagOutDir/fieldMapMag_MNI.nii* ]; then

      #Check to see if input FieldMap (Mag) is already processed/NIfTI format
        #Making a wild assumption that if it is NOT dcm or ima, it will be NIFTI (most likely .nii or nii.gz as the suffix)
      if [ $fieldMapMagSuffix == "nii" ]; then
        echo ""
        echo ""
        echo "....Checking FieldMap (Mag) data for correct orientation and naming convention"
        echo ""
        echo ""

        #NIFTI input, just needs to be oriented correctly and named properly
        cd $fieldMapMagOutDir

        echo "...Reorienting FieldMap (Mag) to RPI"
        if [[ ! -e $fieldMapMagOutDir/FSLORIENT/fieldMapMag_MNI.nii.gz ]]; then
          ##File doesn't exist
          if [[ ! -e $fieldMapMagOutDir/FSLORIENT ]]; then
            mkdir $fieldMapMagOutDir/FSLORIENT
          fi

          cd $fieldMapMagOutDir/FSLORIENT

          if [[ ! -e ${fieldMapMagname%.nii.gz}_MNI_brain.nii.gz ]]; then
            cp $fieldMapMagDir/${fieldMapMagname} $fieldMapMagOutDir/FSLORIENT/${fieldMapMagname}
            #Convert to RPI orientation - call upon an external FSL reorienting script
            $scriptDir/fslreorient.sh ${fieldMapMagname}
            mv ${fieldMapMagname%.nii.gz}_MNI.nii.gz fieldMapMag_MNI.nii.gz

            #Skull-strip the Magnitude image
            bet fieldMapMag_MNI.nii.gz fieldMapMag -m -n
            fslmaths fieldMapMag_mask.nii.gz -ero fieldMapMag_mask_eroded.nii.gz
            fslmaths fieldMapMag_MNI.nii.gz -mul fieldMapMag_mask_eroded.nii.gz fieldMapMag_MNI_stripped.nii.gz

            if [[ $outFlag == 1 ]]; then
              cp fieldMapMag_MNI.nii.gz $fieldMapMagOutDir
              cp fieldMapMag_MNI_stripped.nii.gz $fieldMapMagOutDir
              cd $fieldMapMagOutDir
              rm -rf $fieldMapMagOutDir/FSLORIENT
            else
              fieldMapMagOutDir=$fieldMapMagOutDir/FSLORIENT
              rm $fieldMapMagOutDir/${fieldMapMagname}
              cd $fieldMapMagOutDir
            fi

          else        
            #Convert to RPI orientation - call upon an external FSL reorienting script
            $scriptDir/fslreorient.sh ${fieldMapMagname%.nii.gz}_MNI_brain.nii.gz
            fieldMapMagOutDir=$fieldMapMagOutDir/FSLORIENT
          fi

          #Saving variables for logging and for donwstream processing
          echo "fieldMapMag=$fieldMapMagOutDir/fieldMapMag_MNI.nii.gz" >> $resultsDir/rsParams
          echo "fieldMapMagStripped=$fieldMapMagOutDir/fieldMapMag_MNI_stripped.nii.gz" >> $resultsDir/rsParams
     
        else
          ##If user set overwrite (-c), overwrite previous file (file already exists)
          if [[ $overwriteFlag == 1 ]]; then
            if [[ ! -e $fieldMapMagOutDir/FSLORIENT ]]; then
              mkdir $fieldMapMagOutDir/FSLORIENT
            fi

            cd $fieldMapMagOutDir/FSLORIENT        
            cp $fieldMapMagOutDir/${fieldMapMagname} $fieldMapMagOutDir/FSLORIENT/${fieldMapMagname}

            #Convert to RPI orientation - call upon an external FSL reorienting script
            $scriptDir/fslreorient.sh ${fieldMapMagname}
            mv ${fieldMapMagname%.nii.gz}_MNI.nii.gz fieldMapMag_MNI.nii.gz

            #Skull-strip the Magnitude image
            bet fieldMapMag_MNI.nii.gz fieldMapMag -m -n
            fslmaths fieldMapMag_mask.nii.gz -ero fieldMapMag_mask_eroded.nii.gz
            fslmaths fieldMapMag_MNI.nii.gz -mul fieldMapMag_mask_eroded.nii.gz fieldMapMag_MNI_stripped.nii.gz

            if [[ $outFlag == 1 ]]; then
              cp fieldMapMag_MNI.nii.gz $fieldMapMagOutDir
              cp fieldMapMag_MNI_stripped.nii.gz $fieldMapMagOutDir
              cd $fieldMapMagOutDir
              rm -rf $fieldMapMagOutDir/FSLORIENT
            else
              fieldMapMagOutDir=$fieldMapMagOutDir/FSLORIENT
              rm $fieldMapMagOutDir/${fieldMapMagname}
              cd $fieldMapMagOutDir
            fi

            #Saving variables for logging and for donwstream processing
            echo "fieldMapMag=$fieldMapMagOutDir/fieldMapMag_MNI.nii.gz" >> $resultsDir/rsParams
            echo "fieldMapMagStripped=$fieldMapMagOutDir/fieldMapMag_MNI_stripped.nii.gz" >> $resultsDir/rsParams
               
          else
            echo "overwrite flag (-c) not specified and FieldMap (Mag) file already exists.  Skipping FieldMap (Mag) setup"
          fi
        fi

      else
        ###Assumption that this is raw DICOM/IMA data that needs to be converted to NIFTI, reoriented, etc.
        cd $fieldMapMagDir
        
        #Grab first DICOM image
        dcmPic=`ls *${fieldMapMagSuffix} | sort -t. -k 5 -n | head -1 | tail -1`

        #Convert from DICOM to NIfTI     
        mri_convert --in_type siemens_dicom --out_type nii $dcmPic $fieldMapMagOutDir/fieldMapMag.nii.gz
         
        cd $fieldMapMagOutDir

        #Reorienting file to RPI
        if [[ ! -e $fieldMapMagOutDir/FSLORIENT ]]; then
          mkdir $fieldMapMagOutDir/FSLORIENT
        fi

        cd $fieldMapMagOutDir/FSLORIENT        
        cp $fieldMapMagOutDir/fieldMapMag.nii.gz $fieldMapMagOutDir/FSLORIENT

        #Convert to RPI orientation - call upon an external FSL reorienting script
        $scriptDir/fslreorient.sh fieldMapMag

        #Skull-strip the Magnitude image
        bet fieldMapMag_MNI.nii.gz fieldMapMag -m -n
        fslmaths fieldMapMag_mask.nii.gz -ero fieldMapMag_mask_eroded.nii.gz
        fslmaths fieldMapMag_MNI.nii.gz -mul fieldMapMag_mask_eroded.nii.gz fieldMapMag_MNI_stripped.nii.gz

        if [[ $outFlag == 1 ]]; then
          cp fieldMapMag_MNI.nii.gz $fieldMapMagOutDir
          cp fieldMapMag_MNI_stripped.nii.gz $fieldMapMagOutDir
          cd $fieldMapMagOutDir
          rm -rf $fieldMapMagOutDir/FSLORIENT
        else
          fieldMapMagOutDir=$fieldMapMagOutDir/FSLORIENT
          rm $fieldMapMagOutDir/fieldMapMag.nii.gz
          cd $fieldMapMagOutDir
        fi

        #Saving variables for logging and for donwstream processing
        echo "fieldMapMag=$fieldMapMagOutDir/fieldMapMag_MNI.nii.gz" >> $resultsDir/rsParams
        echo "fieldMapMagStripped=$fieldMapMagOutDir/fieldMapMag_MNI_stripped.nii.gz" >> $resultsDir/rsParams
      fi

    else
      #Check for overwrite permissions
      if [[ $overwriteFlag == 1 ]]; then

        #Main script (processRestingState.sh) checks to see if things need to be/should be overwritten.  Assuming things have passed that stage
          #(and that "-c" overwrite flag is passed on if it SHOULD be)....
            #fieldMapMag (NIFTI) file already exists, make sure everything is properly aligned, etc.      

        #Remove pre-existing files
        if [[ -e $fieldMapMagOutDir/FSLORIENT ]]; then
          rm -rf $fieldMapMagOutDir/FSLORIENT
        fi        
        if [[ -e $fieldMapMagOutDir/fieldMapMag_MNI.nii* ]]; then
          rm $fieldMapMagOutDir/fieldMapMag_MNI.nii*
        fi


        #Recreate files
        if [ $fieldMapMagSuffix == "nii" ]; then
          echo ""
          echo ""
          echo "....Checking FieldMap (Mag) data for correct orientation and naming convention"
          echo ""
          echo ""

          #NIFTI input, just needs to be oriented correctly and named properly
          cd $fieldMapMagOutDir

          echo "...Reorienting FieldMap (Mag) to RPI"
        
          mkdir $fieldMapMagOutDir/FSLORIENT
          
          cd $fieldMapMagOutDir/FSLORIENT

          
          cp $fieldMapMagDir/${fieldMapMagname} $fieldMapMagOutDir/FSLORIENT/${fieldMapMagname}
          #Convert to RPI orientation - call upon an external FSL reorienting script
          $scriptDir/fslreorient.sh ${fieldMapMagname}
          mv ${fieldMapMagname%.nii.gz}_MNI.nii.gz fieldMapMag_MNI.nii.gz

          #Skull-strip the Magnitude image
          bet fieldMapMag_MNI.nii.gz fieldMapMag -m -n
          fslmaths fieldMapMag_mask.nii.gz -ero fieldMapMag_mask_eroded.nii.gz
          fslmaths fieldMapMag_MNI.nii.gz -mul fieldMapMag_mask_eroded.nii.gz fieldMapMag_MNI_stripped.nii.gz

          if [[ $outFlag == 1 ]]; then
            cp fieldMapMag_MNI.nii.gz $fieldMapMagOutDir
            cp fieldMapMag_MNI_stripped.nii.gz $fieldMapMagOutDir
            cd $fieldMapMagOutDir
            rm -rf $fieldMapMagOutDir/FSLORIENT
          else
            fieldMapMagOutDir=$fieldMapMagOutDir/FSLORIENT
            rm $fieldMapMagOutDir/${fieldMapMagname}
            cd $fieldMapMagOutDir
          fi

          #Saving variables for logging and for donwstream processing
          echo "fieldMapMag=$fieldMapMagOutDir/fieldMapMag_MNI.nii.gz" >> $resultsDir/rsParams
          echo "fieldMapMagStripped=$fieldMapMagOutDir/fieldMapMag_MNI_stripped.nii.gz" >> $resultsDir/rsParams

        else
          ###Assumption that this is raw DICOM/IMA data that needs to be converted to NIFTI, reoriented, etc.
          cd $fieldMapMagDir
        
          #Grab first DICOM image
          dcmPic=`ls *${fieldMapMagSuffix} | sort -t. -k 5 -n | head -1 | tail -1`

          #Convert from DICOM to NIfTI     
          mri_convert --in_type siemens_dicom --out_type nii $dcmPic $fieldMapMagOutDir/fieldMapMag.nii.gz
         
          cd $fieldMapMagOutDir

          #Reorienting file to RPI
          mkdir $fieldMapMagOutDir/FSLORIENT
        
          cd $fieldMapMagOutDir/FSLORIENT        
          cp $fieldMapMagOutDir/fieldMapMag.nii.gz $fieldMapMagOutDir/FSLORIENT

          #Convert to RPI orientation - call upon an external FSL reorienting script
          $scriptDir/fslreorient.sh fieldMapMag


          #Skull-strip the Magnitude image
          bet fieldMapMag_MNI.nii.gz fieldMapMag -m -n
          fslmaths fieldMapMag_mask.nii.gz -ero fieldMapMag_mask_eroded.nii.gz
          fslmaths fieldMapMag_MNI.nii.gz -mul fieldMapMag_mask_eroded.nii.gz fieldMapMag_MNI_stripped.nii.gz


          if [[ $outFlag == 1 ]]; then
            cp fieldMapMag_MNI.nii.gz $fieldMapMagOutDir
            cp fieldMapMag_MNI_stripped.nii.gz $fieldMapMagOutDir
            cd $fieldMapMagOutDir
            rm -rf $fieldMapMagOutDir/FSLORIENT
          else
            fieldMapMagOutDir=$fieldMapMagOutDir/FSLORIENT
            rm $fieldMapMagOutDir/fieldMapMag.nii.gz
            cd $fieldMapMagOutDir
          fi

          #Saving variables for logging and for donwstream processing
          echo "fieldMapMag=$fieldMapMagOutDir/fieldMapMag_MNI.nii.gz" >> $resultsDir/rsParams
          echo "fieldMapMagStripped=$fieldMapMagOutDir/fieldMapMag_MNI_stripped.nii.gz" >> $resultsDir/rsParams
        fi

      else
        echo "overwrite flag (-c) not specified and FieldMap (Mag) file already exists.  Skipping FieldMap (Mag) setup"
      fi
    fi

    ################################################################





    ###### FieldMap (Prepped) ########################################

    #Begin prepping fieldMap data for BBR registration downstream
      #Prepare the field Map from stripped Mag image and converted Phase image    

    echo ""
    echo ""
    echo "....Prepping FieldMap data (from Phase and Magnitude images) for subsequent registration steps"
    echo ""
    echo ""

    #Dependency of presence/abasence of outFlag
    if [[ $outFlag == 1 ]]; then
      #File will be in /func/EPItoT1optimized

    
      #Check for presence of file/overwrite permissions
      if [[ ! -e $resultsDir/EPItoT1optimized/fieldMap_prepped.nii* ]]; then
        #File doesn't exist

        cd $resultsDir/EPItoT1optimized

        #Prepare the fieldMaps
        fsl_prepare_fieldmap SIEMENS $fieldMapPhaseOutDir/fieldMapPhase_MNI.nii.gz $fieldMapMagOutDir/fieldMapMag_MNI_stripped.nii.gz $resultsDir/EPItoT1optimized/fieldMap_prepped.nii.gz $deltaTE

        #Saving variables for logging and for donwstream processing
        echo "fieldMapPrepped=$resultsDir/EPItoT1optimized/fieldMap_prepped.nii.gz" >> $resultsDir/rsParams

      else
        #File exists      
        if [[ $overwriteFlag == 1 ]]; then

          cd $resultsDir/EPItoT1optimized

          #Prepare the fieldMaps
          fsl_prepare_fieldmap SIEMENS $fieldMapPhaseOutDir/fieldMapPhase_MNI.nii.gz $fieldMapMagOutDir/fieldMapMag_MNI_stripped.nii.gz $resultsDir/EPItoT1optimized/fieldMap_prepped.nii.gz $deltaTE

          #Saving variables for logging and for donwstream processing
          echo "fieldMapPrepped=$resultsDir/EPItoT1optimized/fieldMap_prepped.nii.gz" >> $resultsDir/rsParams

        else
          echo "overwrite flag (-c) not specified and FieldMap (Prepped) file already exists.  Skipping FieldMap (Prepped) setup"
        fi
      fi

    else
      #File will be in EPI input directory ($resultsDir)
      cd $resultsDir

      if [[ ! -e  $resultsDir/EPItoT1optimized ]]; then
        mkdir $resultsDir/EPItoT1optimized
      fi

      fieldMapPreppedOutDir=$resultsDir/EPItoT1optimized


      #Check for presence of file/overwrite permissions
      if [[ ! -e $fieldMapPreppedOutDir/fieldMap_prepped.nii* ]]; then
        #File doesn't exist

        cd $fieldMapPreppedOutDir

        #Prepare the fieldMaps
        fsl_prepare_fieldmap SIEMENS $fieldMapPhaseOutDir/fieldMapPhase_MNI.nii.gz $fieldMapMagOutDir/fieldMapMag_MNI_stripped.nii.gz $fieldMapPreppedOutDir/fieldMap_prepped.nii.gz $deltaTE

        #Saving variables for logging and for donwstream processing
        echo "fieldMapPrepped=$fieldMapPreppedOutDir/fieldMap_prepped.nii.gz" >> $resultsDir/rsParams

      else
        #File exists      
        if [[ $overwriteFlag == 1 ]]; then

          cd $fieldMapPreppedOutDir

          #Prepare the fieldMaps
          fsl_prepare_fieldmap SIEMENS $fieldMapPhaseOutDir/fieldMapPhase_MNI.nii.gz $fieldMapMagOutDir/fieldMapMag_MNI_stripped.nii.gz $fieldMapPreppedOutDir/fieldMap_prepped.nii.gz $deltaTE

          #Saving variables for logging and for donwstream processing
          echo "fieldMapPrepped=$fieldMapPreppedOutDir/fieldMap_prepped.nii.gz" >> $resultsDir/rsParams

        else
          echo "overwrite flag (-c) not specified and FieldMap (Prepped) file already exists.  Skipping FieldMap (Prepped) setup"
        fi
      fi
    fi

    ################################################################
  fi

#let index+=1
#done

echo "$0 Complete"
echo ""
echo ""





