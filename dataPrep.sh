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

clob=false
# Parse Command line arguments
while getopts “hi:o:t:T:fF:S:c” OPTION
do
  case $OPTION in
    h)
      printCommandLine
      ;;
    i)
      datafile=$(perl -e 'use Cwd "abs_path";print abs_path(shift)' $OPTARG)
      ;;
    o)
      outDir=$OPTARG
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
    S)
      scanner=${OPTARG}
      ;;
    c)
      clob=true
    ?)
      printCommandLine
      ;;
     esac
done

function printCommandLine()
{
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

##################
#function: clobber
##################
#purpose: checks to see if files exist and overwrites them when clob is set to true
##################
#dependencies: None
##################
#Used in: (almost) Everything
##################
function clobber() 
{
  #Tracking Variables
  local -i num_existing_files=0
  local -i num_args=$#

  #Tally all existing outputs
  for arg in $@; do
    if [ -e "${arg}" ] && [ "${clob}" == true ]; then
      rm -rf "${arg}"
    elif [ -e "${arg}" ] && [ "${clob}" == false ]; then
      num_existing_files=$(( ${num_existing_files} + 1 ))
      continue
    elif [ ! -e "${arg}" ]; then
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

function T1Head_prep()
{
  local t1Head=$1
  local t1Head_outDir=$2
  printf "\n\n%s\n\n" "....Preparing T1Head data"

  ConvertToNifti ${t1Head}

  clobber ${t1Head_outDir}/T1_head.nii.gz &&\
  cp ${t1Head} ${t1Head_outDir}/T1_head.nii.gz ||\
  { printf "%s\n" "cp ${t1Head} ${t1Head_outDir}/T1_head.nii.gz failed" "exiting ${FUNCNAME} function" && return 1 }

  printf "%s\n" "Reorienting T1Head to RPI"
  clobber ${t1Head_outDir}/T1_head_RPI.nii.gz &&\
  RPI_orient ${t1Head_outDir}/T1_head.nii.gz ||\
  { printf "%s\n" "Re-Orientation failed, exiting ${FUNCNAME} function" && return 1 }

  printf "%s\n" "${FUNCNAME} ran successfully." && return 0
}

function ConvertToNifti()
{
  __input=$1
  inputDir=$(dirname ${__input})
  inputBase=$(basename ${__input})
  inputSuffix=${inputBase#*.}
case "${inputSuffix}" in
  'dcm')
      echo "code not implemented (needs to reset epi variable)" && return 1
      #reconstruct
      #eval __input="'nifti_output'"
      ;;
  'BRIK')
      echo "code not implemented (needs to reset epi variable)" && return 1
      #reconstruct
      #eval __input="'nifti_output'"
      ;;
  'IMA')
      echo "code not implemented (needs to reset epi variable)" && return 1
      #reconstruct
      #eval __input="'nifti_output'"
      ;;
  'nii.gz')
      echo "${__input} already in NIFTI format"
      ;;
esac

printf "%s\n" "${FUNCNAME} ran successfully." && return 0
}


function T1Brain_prep()
{
  local t1Brain=$1
  local t1Brain_outDir=$2
  printf "\n\n%s\n\n" "....Preparing T1Brain data"

  ConvertToNifti ${t1Brain}

  clobber ${t1Brain_outDir}/T1_brain.nii.gz &&\
  cp ${t1Head} ${t1Head_outDir}/T1_brain.nii.gz ||\
  { printf "%s\n" "cp ${t1Brain} ${t1Brain_outDir}/T1_brain.nii.gz failed" "exiting ${FUNCNAME} function" && return 1 }

  printf "%s\n" "Reorienting T1Brain to RPI"
  clobber ${t1Brain_outDir}/T1_brain_RPI.nii.gz &&\
  RPI_orient ${t1Brain_outDir}/T1_brain.nii.gz ||\
  { printf "%s\n" "Re-Orientation failed, exiting ${FUNCNAME} function" && return 1 }

  clobber ${t1Brain_outDir}/T1_brain_RPI.nii.gz/brainMask.nii.gz &&\
  fslmaths ${t1Brain_outDir}/T1_brain_RPI.nii.gz -bin ${t1Brain_outDir}/T1_brain_RPI.nii.gz/brainMask.nii.gz -odt char ||\
  { printf "%s\n" "Brain Masking failed, exiting ${FUNCNAME} function" && return 1 }

  printf "%s\n" "${FUNCNAME} ran successfully." && return 0
}

function epi_prep() 
{
  local epi=$1
  local epi_outDir=$2

  printf "\n\n%s\n\n" "....Preparing EPI data"

  ConvertToNifti ${epi}

  clobber ${epi_outDir}/RestingStateRaw.nii.nii.gz &&\
  cp ${epi} ${epi_outDir}/tmpRestingStateRaw.nii.gz &&\
  RPI_orient ${epi_outDir}/tmpRestingStateRaw.nii.gz &&\
  mv ${epi_outDir}/tmpRestingStateRaw_RPI.nii.gz ${epi_outDir}/RestingStateRaw.nii.gz &&\
  rm ${epi_outDir}/tmpRestingStateRaw.nii.gz ||\
  { printf "%s\n" "Re-Orientation failed" "exiting ${FUNCNAME} function" && return 1 }

  printf "%s\n" "${FUNCNAME} ran successfully." && return 0
}

function FieldMapPhase_prep()
{
  local fieldMapPhase=$1
  local FieldMapPhase_outDir=$2

  printf "\n\n%s\n\n" "....Preparing FieldMapPhase data"

  ConvertToNifti ${FieldMapPhase}

  clobber ${FieldMapPhase_outDir}/FieldMapPhase.nii.gz &&\
  cp ${FieldMapPhase} ${FieldMapPhase_outDir}/FieldMapPhase.nii.gz ||\
  { printf "%s\n" "cp ${FieldMapPhase} ${FieldMapPhase_outDir}/FieldMapPhase.nii.gz failed" "exiting ${FUNCNAME} function" && return 1 }

  printf "%s\n" "Reorienting FieldMapPhase to RPI"
  clobber ${FieldMapPhase_outDir}/FieldMapPhase_RPI.nii.gz &&\
  RPI_orient ${FieldMapPhase_outDir}/FieldMapPhase.nii.gz ||\
  { printf "%s\n" "Re-Orientation failed, exiting ${FUNCNAME} function" && return 1 }

  printf "%s\n" "${FUNCNAME} ran successfully." && return 0
}

function FieldMapMag_prep()
{
  local fieldMapMag=$1
  local FieldMapMag_outDir=$2

  printf "\n\n%s\n\n" "....Preparing FieldMapMag data"

  ConvertToNifti ${FieldMapMag}

  clobber ${FieldMapMag_outDir}/FieldMapMag.nii.gz &&\
  cp ${FieldMapMag} ${FieldMapMag_outDir}/FieldMapMag.nii.gz ||\
  { printf "%s\n" "cp ${FieldMapMag} ${FieldMapMag_outDir}/FieldMapMag.nii.gz failed" "exiting ${FUNCNAME} function" && return 1 }

  printf "%s\n" "Reorienting FieldMapMag to RPI"
  clobber ${FieldMapMag_outDir}/FieldMapMag_RPI.nii.gz &&\
  RPI_orient ${FieldMapMag_outDir}/FieldMapMag.nii.gz ||\
  { printf "%s\n" "Re-Orientation failed, exiting ${FUNCNAME} function" && return 1 }

  clobber ${FieldMapMag_outDir}/fieldMapMag_mask.nii.gz &&\
  bet ${FieldMapMag_outDir}/FieldMapMag_RPI.nii.gz ${FieldMapMag_outDir}/fieldMapMag -m -n ||\
  { printf "%s\n" "bet failed, exiting ${FUNCNAME} function" && return 1 }

  clobber ${FieldMapMag_outDir}/fieldMapMag_mask_eroded.nii.gz &&\
  fslmaths ${FieldMapMag_outDir}/fieldMapMag_mask.nii.gz -ero ${FieldMapMag_outDir}/fieldMapMag_mask_eroded.nii.gz ||\
  { printf "%s\n" "erosion failed, exiting ${FUNCNAME} function" && return 1 }

  clobber ${FieldMapMag_outDir}/fieldMapMag_RPI_stripped.nii.gz &&\
  fslmaths ${FieldMapMag_outDir}/fieldMapMag_RPI.nii.gz -mul ${FieldMapMag_outDir}/fieldMapMag_mask_eroded.nii.gz ${FieldMapMag_outDir}/fieldMapMag_RPI_stripped.nii.gz ||\
  { printf "%s\n" "masking failed, exiting ${FUNCNAME} function" && return 1 }

  printf "%s\n" "${FUNCNAME} ran successfully." && return 0
}

function FieldMap_prep()
{
  local phase=$1
  local mag=$2
  local fieldMap_outDir=$3
  local scannertype=$4

  printf "\n\n%s\n\n" "....Prepping FieldMap data (from Phase and Magnitude images) for subsequent registration steps"

  case "${scannertype}" in
    'SEIMENS')
        clobber ${outDir}/func/EPItoT1optimized/fieldMap_prepped.nii.gz &&\
        fsl_prepare_fieldmap SIEMENS ${phase} ${mag} ${outDir}/func/EPItoT1optimized/fieldMap_prepped.nii.gz $deltaTE ||\
        { printf "%s\n" "SEIMENS: FieldMap_prep failed, exiting ${FUNCNAME} function" && return 1 }
        ;;
    'GE')
        echo "this code is not implemented, exiting ${FUNCNAME} with error" && return 1
        ;;
  esac

  printf "%s\n" "${FUNCNAME} ran successfully." && return 0  
}

#############################   MAIN   ###########################
#Quick check for input data. Exit with error if data is missing
if [[ $datafile == "" ]]; then
  echo "Error: data file must be specified with the -i option"
  exit 1
fi

#Quick check for output directory. Exit with error if data is missing
if [[ $outDir == "" ]]; then
  echo "Error: output Directory must be specified with the -o option"
  exit 1
fi

#Check for output directory flag and sub-directory creation if this is set
mkdir -p ${outDir}/{func/EPItoT1optimized,anat,fieldMap,log}



  #A few default parameters (if input not specified, these parameters are assumed)
  if [[ $tr == "" ]]; then
    tr=2
  fi

  if [[ $deltaTE == "" ]]; then
    deltaTE=2.46
  fi


#Assuming TR is entered as seconds (defualt is 2), for input to AFNI's "to3D"
trMsec=$(echo $tr 1000 | awk '{print $1*$2}')


echo "Running $0 ..."
 


###### Basic Input/variables ########################################

#Input files
t1Head=$(awk '{print $1}' $datafile)
t1Brain=$(awk '{print $2}' $datafile)
epi=$(awk '{print $3}' $datafile)  
if [[ $fieldMapFlag == 1 ]]; then
  fieldMapPhase=$(awk '{print $4}' $datafile)
  fieldMapMag=$(awk '{print $5}' $datafile)
fi

#Checking for appropriate input data
if [ "$t1Head" == "" ]; then
  echo "T1 (with skull) must be set in order to run this script."
  exit 1
fi

if [ "$t1Brain" == "" ]; then
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
epiDir=$(dirname $epi)
epiName=$(basename ${epi})

t1HeadDir=$(dirname $t1Skull)
t1HeadName=$(basename $t1Skull)

t1BrainDir=$(dirname $t1)
t1BrainName=$(basename $t1)

if [[ $fieldMapFlag == 1 ]]; then

  fieldMapPhaseDir=$(dirname $fieldMapPhase)
  fieldMapPhasename=$(basename $fieldMapPhase)

  fieldMapMagDir=$(dirname $fieldMapMag)
  fieldMapMagname=$(basename $fieldMapMag)
fi


##Echo out all input parameters into a log


echo "------------------------------------" >> $outDir/log/DataPrep.log
echo "-i $datafile" >> $outDir/log/DataPrep.log
echo "-o $outDir" >> $outDir/log/DataPrep.log
if [[ ${clob} == true ]]; then
  echo "-c" >> $outDir/log/DataPrep.log
fi

echo "-t $tr" >> $outDir/log/DataPrep.log
if [[ $fieldMapFlag == 1 ]]; then
  echo "-f" >> $outDir/log/DataPrep.log
  echo "-F $deltaTE" >> $outDir/log/DataPrep.log
fi
echo "$(date)" >> $outDir/log/DataPrep.log
echo "" >> $outDir/log/DataPrep.log



#Processing T1Skull
T1Head_prep ${t1Head} ${outDir}/anat | tee -a ${outDir}/log/DataPrep.log ||\
{ printf "%s\n" "T1Head_prep failed, exiting script" | tee -a ${outDir}/log/DataPrep.log && exit 1 }
#Processing T1brain
T1Brain_prep ${t1Brain} ${outDir}/anat | tee -a ${outDir}/log/DataPrep.log ||\
{ printf "%s\n" "T1Brain_prep failed, exiting script" | tee -a ${outDir}/log/DataPrep.log && exit 1 }
#processing EPI
epi_prep ${epi} ${outDir}/func | tee -a ${outDir}/log/DataPrep.log ||\
{ printf "%s\n" "epi_prep failed, exiting script" | tee -a ${outDir}/log/DataPrep.log && exit 1 }

if [[ $fieldMapFlag == 1 ]]; then
  ###### FieldMap (Phase)
  FieldMapPhase_prep ${fieldMapPhase} ${outDir}/fieldMap | tee -a ${outDir}/log/DataPrep.log ||\
  { printf "%s\n" "FieldMapPhase_prep failed, exiting script" | tee -a ${outDir}/log/DataPrep.log && exit 1 }
  ###### FieldMap (Magnitude)    
  FieldMapMag_prep ${fieldMapMag} ${outDir}/fieldMap | tee -a ${outDir}/log/DataPrep.log ||\
  { printf "%s\n" "FieldMapMag_prep failed, exiting script" | tee -a ${outDir}/log/DataPrep.log && exit 1 }
  
  ###### FieldMap (Prepped) ########################################
  FieldMap_prep ${outDir}/fieldMap/FieldMapPhase_RPI.nii.gz ${outDir}/fieldMap/fieldMapMag_RPI_stripped.nii.gz | tee -a ${outDir}/log/DataPrep.log ||\
  { printf "%s\n" "FieldMap_prep failed, exiting script" | tee -a ${outDir}/log/DataPrep.log && exit 1 }
fi
 
printf "\n\n%s\n\n" "$0 Complete"