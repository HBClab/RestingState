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
      te=$OPTARG #is this argument used?
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
      ;;
    ?)
      printCommandLine
      ;;
     esac
done
#############################   HELPER FUNCTIONS   #############################
function printCommandLine()
{
  echo ""
  echo "Usage: dataPrep.sh -i datafile -o outputDirectory -c -t TR -T TE -f -F 2.46" # ADD in -S?
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
  echo "   -S Specify which scanner the fieldmap data was acquired on (SIEMENS or GE)"
  echo "   -F deltaTE of the fieldMap (in s) (default to 2.46 s)"
  echo "         *This scan be obtained from the difference in TE between the Phase and Magnitude images"
  echo "           e.g.:, TE(Phase)=2550, TE(Mag)=5010; deltaTE=2460 m (2.46s)"
  echo "       **If using DICOM as input for the FieldMap data, delaTE will be calculated from the header information."
  echo ""
  echo ""
  echo "     A few notes:"
  echo "       *If fieldMap correction is to be run, you must ALSO run the '-f' flag & '-S' flag"  #-s or -S? #JK: -S capital S is the correct term. 
  echo "       *The T1 files MUST be in NIFTI format"
  echo "         ** The skull-stripped file will be renamed T1_MNI_brain.  The image with skull will be renamed T1_MNI."
  echo "       *If EPI is in DICOM format, it will be converted to NIFTI.  If already NIFTI, it will be checked for"
  echo "        naming convention and orientation."
  echo "       *TR, deltaTE will be sourced from DICOM header (will overwrite flag-settings)."
  echo "       *Please refrain from putting '.' in the names of files (e.g. sub1.post.nii.gz should be sub1_post.nii.gz)" #JK: added suggested precondition for ConvertToNifti
  echo ""
  exit 1
}

##################
#function: clobber
##################
#purpose: checks to see if files exist and overwrites them when clob is set to true
##################
#input: any number of filenames that may or may not exist
##################
#output: a 1 (false) or 0 (true)
##################
#dependencies: None
##################
#Used in: (almost) Everything
##################
function clobber()
{
  #Tracking Variables
  local -i num_existing_files=0 #this number will be used to compare with how many files should exist
  local -i num_args=$# #this measures the number of files that were passed into the function

  #Tally all existing outputs
  for arg in $@; do #for each file that is passed into this function, do the following:
    if [ -e "${arg}" ] && [ "${clob}" == true ]; then #if the file exists and you want to clobber the results...
      rm -rf "${arg}" #remove the file with prejudice
    elif [ -e "${arg}" ] && [ "${clob}" == false ]; then #if the file exists and you don't want to clobber the results
      num_existing_files=$(( ${num_existing_files} + 1 )) #add one to the counter which measures how many files that were passed into clobber actually exist
      continue #move on to the next file (not really necessary to do this I think)
    elif [ ! -e "${arg}" ]; then #if the file does not exist...
      continue #don't need to do anything, move on to the next file
    else #catch everything else, if you didn't set clob, you can get here.
      echo "clobber is not set, did you set the variable clob?" #JAMES-would it be better to change this to something like "clobber not set"? "How did you get here?" isn't a helpful error message
      return 1 #don't run the command
      #JK: good point, when I made this function, I actually didn't know how to get here, but subsequent testing has shown that not setting clob gets you here.
    fi
  done

  #see if the command should be run by checking if the requisite files exist.
  #0=true
  #1=false
  if [ ${num_existing_files} -lt ${num_args} ]; then #if all the files that are supposed to exist don't...
    return 0 #return 0 and run the command
  else #all the files exist
    return 1 #don't run the command
  fi

  #example usage
  #clobber test.nii.gz &&\
  #fslmaths input.nii.gz -mul 10 test.nii.gz
}

##################
#function: RPI_orient
##################
#purpose: Checks to see if input is in R->L,P->A,I->S orientation, and switches the image around if it isn't
##################
#input: a 3d nifti image
##################
#output: a 3d nifti image in RPI orientation
##################
#dependencies: FSL
##################
#Used in: *_prep functions
##################
function RPI_orient() {
    #JK: probably overkill to check the variable was set without error.
    local infile=$1 &&\
    #-z tests if a string is null, so what I'm saying here is:
    #if the variable ${infile} is not an empty string (return 0) then don't run the following command 
    #if the variable ${infile} is an empty string (return 1), then do run the next command.
    [ ! -z  "${infile}" ] ||\
    #I used () brackets, but should be {} I believe.
    { printf '%s\n' "${FUNCNAME[0]}, input not defined" && return 1 ;} #JAMES-Not clear how this conditional works. Please comment to explain.
    #JK: added some comments to the function

    #Determine qform-orientation to properly reorient file to RPI (MNI) orientation
  xorient=`fslhd ${infile} | grep "^qform_xorient" | awk '{print $2}' | cut -c1`
  yorient=`fslhd ${infile} | grep "^qform_yorient" | awk '{print $2}' | cut -c1`
  zorient=`fslhd ${infile} | grep "^qform_zorient" | awk '{print $2}' | cut -c1`

  native_orient=${xorient}${yorient}${zorient}

  echo "native orientation = ${native_orient}"

  if [ "${native_orient}" != "RPI" ]; then #setting flip flags if native orientaiton is not already RPI

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
    local warnFlag=`fslswapdim ${infile} ${flipFlag} ${infile%.nii.gz}_RPI.nii.gz`
    local warnFlagCut=`echo ${warnFlag} | awk -F":" '{print $1}'`

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

##################
#function: ConvertToNifti
##################
#purpose: converts images from various formats into nifti
##################
#input: An image in a non-specified format
##################
#output: nifti file
##################
#preconditions: No "." in the names of the input files
##################
#dependencies: FSL, clobber, AFNI (probably others)
##################
#Used in: *_prep
##################
function ConvertToNifti()
{
  #I am overwiting a variable name in the functions, so I need to a global variable, I think this is the way to do it. #JAMES-What variable are you overwriting? Unclear
  #JK: I am overwriting whatever variable is passed into __input. for example if ${t1head} is passed into __input
  #and t1head used to equal /some/path/to/dicoms/*dcm, then this function would overwrite what t1head points to, making it a nifti file instead
  # such as t1head=/some/path/to/dicoms/t1head.nii.gz or something like that.
  # I am not married to this method and I am open to just giving the nifti file a different variable name such as t1headnii.
  __input=$1
  #local variables mean they do not interfere with the main script.
  local inputDir=$(dirname ${__input})
  local inputBase=$(basename ${__input})
  #this gets rid of anything before the first ".", please don't put "." in the name of the file. #JAMES-if that's the case, this should be documented in the helper call for dataPrep.sh
  local inputSuffix=${inputBase#*.}
case "${inputSuffix}" in
  'dcm')
      echo "code not implemented (needs to reset epi variable)" && return 1 #JAMES-assuming this is temporary/placeholder #JK: you are correct, idk what type of dicom processing is wanted/necessary.
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

#############################   MAIN FUNCTIONS   #############################
##################
#function: SoftwareCheck
##################
#purpose: makes sure you have the prerequisite software to run the commands
##################
#input: software/commands
##################
#output: 0 : all software exists
#        1 : at least one command/software doesn't exist
##################
#dependencies: None
##################
#Used in: MAIN
##################
function SoftwareCheck()
{
  local missing_command=0
  local com #JAMES-what does declare/com mean?
              #JK: in this context declare makes the variable local.
              #I was under the impression if I used 'local' I would have to set the variable
              #in the same line. I was wrong. corrected
  for com in $@; do
    local command_check=$(which ${com})
    if [[ "${command_check}" == "" ]]; then
      local missing_command=1
      printf "%s\n" "${command} is missing"
    fi
  done

  return ${missing_command}
}
##################
#function: T1Head_prep
##################
#purpose: prepares T1Head (brain+skull) by making sure it's in nifti format and oriented correctly
##################
#input: A T1 Head image
#       An output directory
##################
#output: A T1Head nifti file in RPI orientation
##################
#dependencies: FSL, clobber
##################
#Used in: MAIN
##################
function T1Head_prep()
{
  #assign function input variables
  local t1Head=$1
  local t1Head_outDir=$2
  printf "\n\n%s\n\n" "....Preparing T1Head data"

  #convert whatever image that was passed in to a nifti file (Not Implemented)
  ConvertToNifti ${t1Head}

  #copy the nifti file to the processing directory
  clobber ${t1Head_outDir}/T1_head.nii.gz &&\ #JAMES so this reads to me as "run clobber on T1_head.nii.gz AND..."
  { cp ${t1Head} ${t1Head_outDir}/T1_head.nii.gz ||\ #JAMES Copy T1 head to the directory OR...
  { printf "%s\n" "cp ${t1Head} ${t1Head_outDir}/T1_head.nii.gz failed" "exiting ${FUNCNAME} function" && return 1 ;} ;} #JAMES print error statements"

  #JAMES-I appreciate the detailed explanation below, but I guess coming from MATLAB or other usage of logical operators, I see && and assume it's an AND conditional, likewise || implies an OR conditional to me. I kinda get how that holds here, but the 1/0 status of the clobber operation on the first line relative to the rest of the statement REALLY confuses things for me. If i had to debug this, how would i know if my error was because clobber was set wrong, or because there isn't a file to copy, or because there's an error with copy? Is there any way to separate the clobber operation from the rest of this? I think it would help a lot with readability.
  #JK: good comment, and drives an important underlying structure to all bash commands. 
  #Namely, all bash commands either return a 0 or non-zero (one in my case) status. 
  #so the cp command will return either a zero (it ran successfully, equivalent to a true status), or a non-zero number (equivalent to a false status)
  #the && and || conditionals only care about whether each command was run successfully (returned a zero) or not successfully (returned a non-zero)
  #I updated to the clobber function to not run any commands if clob is not set. 
  #to get at your question on how to tell whether the clobber function failed, or if the cp function failed:
  #the clobber function will return the error message (updated) and a one, meaning the cp command will not be run.
  #you will be able to tell it was the clobber function because of the error message clobber gives.
  #I am unaware of other ways clobber could fail.
  #if clobber runs successfully, then I can tell whether cp runs successfully by seeing if a error message saying cp failed appears.

  #^^^^the logic:
  #if the file exists and clob=false, don't run the next two commands.
  #if the file doesn't exist, do the copy command; then
    #if the copy command fails (returns a 1), print the error message and exit the function with a failure (return with a 1)
  #The cp and printf commands are grouped together because I never want to run one without the other.
  #If I don't group them and the clobber command returns a 1,
  # then the print statement will automatically print, even though the command didn't fail, it just wasn't ran.
  #how the logic connectors work: (A && (B || (C && D)))
  #In english:
  # if A evaluates to be false, then don't run the next argument
  # if A evaluates to be true, then run the next argument (B)
    # if B evaluates to be true, then the logic statement is over
    # if B evaluates to be false, then run C
      # if C evaluates to be false, then the logic statement is over
      # if C evaluates to be true, then run D
        # if D evaluates to be true, then the logic statement is over
        # if D evaluates to be false, then the logic statement is over

  #How it applies to this statement

  #clob=false
  #A: if the file exists, don't run the next command
  #A: if the file does not exist, run the next command
    #B: if the cp command succeeds, don't run the error statements
    #B: if the cp command fails, run the error statements
      #C: printing the error message fails (should never happen)
      #C: print the error message and return a bad result (D)
        #D: returns the bad result
        #D: can't return the bad result (should never happen)


  #clob=true
  #A: if the file exists, run the next command
  #A: if the file does not exist, run the next command
    #B: if the cp command succeeds, don't run the error statements
    #B: if the cp command fails, run the error statements
      #C: printing the error message fails (should never happen)
      #C: print the error message and return a bad result (D)
        #D: returns the bad result
        #D: can't return the bad result (should never happen)






  #reorient the nifti file in the processing directory
  printf "%s\n" "Reorienting T1Head to RPI"
  clobber ${t1Head_outDir}/T1_head_RPI.nii.gz &&\
  { RPI_orient ${t1Head_outDir}/T1_head.nii.gz ||\
  { printf "%s\n" "Re-Orientation failed, exiting ${FUNCNAME} function" && return 1 ;} ;}

  printf "%s\n" "${FUNCNAME} ran successfully." && return 0
}

##################
#function: T1Brain_prep
##################
#purpose: prepares T1Brain by making sure it's in nifti format and oriented correctly
##################
#input: A skullstriped T1 image
#       An output directory
##################
#output: A T1Brain nifti file in RPI orientation
#        Brain Mask
##################
#dependencies: FSL, clobber
##################
#Used in: MAIN
##################
function T1Brain_prep()
{
  local t1Brain=$1
  local t1Brain_outDir=$2
  printf "\n\n%s\n\n" "....Preparing T1Brain data"

  #convert whatever image that was passed in to a nifti file (Not Implemented)
  ConvertToNifti ${t1Brain}

  #copy the nifti file to the processing directory
  clobber ${t1Brain_outDir}/T1_brain.nii.gz &&\
  { cp ${t1Brain} ${t1Brain_outDir}/T1_brain.nii.gz ||\
  { printf "%s\n" "cp ${t1Brain} ${t1Brain_outDir}/T1_brain.nii.gz failed" "exiting ${FUNCNAME} function" && return 1 ;} ;}

  #reorient the nifti file in the processing directory
  printf "%s\n" "Reorienting T1Brain to RPI"
  clobber ${t1Brain_outDir}/T1_brain_RPI.nii.gz &&\
  { RPI_orient ${t1Brain_outDir}/T1_brain.nii.gz ||\
  { printf "%s\n" "Re-Orientation failed, exiting ${FUNCNAME} function" && return 1 ;} ;}

  #make a binary brainmask from the reoriented T1
  printf "%s\n" "Making a T1 brain Mask"
  clobber ${t1Brain_outDir}/brainMask.nii.gz &&\
  { fslmaths ${t1Brain_outDir}/T1_brain_RPI.nii.gz -bin ${t1Brain_outDir}//brainMask.nii.gz -odt char ||\
  { printf "%s\n" "Brain Masking failed, exiting ${FUNCNAME} function" && return 1 ;} ;}

  printf "%s\n" "${FUNCNAME} ran successfully." && return 0
}

##################
#function: epi_prep
##################
#purpose: prepares EPI by making sure it's in nifti format and oriented correctly
##################
#input: EPI image
#       An output directory
##################
#output: EPI nifti file in RPI orientation
##################
#dependencies: FSL, clobber
##################
#Used in: MAIN
##################
function epi_prep()
{
  local epi=$1
  local epi_outDir=$2

  printf "\n\n%s\n\n" "....Preparing EPI data"

  #convert whatever image that was passed in to a nifti file (Not Implemented)
  ConvertToNifti ${epi}

  #this does the copying, orienting and renaming, I don't think a temporary file is necessary #JAMES-okay, but the logic of four && conditionals in a row need to be better clarified
  #JK: each && statement is saying that if the previous command returned a 0, run the next command.
  #if one of the commands fails within the daisy chain of &&, then jump to the || and print the error message
  clobber ${epi_outDir}/RestingStateRaw.nii.nii.gz &&\
  { cp ${epi} ${epi_outDir}/tmpRestingStateRaw.nii.gz &&\
  RPI_orient ${epi_outDir}/tmpRestingStateRaw.nii.gz &&\
  mv ${epi_outDir}/tmpRestingStateRaw_RPI.nii.gz ${epi_outDir}/RestingStateRaw.nii.gz &&\
  rm ${epi_outDir}/tmpRestingStateRaw.nii.gz ||\
  { printf "%s\n" "Re-Orientation failed" "exiting ${FUNCNAME} function" && return 1 ;} ;}

  printf "%s\n" "${FUNCNAME} ran successfully." && return 0
}

##################
#function: FieldMapPhase_prep
##################
#purpose: prepares FieldMapPhase image by making sure it's in nifti format and oriented correctly
##################
#input: Fieldmap Phase image
#       An output directory
##################
#output: Fieldmapphase nifti file in RPI orientation
##################
#dependencies: FSL, clobber
##################
#Used in: MAIN
##################
function FieldMapPhase_prep()
{
  local fieldMapPhase=$1
  local FieldMapPhase_outDir=$2

  printf "\n\n%s\n\n" "....Preparing FieldMapPhase data"

  #convert whatever image that was passed in to a nifti file (Not Implemented)
  ConvertToNifti ${FieldMapPhase}

  #copy the nifti file to the processing directory
  clobber ${FieldMapPhase_outDir}/FieldMapPhase.nii.gz &&\
  { cp ${FieldMapPhase} ${FieldMapPhase_outDir}/FieldMapPhase.nii.gz ||\
  { printf "%s\n" "cp ${FieldMapPhase} ${FieldMapPhase_outDir}/FieldMapPhase.nii.gz failed" "exiting ${FUNCNAME} function" && return 1 ;} ;}

  #reorient the nifti file in the processing directory
  printf "%s\n" "Reorienting FieldMapPhase to RPI"
  clobber ${FieldMapPhase_outDir}/FieldMapPhase_RPI.nii.gz &&\
  { RPI_orient ${FieldMapPhase_outDir}/FieldMapPhase.nii.gz ||\
  { printf "%s\n" "Re-Orientation failed, exiting ${FUNCNAME} function" && return 1 ;} ;}

  printf "%s\n" "${FUNCNAME} ran successfully." && return 0
}

##################
#function: FieldMapMag_prep
##################
#purpose: prepares FieldMap magnitude image by making sure it's in nifti format and oriented correctly
##################
#input: Field Map magnitude
#       An output directory
##################
#output: FieldMap Magnitude nifti file in RPI orientation
#        Brain Mask
##################
#dependencies: FSL, clobber
##################
#Used in: MAIN
##################
function FieldMapMag_prep()
{
  local fieldMapMag=$1
  local FieldMapMag_outDir=$2

  printf "\n\n%s\n\n" "....Preparing FieldMapMag data"

  #convert whatever image that was passed in to a nifti file (Not Implemented)
  ConvertToNifti ${FieldMapMag}

  #copy the nifti file to the processing directory
  clobber ${FieldMapMag_outDir}/FieldMapMag.nii.gz &&\
  { cp ${FieldMapMag} ${FieldMapMag_outDir}/FieldMapMag.nii.gz ||\
  { printf "%s\n" "cp ${FieldMapMag} ${FieldMapMag_outDir}/FieldMapMag.nii.gz failed" "exiting ${FUNCNAME} function" && return 1 ;} ;}

  #reorient the nifti file in the processing directory to RPI.
  printf "%s\n" "Reorienting FieldMapMag to RPI"
  clobber ${FieldMapMag_outDir}/FieldMapMag_RPI.nii.gz &&\
  { RPI_orient ${FieldMapMag_outDir}/FieldMapMag.nii.gz ||\
  { printf "%s\n" "Re-Orientation failed, exiting ${FUNCNAME} function" && return 1 ;} ;}

  #make a brain mask for the image using FSL's bet.
  clobber ${FieldMapMag_outDir}/FieldMapMag_mask.nii.gz &&\
  { bet ${FieldMapMag_outDir}/FieldMapMag_RPI.nii.gz ${FieldMapMag_outDir}/FieldMapMag -m -n ||\
  { printf "%s\n" "bet failed, exiting ${FUNCNAME} function" && return 1 ;} ;}

  #make the brainmask smaller: reason: ???
  clobber ${FieldMapMag_outDir}/FieldMapMag_mask_eroded.nii.gz &&\
  { fslmaths ${FieldMapMag_outDir}/FieldMapMag_mask.nii.gz -ero ${FieldMapMag_outDir}/FieldMapMag_mask_eroded.nii.gz ||\
  { printf "%s\n" "erosion failed, exiting ${FUNCNAME} function" && return 1 ;} ;}

  #multiply the brainmask with the fieldmap to get a brain masked fieldmap.
  clobber ${FieldMapMag_outDir}/FieldMapMag_RPI_stripped.nii.gz &&\
  { fslmaths ${FieldMapMag_outDir}/FieldMapMag_RPI.nii.gz -mul ${FieldMapMag_outDir}/FieldMapMag_mask_eroded.nii.gz ${FieldMapMag_outDir}/FieldMapMag_RPI_stripped.nii.gz ||\
  { printf "%s\n" "masking failed, exiting ${FUNCNAME} function" && return 1 ;} ;}

  printf "%s\n" "${FUNCNAME} ran successfully." && return 0
}

##################
#function: FieldMap_prep
##################
#purpose: prepares FieldMap to be used in EPI registration
##################
#input: Fieldmap magnitude
#       Fieldmap phase
#       dTE
#       outDir
#       scannertype
##################
#output: ????
##################
#dependencies: FSL, clobber
##################
#Used in: MAIN
##################
function FieldMap_prep()
{
  local phase=$1
  local mag=$2
  local dTE=$3
  local fieldMap_outDir=$4
  local scannertype=$5

  printf "\n\n%s\n\n" "....Prepping FieldMap data (from Phase and Magnitude images) for subsequent registration steps"

  case "${scannertype}" in
    'SEIMENS')
        clobber ${outDir}/func/EPItoT1optimized/fieldMap_prepped.nii.gz &&\
        { fsl_prepare_fieldmap SIEMENS ${phase} ${mag} ${outDir}/func/EPItoT1optimized/fieldMap_prepped.nii.gz $dTE ||\
         printf "%s\n" "SIEMENS: FieldMap_prep failed, exiting ${FUNCNAME} function" && return 1 ;}
        ;;
    'GE')
        echo "this code is not implemented, exiting ${FUNCNAME} with error" && return 1
        ;;
  esac

  printf "%s\n" "${FUNCNAME} ran successfully." && return 0
}


#############################   MAIN   #############################

#DATA CHECKS AND VARIABLE SETTING

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
mkdir -p ${outDir}/{func/EPItoT1optimized,anat,log}
if [[ fieldMapFlag -eq 1 ]]; then
  mkdir -p ${outDir}/func/fieldmap
fi



  #A few default parameters (if input not specified, these parameters are assumed)
  if [[ $tr == "" ]]; then
    tr=2
  fi

  if [[ $deltaTE == "" ]]; then
    deltaTE=2.46
  fi


echo "Running $0 ..."



###### Basic Input/variables

#Input files
t1Head=$(awk '{print $1}' $datafile)
t1Brain=$(awk '{print $2}' $datafile)
epi=$(awk '{print $3}' $datafile)
if [[ $fieldMapFlag == 1 ]]; then #Will need to update for GE fieldmap format
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

t1HeadDir=$(dirname $t1Head)
t1HeadName=$(basename $t1Head)

t1BrainDir=$(dirname $t1Brain)
t1BrainName=$(basename $t1Brain)

if [[ $fieldMapFlag == 1 ]]; then

  fieldMapPhaseDir=$(dirname $fieldMapPhase)
  fieldMapPhasename=$(basename $fieldMapPhase)

  fieldMapMagDir=$(dirname $fieldMapMag)
  fieldMapMagname=$(basename $fieldMapMag)
fi


##Echo out all input parameters into a log
printf "%s\n" "------------------------" | tee -a ${outDir}/log/DataPrep.log
date >> ${outDir}/log/DataPrep.log
printf "%s\t" "$0 $@" | tee -a ${outDir}/log/DataPrep.log
#$0: name of the script
#$@ all of the arguments given to the script (including flags)


# MAIN PROCESSING COMMANDS

#check software prerequisites (fsl & afni currently)
SoftwareCheck fsl afni ||\
{ printf "%s\n" "Prerequisite software doesn't exist, exiting script with errors" && exit 1 ;}

#Processing T1Skull
T1Head_prep ${t1Head} ${outDir}/anat | tee -a ${outDir}/log/DataPrep.log &&\
{ [[ ${PIPESTATUS[0]} -ne 0 ]] && printf "%s\n" "T1Head_prep failed, exiting script" | tee -a ${outDir}/log/DataPrep.log && exit 1; }
#Processing T1brain
T1Brain_prep ${t1Brain} ${outDir}/anat | tee -a ${outDir}/log/DataPrep.log &&\
{ [[ ${PIPESTATUS[0]} -ne 0 ]] && printf "%s\n" "T1Brain_prep failed, exiting script" | tee -a ${outDir}/log/DataPrep.log && exit 1; }
#processing EPI
epi_prep ${epi} ${outDir}/func | tee -a ${outDir}/log/DataPrep.log &&\
{ [[ ${PIPESTATUS[0]} -ne 0 ]] && printf "%s\n" "epi_prep failed, exiting script" | tee -a ${outDir}/log/DataPrep.log && exit 1; }

if [[ $fieldMapFlag == 1 ]]; then
  #Processing FieldMap (Phase)
  FieldMapPhase_prep ${fieldMapPhase} ${outDir}/fieldMap | tee -a ${outDir}/log/DataPrep.log &&\
  { [[ ${PIPESTATUS[0]} -ne 0 ]] && printf "%s\n" "FieldMapPhase_prep failed, exiting script" | tee -a ${outDir}/log/DataPrep.log && exit 1; }
  #Processing FieldMap (Magnitude)
  FieldMapMag_prep ${fieldMapMag} ${outDir}/fieldMap | tee -a ${outDir}/log/DataPrep.log ||\
  { [[ ${PIPESTATUS[0]} -ne 0 ]] && printf "%s\n" "FieldMapMag_prep failed, exiting script" | tee -a ${outDir}/log/DataPrep.log && exit 1; }
  #Processing FieldMap (Prepped)
  FieldMap_prep ${outDir}/fieldMap/FieldMapPhase_RPI.nii.gz ${outDir}/fieldMap/fieldMapMag_RPI_stripped.nii.gz | tee -a ${outDir}/log/DataPrep.log ||\
  { [[ ${PIPESTATUS[0]} -ne 0 ]] && printf "%s\n" "FieldMap_prep failed, exiting script" | tee -a ${outDir}/log/DataPrep.log && exit 1; }
fi
#JAMES -this all looks fine. Do you know if the tee command is standard across Linux distros? I've never encountered this function before.
#JK: good question, tee, while not as popular as mv or cp, is a core linux function and should be available on most instances of linux
#^^^^logic of command format
#The function is called and the function's output is printed out to the screen (stout) and into the log file (appending, not overwrite) via the "tee" command
#Since the tee command will always return 0 unless something is wrong with bash, we need to do a separate check to see if the function failed
#PIPESTATUS is a builtin bash variable array that we can use to query whether a particular command in a pipe sequence (e.g. func input | tee -a log)
#succeeded or failed. The first element in the PIPESTATUS array is the function we called such as T1Head_prep. So if the T1Head_prep function exited with a non-zero
#status then the error message will be printed out to the terminal (stout) and to the log. The script will also exit with error.
printf "\n\n%s\n\n" "$0 Complete"
