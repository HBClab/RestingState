#!/bin/bash

########################################################################
# Two main processing pipelines: "Classic" and "Melodic"
#
#   Classic:
#     -P 1:
#       dataPrep
#       qualityCheck
#     -P 2a:
#       restingStatePreprocess
#       removeNuisanceRegressor
#       motionScrub
#       seedVoxelCorrelation
#
#
#   Melodic:
#     -P 1:
#       dataPrep
#       qualityCheck
#     -P 2:
#       restingStateMelodic
#     -P 3:
#       ICA_denoise
#       removeNuisanceRegressor
#       motionScrub
#       seedVoxelCorrelation
########################################################################

scriptPath=`perl -e 'use Cwd "abs_path";print abs_path(shift)' $0`
scriptDir=`dirname $scriptPath`
roiDir=$scriptDir/ROIs


function printCommandLine {
  echo ""
  echo "Usage: processRestingState.sh -i datafile -r ROI -n nuisanceROI -t tr -T te -s smooth -P 1"
  echo ""
  echo "                            -OR-"
  echo ""
  echo "       processRestingState.sh -i datafile -R datafile -N nuisanceDatafile -t tr -T te -s smooth -P 1"
  echo ""
  echo "   where:"
  echo ""
  echo "    Input Data (and related flags)"
  echo "    -------------------"
  echo "   -i Data file having a space-separated list of anatomical and epi images"
  echo "        *Text file with five possible entries:"
  echo "           1) T1 (with skull)"
  echo "           2) T1 (skull-stripped)"
  echo "           3) EPI image"
  echo "           4) FieldMap: Phase image"
  echo "           5) FieldMap: Magnitude image"
  echo ""
  echo "       A few notes:"
  echo "         *If FieldMap correction is to be run, you must ALSO run the '-f' flag"  
  echo "         *The T1 files MUST be in NIFTI format"
  echo "           ** The skull-stripped file will be renamed T1_MNI_brain.  The image with skull will be renamed T1_MNI." 
  echo "         *If EPI is in DICOM format, it will be converted to NIFTI.  If already NIFTI, it will be checked"
  echo "          for naming convention and orientation."
  echo "   -s spatial smoothing (mm) (default to 6mm)"
  echo "   -L lowpass filter frequency (Hz)"
  echo "   -H highpass filter frequency (Hz)"
  echo "        *default is set to NOT pass any low/highpass filter settings and to use restingStatePreprocess"
  echo "         script defaults (.008 < f < .08 Hz)"  
  echo "   -o output directory (will create /anat for T1 data, /func for EPI data) (default is to write to EPI directory)"
  echo "   -c clobber/overwrite previous results"
  echo "   -m MotionScrubb the EPI: O,1 or 2 (default is 0/no)"
  echo "      0 = use non-motionscrubbed EPI only (default)"
  echo "      1 = use motionscrubbed EPI only"
  echo "      2 = use motionscrubbed and non-motionscrubbed EPI (parallel output)"
  echo "   -V Review SeedCorrelation Results (default is to NOT view results).  Setting of this flag will spit out time-series plot"
  echo "      of seed/ROI"
  echo "        *If selected, results seed Maps will be registered to subject's T1 and the MNI 2mm atlas"
  echo ""
  echo ""
  echo ""
  echo "    EPI Data"
  echo "    -------------------"
  echo "   -t TR (seconds) (default to 2 s)"
  echo "   -T TE (milliseconds) (default to 30 ms)"
  echo ""
  echo ""
  echo ""
  echo "    FieldMap Data"
  echo "    -------------------"
  echo "   -f Use FieldMap Correction with BBR (EPI to T1 registration)"
  echo "     *This is only applicable for data acquired on a Siemens scanner"
  echo "   -D dwell time (in seconds)"
  echo "       *dwell time is from the EPI but is only set if FieldMap correction ('-f') is chosen."
  echo "       *If not set and FieldMap correction is flagged ('-f'), default is 0.00056"
  echo "       **If DICOM is used for FieldMap input, dwellTime will be read from the header."
  echo "   -d Phase Encoding Direction"
  echo "      *peDir is from the EPI but is only set if FieldMap correction ('-f') is chosen."
  echo "      *If not set and FieldMap correction is flagged ('-f'), default is -y"
  echo "       **If DICOM is used for FieldMap input, peDir will be read from the header."
  echo "   -F deltaTE of the FieldMap (in mS)"
  echo "       *This scan be obtained from the difference in TE between the Phase and Magnitude images"
  echo "       *If FieldMap correction is called ('-f') and deltaTE is not specified, 2.46 mS is default."
  echo "         *Common TE values are 12.46 for the Magnitude, 10.00 for the Phase."
  echo ""
  echo ""
  echo ""
  echo "    Seed Data"
  echo "    -------------------"
  echo "   -r ROI for seed voxel (can be used multiple times)"
  echo "   -R Data file with seed list, one seed per line"
  echo "        **Use ONLY one option, -r or -R, NOT both"
  echo ""
  echo ""
  echo ""
  echo "    Nuisance Regressors"
  echo "    -------------------"
  echo "   -n nuisance ROI for regression (can be used multiple times)"
  echo "   -N Data file with nuisance ROI list, one ROI per line"
  echo "        **Use ONLY one option, -n or -N, NOT both"
  echo ""
  echo ""
  echo ""
  echo "    Data Streams"
  echo "    -------------------"
  echo "   -P multi-part processing (possibly involving MELODIC**)"
  echo "      1 = Data setup, quality control"
  echo "      2 = MELODIC IC creation, signal/noise determination"
  echo "      2a = High/Lowpass filtering, Nuisance Regression, Motion scrubbing (if chosen with '-m' flag), Network creation"
  echo "        * If this option is chosen, MELODIC/denoising will NOT be performed and step '-P 3' will NOT need to be run"
  echo "      3 = Denoise, Nuisance Regression, Motion scrubbing (if chosen with '-m' flag), Network creation"
  echo "   -I List (comma-separated) of noise IC's from MELODIC ('-P 2)"
  echo "   -l Binary lesion mask"
  echo "      *This is only to be provided for T1 to MNI registration.  The mask MUST be in the anatomical space."
  echo "   -p rsParams file (will be created after Initial '-P 1' run"
  echo "	*With initial run ('-P 1'), ALL further processing flags can be set ('-m, -r, etc.').  These input"
  echo "         flags will be stored in a text file, rsParams (in the EPI output directory).  Further"
  echo "         processing ('-P 2, -P 3') can just point at this text file and variables will be set."
  echo "         IF parameters aren't set initially (for MELODIC, etc.), they MUST be set with appropriate '-P' section"
  echo ""
  echo "                e.g.:"
  echo ""
  echo "       processRestingState.sh -i datafile -r ROI -t tr -T te -s smooth -m 1 -c -P 1"
  echo ""
  echo "		would then require:"
  echo ""
  echo "       processRestingState.sh -p pathToEPIDir/rsParams -P 2"
  echo "       processRestingState.sh -p pathToEPIDir/rsParams -P 3"
  echo ""
  echo ""
  echo "    **Optionally, this script can be run in a three part process (that will require manual intevention):"
  echo "	PartI: Data Preparation and Quality Control"
  echo "	  *This will make sure EPI and T1 are properly oriented and named and give a base for how noisy/bad the"
  echo "           input data is.  The user could  stop at this point, evaluate the"
  echo "	   data (check analysisResults.html in the EPI output directory) to determine if it's worth processing further"
  echo "	PartII: MELODIC IC output"
  echo "	  *The user will need to examine all outputs of MELODIC to evaluate ICs as noise or signal."
  echo "	PartIII:  Denoising data, Nuisance regression, Motion Scrubbing (if set) and Network creation"
  echo "	  *After determining signal ICs from PartII, this step will finish up the processing, first"
  echo "           removing nuisnace regressors further from the signal (Global, WM and CSF signal),"
  echo "	   Motion scrubbing (eliminating TRs with too much motion) and creating network maps from input ROIs"
  echo ""
  echo "  For a list of possible ROIs, see files in $roiDir"
  echo ""
  exit 1
}



# Parse Command line arguments
while getopts “hi:s:L:H:o:cm:Vt:T:fD:d:F:r:R:n:N:P:I:l:p:” OPTION
do
  case $OPTION in
    h)
      printCommandLine
      ;;
    i)
      datafile=`perl -e 'use Cwd "abs_path";print abs_path(shift)' $OPTARG`
      ;;
    s)
      smooth=$OPTARG
      ;;
    L)
      lowpassArg=$OPTARG
      ;;
    H)
      highpassArg=$OPTARG
      ;;
    o)
      outDir=$OPTARG
      outFlag=1
      ;;    
    c)
      overwriteFlag=1
      ;;
    m)
      motionscrubFlag=$OPTARG
      ;;
    V)
      reviewResults=1
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
    D)
      dwellTime=$OPTARG
      ;;
    d)
      peDir=$OPTARG
      ;;
    F)
      deltaTE=$OPTARG
      ;;
    r)
      roiList=`echo $roiList $OPTARG`
      ;;
    R)
      roiList=`cat $OPTARG`
      ;;
    n)
      nuisanceList=`echo $nuisanceList $OPTARG`
      ;;
    N)
      nuisanceList=`cat $OPTARG`
      ;;
    P)
      multiFlag=$OPTARG
      ;;
    I)
      noiseIC=$OPTARG
      ;;
    l)
      lesionMask=$OPTARG
      lesionMaskFlag=1
      ;;
    p)
      rsParamFile=$OPTARG
      rsParamFileSet=1
      ;;
    ?)
      printCommandLine
      ;;
     esac
done




#A few default parameters (if input not specified, these parameters are assumed)
  if [[ $overwriteFlag == "" ]]; then
    overwriteFlag=0
  fi

  if [[ $multiFlag == "" ]]; then
    multiFlag=0
  fi

  if [[ $outFlag == "" ]]; then
    outFlag=0
  fi

  if [[ $motionscrubFlag == "" ]]; then
    motionscrubFlag=0
  fi

  if [[ $fieldMapFlag == "" ]]; then
    fieldMapFlag=0
  fi

  if [[ $reviewResults == "" ]]; then
    reviewResults=0
  fi

  if [[ $rsParamFileSet == "" ]]; then
    rsParamFileSet=0
  fi

  if [[ $lesionMaskFlag == "" ]]; then
    lesionMaskFlag=0
  fi





#Check for multi-flag settings.  One of them has to be used in order to run
if [[ $multiFlag != 1 ]] && [[ $multiFlag != 2 ]] && [[ $multiFlag != 2a ]] && [[ $multiFlag != 3 ]] ; then
  echo "Error: One of the multi-flags must be used.  Please run with either '-P (1, 2, 2a or 3)'"
  exit 1
fi




      
# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% #
###### dataPrep and qualityCheck ############################################################

if [[ $multiFlag == 1 ]]; then

  ###### Basic Input/variables ########################################

  #Directory to dump output paramaters to (where rsParams will reside)
  epi=`sed -n "1p" $datafile | awk '{print $3}'`
  epiDir=`dirname $epi`

  #Set up directories for T1,EPI & FieldMap (if $outDir is specified)
  if [[ $outDir != "" ]]; then
    outDirOption="-o $outDir"

    #EPI directory
    if [[ ! -e $outDir/func ]]; then
      mkdir -p $outDir/func
    fi
    #T1 directory
    if [[ ! -e $outDir/anat ]]; then
      mkdir -p $outDir/anat
    fi
    #FieldMap directory
    if [[ $fieldMapFlag == 1 ]]; then
      if [[ ! -e $outDir/fieldMap ]]; then
        mkdir -p $outDir/fieldMap
      fi
    fi
  else
    outDirOption=""
  fi

  #rsParams log file setup
  if [[ $outDir != "" ]]; then
    rsParamDir=$outDir/func    
  else
    rsParamDir=$epiDir
  fi

  #Variable for output text file
  rsParamFile=$rsParamDir/rsParams

  ###############################################



  ##### Misc variables ######################

  #If user set ROI seedlist from beginning, echo out list to rsParams (can be sourced later)
  if [[ $roiList != "" ]]; then
    for i in $roiList
      do
        seeds="$seeds -r $i"
    done

    echo "seeds=$seeds" >> $rsParamFile
  fi

  #If user set nuisance ROI list from beginning, echo out list to rsParams (can be sourced later)
  if [[ $nuisanceList != "" ]]; then
    for i in $nuisanceList
      do
        nuisanceROI="$nuisanceROI -n $i"
    done

    echo "nuisanceROI=$nuisanceROI" >> $rsParamFile
  fi

  #If Lowpass filter is set from the beginning
  if [[ $lowpassArg != "" ]]; then
    echo "lowpassFilt=$lowpassArg" >> $rsParamFile 
  fi

  #If Highpass filter is set from the beginning
  if [[ $highpassArg != "" ]]; then
    echo "highpassFilt=$highpassArg" >> $rsParamFile
  fi

  #If motionScrub flag is set from the beginning
  if [[ $motionscrubFlag == 1 || $motionscrubFlag == 2 ]]; then
    echo "motionScrub=$motionscrubFlag" >> $rsParamFile
  fi

  #If reviewResults flag is set from the beginning
  if [[ $reviewResults == 1 ]]; then
    echo "reviewResultsFlag=$reviewResults" >> $rsParamFile
  fi

  #If TR is set from the beginning
  if [[ $tr != "" ]]; then
    echo "epiTR=$tr" >> $rsParamFile
  fi

  #If TE is set from the beginning
  if [[ $te != "" ]]; then
    echo "epiTE=$te" >> $rsParamFile
  fi

  #If smoothing kernel is set from the beginning
  if [[ $smooth != "" ]]; then
    echo "epiSmooth=$smooth" >> $rsParamFile
  fi

  #If Phase Encoding direction is set from the beginning
  if [[ $peDir != "" ]]; then
    echo "peDir=$peDir" >> $rsParamFile
  fi

  #If Dwell Time is set from the beginning
  if [[ $dwellTime != "" ]]; then
    echo "epiDwell=$dwellTime" >> $rsParamFile
  fi

  #If deltaTE is set from the beginning
  if [[ $deltaTE != "" ]]; then
    echo "deltaTE=$deltaTE" >> $rsParamFile
  fi

  ###############################################




  ##### Initial processing check/clobber check ######################

  #Check to see if Initial processing has been done
  if [[ -e $rsParamFile ]]; then 
    baseProc=`cat $rsParamFile | grep "IsDone_PartI_" | tail -1`
  fi     

  if [[ $overwriteFlag == 0 ]]  && [[ $baseProc != "" ]]; then
    echo "Base processing for EPI/T1, through qualityCheck, has already been run.  Please set overwrite (-c) option to reprocess."
    exit 1
  fi

  ###############################################




    ##### -P 1 ######################

    ##Start PartI
    #Set up text file to track info
    echo "....Beginning Base processing of EPI/T1 data"
    echo "_PartI_" >> $rsParamFile
    echo "`date`" >> $rsParamFile           

          ##### -P 1 (dataPrep) ######################

              ##### dataPrep variables ######################

              #Initial datafile check and setup (need input files to work with)
              if [[ $datafile == "" ]]; then
                echo "Error: data file must be specified with the -i option"
                exit 1
              fi

              ##Flags that CAN be set but aren't required:
              #-o output directory (will create func, anat, fieldMap (if chosen))
              #-t TR (seconds)
	      #-T TE (ms)
              #-f FieldMapFlag (preprocess FieldMap data)
              #-F deltaTE (only if '-f' is set).  This is optional and can be read from DICOM header
              #-c overWriteFlag (clobber)  

              #TR
              if [[ $tr != "" ]]; then
                trOption="-t $tr"
              else
                trOption=""
              fi

	      #TE
              if [[ $te != "" ]]; then
                teOption="-T $te"
              else
                teOption=""
              fi


              #fieldMapFlag
              if [[ $fieldMapFlag == 1 ]]; then
                fieldMapFlagOption="-f"
              else
                fieldMapFlagOption=""
              fi

              #deltaTe
              deltaTECheck=`cat $rsParamFile | grep "deltaTE=" | tail -1`
              if [[ $deltaTE != "" ]]; then
                deltaTEOption="-F $deltaTE"
              else
                if [[ $deltaTECheck != "" ]]; then
                  deltaTEOption="-F $deltaTECheck"
                else
                  deltaTEOption=""
                fi
              fi

              #Overwrite flag
              if [[ $overwriteFlag == 1 ]]; then
                overwriteOption="-c"
              else
                overwriteOption=""
              fi

              ###############################################
                          
          #Data Prep (Run EPI,T1 & FieldMap (if chosen) through processing stream to get correct name and orientation)
          $scriptDir/dataPrep.sh -i $datafile $outDirOption $trOption $teOption $fieldMapFlagOption $deltaTEOption $overwriteOption

          ###############################################





          ##### -P 1 (qualityCheck) ######################

              ##### qualityCheck variables ######################
  
              #Variables set from dataPrep script.  Source from rsParams file
              epiData=`cat $rsParamFile | grep "epiRaw=" | tail -1 | awk -F"=" '{print $2}'`
              t1Data=`cat $rsParamFile | grep "t1=" | tail -1 | awk -F"=" '{print $2}'`
              t1SkullData=`cat $rsParamFile | grep "t1Skull=" | tail -1 | awk -F"=" '{print $2}'`  

              ##Flags that CAN be set but aren't required:
              #l lesionMask (to be used with flirt/fnirt)
              #-f FieldMapFlag (BBR registration with FieldMap data)
                #-b FieldMap (prepped (combo of Phase and Magnitude)
                #-v FieldMapMag
                #-w FieldMapMag (skull-stripped)
              #-D dwellTime (can be read from DICOM header)
              #-d peDir (can be read from DICOM header
              #-c overWriteFlag (clobber)


              #FieldMap flag
              fieldMapCheck=`cat $rsParamFile | grep "fieldMapCorrection=" | tail -1 | awk -F"=" '{print $2}'`

              if [[ $fieldMapCheck == 1 ]]; then
                #FieldMap images
                fieldMapMag=`cat $rsParamFile | grep "fieldMapMag=" | tail -1 | awk -F"=" '{print $2}'`
                fieldMapMagStripped=`cat $rsParamFile | grep "fieldMapMagStripped=" | tail -1 | awk -F"=" '{print $2}'`
                fieldMapPrepped=`cat $rsParamFile | grep "fieldMapPrepped=" | tail -1 | awk -F"=" '{print $2}'`

                #Dwell time
                dwellTimeCheck=`cat $rsParamFile | grep "epiDwell=" | tail -1 | awk -F"=" '{print $2}'`
                
                #Phase Encoding Direction
                peDirCheck=`cat $rsParamFile | grep "peDir=" | tail -1 | awk -F"=" '{print $2}'`

                #FieldMap options
                fieldMapOption="-f -b $fieldMapPrepped -v $fieldMapMag -x $fieldMapMagStripped -D $dwellTimeCheck -d $peDirCheck"
              else
                fieldMapOption=""
              fi
    
              #Lesion mask flag (used in T1 to MNI registration)
              if [[ $lesionMaskFlag == 1 ]]; then
                lesionMaskOption="-l $lesionMask"
                echo "lesionMask=$lesionMask" >> $rsParamFile
              else
                lesionMaskOption=""
              fi              

              #Overwrite flag
              if [[ $overwriteFlag == 1 ]]; then
                overwriteOption="-c"
              else
                overwriteOption=""
              fi              

              ###############################################

          #Quality Control
          $scriptDir/qualityCheck.sh -E $epiData -A $t1Data -a $t1SkullData $lesionMaskOption $fieldMapOption $overwriteOption

          ###############################################
	
    echo "IsDone_PartI_" >> $rsParamFile

    ###############################################

#############################################################################################
# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% #










# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% #
###### restingStateMelodic ##################################################################

elif [[ $multiFlag == 2 ]]; then

  ##### Initial processing check/clobber check ######################

  #Check for rsParams file (needed to grep for appropriate information)
  if [[ $rsParamFile == "" ]]; then
    echo "User must set path to rsParams file (-p) for further processing"
  exit 1
  fi

  #Check to see if Initial processing has been done
  baseProc2=`cat $rsParamFile | grep "IsDone_PartII_" | tail -1`      

  if [[ $overwriteFlag == 0 ]]  && [[ $baseProc2 != "" ]]; then
    echo "Base processing for MELODIC, has already been run.  Please set overwrite (-c) option to reprocess."
    exit 1
  fi

  ###############################################




    ##### -P 2 ######################

    ##Start PartII
    echo "....Calculating ICA components of EPI data"
    echo "_PartII_" >> $rsParamFile
    echo "`date`" >> $rsParamFile



          ##### -P 2 (restingStateMelodic) ######################
              
              ##### restingStateMelodic variables ######################

              #EPI data (motion-corrected and skull-stripped)
              epiDataCheck=`cat $rsParamFile | grep "epiMC=" | tail -1`
              if [[ $epiDataCheck != "" ]]; then
                epiData=`cat $rsParamFile | grep "epiMC=" | tail -1 | awk -F"=" '{print $2}'`
              else
                echo "Motion-corrected EPI needs to be specified.  Please run processRestingState.sh '-P 1' first"
                exit 1
              fi

              #T1 (skull-stripped)
              t1DataCheck=`cat $rsParamFile | grep "t1=" | tail -1`
              if [[ $t1DataCheck != "" ]]; then
                t1Data=`cat $rsParamFile | grep "t1=" | tail -1 | awk -F"=" '{print $2}'`
              else
                echo "T1 needs to be specified.  Please run processRestingState.sh -P 1' first"
                exit 1
              fi

              #TR (-t)
              trCheck=`cat $rsParamFile | grep "epiTR=" | tail -1 | awk -F"=" '{print $2}'`
              if [[ $tr != "" ]]; then
                trOption="-t $tr"
              else
                if [[ $trCheck != "" ]]; then
                  trOption="-t $trCheck"
                else
                  trOption=""
                fi
              fi

              #TE (-T)
              teCheck=`cat $rsParamFile | grep "epiTE=" | tail -1 | awk -F"=" '{print $2}'`
              if [[ $te != "" ]]; then
                teOption="-T $te"
              else
                if [[ $teCheck != "" ]]; then
                  teOption="-T $teCheck"
                else
                  teOption=""
                fi
              fi

              #Smooth (-s)
              smoothCheck=`cat $rsParamFile | grep "epiSmooth=" | tail -1 | awk -F"=" '{print $2}'`
              if [[ $smooth != "" ]]; then
                smoothOption="-s $smooth"
                if [[ $smoothCheck == "" ]]; then
                  echo "epiSmooth=${smooth}" >> $rsParamFile
                fi
              else
                if [[ $smoothCheck != "" ]]; then
                  smoothOption="-s $smoothCheck"
                else
                  smoothOption=""
                fi
              fi


              ##Flags that CAN be set but aren't required:
              #-f FieldMapFlag (updatefeatreg using nonlinear transforms (EPItoT1)
              #-H highpassArg (Highpass Filter)
              #-c overWriteFlag (clobber)

              #FieldMap flag
              fieldMapCheck=`cat $rsParamFile | grep "fieldMapCorrection=" | tail -1 | awk -F"=" '{print $2}'`

              if [[ $fieldMapCheck == 1 ]]; then
                fieldMapOption="-f"
              else
                fieldMapOption=""
              fi

              #Highpass Filter (-H)
              highpassCheck=`cat $rsParamFile | grep "highpassFilt=" | tail -1 | awk -F"=" '{print $2}'`
              if [[ $highpassArg != "" ]]; then
                highpassOption="-H $highpassArg"
              else
                if [[ $highpassCheck != "" ]]; then
                  highpassOption="-H $highpassCheck"
                else
                  highpassOption=""
                fi
              fi

              #Overwrite flag
              if [[ $overwriteFlag == 1 ]]; then
                overwriteOption="-c"
              else
                overwriteOption=""
              fi

              ###############################################

          #MELODIC ICA component creation
          $scriptDir/restingStateMelodic.sh -E $epiData -A $t1Data $trOption $teOption $smoothOption $fieldMapOption $highpassOption $overwriteOption

          ###############################################
   
    echo "IsDone_PartII_" >> $rsParamFile

    ###############################################

#############################################################################################
# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% #










# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% #
###### restingStatePreprocess, removeNuisanceRegressor, MotionScrub, seedVoxelCorrelation ###

elif [[ $multiFlag == 2a ]]; then

  ##### Initial processing check/clobber check ######################

  #Check for rsParams file (needed to grep for appropriate information)
  if [[ $rsParamFile == "" ]]; then
    echo "User must set path to rsParams file (-p) for further processing"
  exit 1
  fi

  #Check to see if Initial processing has been done
  baseProc2a=`cat $rsParamFile | grep "IsDone_PartIIa_" | tail -1`      

  if [[ $overwriteFlag == 0 ]]  && [[ $baseProc2a != "" ]]; then
    echo "Final processing has already been run.  Please set overwrite (-c) option to reprocess."
    exit 1
  fi

  ###############################################




    ##### -P 2a ######################

    ##Start PartIIa
    echo "....Filtering (through seeding steps) EPI data"
    echo "_PartIIa_" >> $rsParamFile
    echo "_NoMELODIC_" >> $rsParamFile
    echo "`date`" >> $rsParamFile


           
          ##### -P 2a (restingStatePreprocess) ######################
              
              ##### restingStatePreprocess variables ######################

              #EPI data (motion-corrected and skull-stripped)
              epiDataCheck=`cat $rsParamFile | grep "epiMC=" | tail -1`
              if [[ $epiDataCheck != "" ]]; then
                epiData=`cat $rsParamFile | grep "epiMC=" | tail -1 | awk -F"=" '{print $2}'`
              else
                echo "Motion-corrected EPI needs to be specified.  Please run processRestingState.sh '-P 1' first"
                exit 1
              fi

              #T1 (skull-stripped)
              t1DataCheck=`cat $rsParamFile | grep "t1=" | tail -1`
              if [[ $t1DataCheck != "" ]]; then
                t1Data=`cat $rsParamFile | grep "t1=" | tail -1 | awk -F"=" '{print $2}'`
              else
                echo "T1 needs to be specified.  Please run processRestingState.sh -P 1' first"
                exit 1
              fi

              #TR (-t)
              trCheck=`cat $rsParamFile | grep "epiTR=" | tail -1 | awk -F"=" '{print $2}'`
              if [[ $tr != "" ]]; then
                trOption="-t $tr"
              else
                if [[ $trCheck != "" ]]; then
                  trOption="-t $trCheck"
                else
                  trOption=""
                fi
              fi

              #TE (-T)
              teCheck=`cat $rsParamFile | grep "epiTE=" | tail -1 | awk -F"=" '{print $2}'`
              if [[ $te != "" ]]; then
                teOption="-T $te"
              else
                if [[ $teCheck != "" ]]; then
                  teOption="-T $teCheck"
                else
                  teOption=""
                fi
              fi

              #Smooth (-s)
              smoothCheck=`cat $rsParamFile | grep "epiSmooth=" | tail -1 | awk -F"=" '{print $2}'`
              if [[ $smooth != "" ]]; then
                smoothOption="-s $smooth"
                if [[ $smoothCheck == "" ]]; then
                  echo "epiSmooth=${smooth}" >> $rsParamFile
                fi
              else
                if [[ $smoothCheck != "" ]]; then
                  smoothOption="-s $smoothCheck"
                else
                  smoothOption=""
                fi
              fi

              
              ##Flags that CAN be set but aren't required:
              #-f FieldMapFlag (updatefeatreg using nonlinear transforms (EPItoT1)
              #-c overWriteFlag (clobber)

              #FieldMap flag
              fieldMapCheck=`cat $rsParamFile | grep "fieldMapCorrection=" | tail -1 | awk -F"=" '{print $2}'`

              if [[ $fieldMapCheck == 1 ]]; then
                fieldMapOption="-f"
              else
                fieldMapOption=""
              fi

              #Overwrite flag
              if [[ $overwriteFlag == 1 ]]; then
                overwriteOption="-c"
              else
                overwriteOption=""
              fi

              ###############################################

          #First level FEAT (preproc.feat)  
          $scriptDir/restingStatePreprocess.sh -E $epiData -A $t1Data $trOption $teOption $smoothOption $fieldMapOption $overwriteOption

          ###############################################





          ##### -P 2a (removeNuisanceRegressor) ######################

              ##### removeNuisanceRegressor variables ######################

              #EPI data (smoothed)
              epiDataCheck=`cat $rsParamFile | grep "epiNonfilt=" | tail -1`
              if [[ $epiDataCheck != "" ]]; then
                epiData=`cat $rsParamFile | grep "epiNonfilt=" | tail -1 | awk -F"=" '{print $2}'`
              else
                echo "Non-filtered (smoothed) EPI needs to be specified.  Please run restingStatePreprocess.sh first"
                exit 1
              fi

              #T1 (skull-stripped)
              t1DataCheck=`cat $rsParamFile | grep "t1=" | tail -1`
              if [[ $t1DataCheck != "" ]]; then
                t1Data=`cat $rsParamFile | grep "t1=" | tail -1 | awk -F"=" '{print $2}'`
              else
                echo "T1 needs to be specified.  Please run processRestingState.sh -P 1' first"
                exit 1
              fi

              #TR (-t)
              trCheck=`cat $rsParamFile | grep "epiTR=" | tail -1 | awk -F"=" '{print $2}'`
              if [[ $tr != "" ]]; then
                trOption="-t $tr"
              else
                if [[ $trCheck != "" ]]; then
                  trOption="-t $trCheck"
                else
                  trOption=""
                fi
              fi

              #TE (-T)
              teCheck=`cat $rsParamFile | grep "epiTE=" | tail -1 | awk -F"=" '{print $2}'`
              if [[ $te != "" ]]; then
                teOption="-T $te"
              else
                if [[ $teCheck != "" ]]; then
                  teOption="-T $teCheck"
                else
                  teOption=""
                fi
              fi

              #Nuisance Regressor ROIs (-N/-n)
              nuisanceROICheck=`cat $rsParamFile | grep "nuisanceROI=" | tail -1 | awk -F"=" '{print $2}'`
              if [[ $nuisanceList != "" ]]; then
                for i in $nuisanceList
                  do
                   nuisanceROI="$nuisanceROI -n $i"
                done
                nuisanceROIOption="$nuisanceROI"
              else
                if [[ $nuisanceROICheck != "" ]]; then
                  nuisanceROIOption="$nuisanceROICheck"
                else
                  nuisanceROIOption=""
                fi
              fi


              ##Flags that CAN be set but aren't required:
              #-L lowpassArg (Lowpass Filter)
              #-H highpassArg (Highpass Filter)
              #-c overWriteFlag (clobber)

              #Lowpass Filter (-L)
              lowpassCheck=`cat $rsParamFile | grep "lowpassFilt" | tail -1 | awk -F"=" '{print $2}'`
              if [[ $lowpassArg != "" ]]; then
                lowpassOption="-L $lowpassArg"
              else
                if [[ $lowpassCheck != "" ]]; then
                  lowpassOption="-L $lowpassCheck"
                else
                  lowpassOption=""
                fi
              fi

              #Highpass Filter (-H)
              highpassCheck=`cat $rsParamFile | grep "highpassFilt=" | tail -1 | awk -F"=" '{print $2}'`
              if [[ $highpassArg != "" ]]; then
                highpassOption="-H $highpassArg"
              else
                if [[ $highpassCheck != "" ]]; then
                  highpassOption="-H $highpassCheck"
                else
                  highpassOption=""
                fi
              fi

              #Overwrite flag
              if [[ $overwriteFlag == 1 ]]; then
                overwriteOption="-c"
              else
                overwriteOption=""
              fi

              ###############################################

          #Nuisance Regression (nuisancereg.feat)
          $scriptDir/removeNuisanceRegressor.sh -E $epiData -A $t1Data $trOption $teOption $nuisanceROIOption $lowpassOption $highpassOption $overwriteOption

          ###############################################





          ##### -P 2a (motionScrub) ######################

              ##### motionScrub variables ######################

              #Check for motionScrub flag
              motionScrubCheck=`cat $rsParamFile | grep "motionScrub=" | tail -1`

              #EPI data (smoothed)
              epiDataCheck=`cat $rsParamFile | grep "epiRaw=" | tail -1`
              if [[ $epiDataCheck != "" ]]; then
                epiData=`cat $rsParamFile | grep "epiRaw=" | tail -1 | awk -F"=" '{print $2}'`
              else
                echo "Raw EPI needs to be specified (-E)."
                exit 1
              fi

              ###############################################

          #Motion Scrubbing
          if [[ $motionscrubFlag == 1 || $motionscrubFlag == 2 ]]; then
            $scriptDir/motionScrub.sh -E $epiData
            if [[ $motionScrubCheck == "" ]]; then
              echo "motionScrub=${motionscrubFlag}" >> $rsParamFile
            fi
          else
            if [[ $motionScrubCheck != "" ]]; then
              $scriptDir/motionScrub.sh -E $epiData
            fi
          fi

          ###############################################





          ##### -P 2a (seedVoxelCorrelation) ######################

              ##### seedVoxelCorrelation variables ######################

              #EPI data
              epiDataCheck=`cat $rsParamFile | grep "epiRaw" | tail -1`
              if [[ $epiDataCheck != "" ]]; then
                epiData=`cat $rsParamFile | grep "epiRaw" | tail -1 | awk -F"=" '{print $2}'`
              else
                echo "EPI data needs to be specified."
                exit 1
              fi

              #Seeds/ROIs (-R/-r)
              seedROICheck=`cat $rsParamFile | grep "seeds=" | tail -1 | awk -F"=" '{print $2}'`
              if [[ $roiList != "" ]]; then
                for i in $roiList
                  do
                   seedROI="$seedROI -r $i"
                done
                seedROIOption="$seedROI"
              else
                if [[ $seedROICheck != "" ]]; then
                  seedROIOption="$seedROICheck"
                else
                  echo "Seed/ROIs need to be specified (-r)."
                  exit 1
                fi
              fi
              

              ##Flags that CAN be set but aren't required:
              #-m motionScrubFlag (if 1 or 2) -- defaults to 0 if not assigned
              #-f (use warp from EPI to T1 if fieldMap correction via BBR)
              #-V reviewResults (Create cope to MNI images)

              #Motion Scrubbing
              motionScrubCheck=`cat $rsParamFile | grep "motionScrub=" | tail -1 | awk -F"=" '{print $2}'`
              if [[ $motionScrubCheck != "" ]]; then                  
                motionScrubOption="-m $motionScrubCheck"
              else
                  motionScrubOption=""
              fi

              #FieldMap flag
              fieldMapCheck=`cat $rsParamFile | grep "fieldMapCorrection=" | tail -1 | awk -F"=" '{print $2}'`
              if [[ $fieldMapCheck == 1 ]]; then
                fieldMapOption="-f"
              else
                fieldMapOption=""
              fi

              #Review Results flag
              reviewResultsCheck=`cat $rsParamFile | grep "reviewResultsFlag=" | tail -1 | awk -F"=" '{print $2}'`
              if [[ $reviewResults == 1 ]]; then
                reviewResultsOption="-V"
              else
                if [[ $reviewResultsCheck == 1 ]]; then
                  reviewResultsOption="-V"
                else
                  reviewResultsOption=""
                fi
              fi

              ###############################################

          #Seed Voxel Correlation
          $scriptDir/seedVoxelCorrelation.sh -E $epiData $seedROIOption $motionScrubOption $fieldMapOption $reviewResultsOption

          ###############################################
   
    echo "IsDone_PartIIa_" >> $rsParamFile

    ###############################################

#############################################################################################
# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% #










# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% #
###### ICA_denoise, removeNuisanceRegressor, MotionScrub, seedVoxelCorrelation ##############

else

  ##### Initial processing check/clobber check ######################

  #Check for rsParams file (needed to grep for appropriate information)
  if [[ $rsParamFile == "" ]]; then
    echo "User must set path to rsParams file (-p) for further processing"
  exit 1
  fi

  #Check to see if Initial processing has been done
  baseProc3=`cat $rsParamFile | grep "IsDone_PartIII" | tail -1`      

  if [[ $overwriteFlag == 0 ]]  && [[ $baseProc3 != "" ]]; then
    echo "Final processing has already been run.  Please set overwrite (-c) option to reprocess."
    exit 1
  fi

  ###############################################




    ##### -P 3 ######################

    ##Start PartIII
    echo "....ICA Denoising (through seeding steps) EPI data"
    echo "_PartIII_" >> $rsParamFile
    echo "`date`" >> $rsParamFile



          ##### -P 3 (ICA_denoise) ################################

              ##### ICA_denoise variables ###############################

              #EPI data
              epiDataCheck=`cat $rsParamFile | grep "epiMelodic" | tail -1`
              if [[ $epiDataCheck != "" ]]; then
                epiData=`cat $rsParamFile | grep "epiMelodic=" | tail -1 | awk -F"=" '{print $2}'`
              else
                echo "EPI data (Output of Melodic) needs to be specified."
                exit 1
              fi

              #Check for noise IC file after signal/noise determination (C. Wong "ICA_gui" in matlab)
              noiseICDir=`dirname $epiData`
              ICnoiseCheck=`cat ${noiseICDir}/filtered_func_data.ica/manual_labeling/noise_com.txt`

              if [[ $ICnoiseCheck != "" ]]; then
                noiseICSet=`cat $noiseICDir/filtered_func_data.ica/manual_labeling/noise_com.txt`
              else
                echo "Melodic IC's have not been classified.  Please run Chelsea Wong's 'ICA_gui' first."
                exit 1
              fi

              #TR (-t)
              trCheck=`cat $rsParamFile | grep "epiTR=" | tail -1 | awk -F"=" '{print $2}'`
              if [[ $tr != "" ]]; then
                trOption="-t $tr"
              else
                if [[ $trCheck != "" ]]; then
                  trOption="-t $trCheck"
                else
                  trOption=""
                fi
              fi

              
              ##Flags that CAN be set but aren't required:
              #-c overWriteFlag (clobber)

              #Overwrite flag
              if [[ $overwriteFlag == 1 ]]; then
                overwriteOption="-c"
              else
                overwriteOption=""
              fi

              ###############################################

          #Removing ICA noise variables from EPI signal
          $scriptDir/ICA_denoise.sh -E $epiData -I $noiseICSet $trOption $overwriteOption

          ###############################################





          ##### -P 3 (removeNuisanceRegressor) ####################

              ##### removeNuisanceRegressor variables ######################

              #EPI data (Denoised)
              epiDataCheck=`cat $rsParamFile | grep "epiDenoised=" | tail -1`
              if [[ $epiDataCheck != "" ]]; then
                epiData=`cat $rsParamFile | grep "epiDenoised=" | tail -1 | awk -F"=" '{print $2}'`
              else
                echo "ICA Denoised EPI needs to be specified.  Please run ICA_Denoise.sh first"
                exit 1
              fi

              #T1 (skull-stripped)
              t1DataCheck=`cat $rsParamFile | grep "t1=" | tail -1`
              if [[ $t1DataCheck != "" ]]; then
                t1Data=`cat $rsParamFile | grep "t1=" | tail -1 | awk -F"=" '{print $2}'`
              else
                echo "T1 needs to be specified.  Please run processRestingState.sh -P 1' first"
                exit 1
              fi

              #TR (-t)
              trCheck=`cat $rsParamFile | grep "epiTR=" | tail -1 | awk -F"=" '{print $2}'`
              if [[ $tr != "" ]]; then
                trOption="-t $tr"
              else
                if [[ $trCheck != "" ]]; then
                  trOption="-t $trCheck"
                else
                  trOption=""
                fi
              fi

              #TE (-T)
              teCheck=`cat $rsParamFile | grep "epiTE=" | tail -1 | awk -F"=" '{print $2}'`
              if [[ $te != "" ]]; then
                teOption="-T $te"
              else
                if [[ $teCheck != "" ]]; then
                  teOption="-T $teCheck"
                else
                  teOption=""
                fi
              fi

              #Nuisance Regressor ROIs (-N/-n)
              nuisanceROICheck=`cat $rsParamFile | grep "nuisanceROI=" | tail -1 | awk -F"=" '{print $2}'`
              if [[ $nuisanceList != "" ]]; then
                for i in $nuisanceList
                  do
                   nuisanceROI="$nuisanceROI -n $i"
                done
                nuisanceROIOption="$nuisanceROI"
              else
                if [[ $nuisanceROICheck != "" ]]; then
                  nuisanceROIOption="$nuisanceROICheck"
                else
                  nuisanceROIOption=""
                fi
              fi


              ##Flags that CAN be set but aren't required:
              #-L lowpassArg (Lowpass Filter)
              #-H highpassArg (Highpass Filter)
              #-M highpassMelodic (Highpass Filter check)
              #-c overWriteFlag (clobber)

              #Lowpass Filter (-L)
              lowpassCheck=`cat $rsParamFile | grep "lowpassFilt" | tail -1 | awk -F"=" '{print $2}'`
              if [[ $lowpassArg != "" ]]; then
                lowpassOption="-L $lowpassArg"
              else
                if [[ $lowpassCheck != "" ]]; then
                  lowpassOption="-L $lowpassCheck"
                else
                  lowpassOption=""
                fi
              fi

              #Highpass Filter (-H)
              highpassCheck=`cat $rsParamFile | grep "highpassFilt=" | tail -1 | awk -F"=" '{print $2}'`
              if [[ $highpassArg != "" ]]; then
                highpassOption="-H $highpassArg"
              else
                if [[ $highpassCheck != "" ]]; then
                  highpassOption="-H $highpassCheck"
                else
                  highpassOption=""
                fi
              fi

              #Highpass Filter from Melodic (-M)
              highpassMelodicCheck=`cat $rsParamFile | grep "highpassFiltMelodic=" | tail -1 | awk -F"=" '{print $2}'`
              if [[ $highpassMelodicCheck != "" ]]; then
                highpassMelodicOption="-M"
              else
                highpassMelodicOption=""
              fi
              
              #Overwrite flag
              if [[ $overwriteFlag == 1 ]]; then
                overwriteOption="-c"
              else
                overwriteOption=""
              fi

              ###############################################

          #Nuisance Regression (nuisancereg.feat)
          $scriptDir/removeNuisanceRegressor.sh -E $epiData -A $t1Data $trOption $teOption $nuisanceROIOption $lowpassOption $highpassOption $highpassMelodicOption $overwriteOption

          ###############################################





          ##### -P 3 (MotionScrub) ####################

              ##### motionScrub variables ######################

              #Check for motionScrub flag
              motionScrubCheck=`cat $rsParamFile | grep "motionScrub=" | tail -1`

              #EPI data (smoothed)
              epiDataCheck=`cat $rsParamFile | grep "epiRaw=" | tail -1`
              if [[ $epiDataCheck != "" ]]; then
                epiData=`cat $rsParamFile | grep "epiRaw=" | tail -1 | awk -F"=" '{print $2}'`
              else
                echo "Raw EPI needs to be specified (-E)."
                exit 1
              fi

              ###############################################

          #Motion Scrubbing
          if [[ $motionscrubFlag == 1 || $motionscrubFlag == 2 ]]; then
            $scriptDir/motionScrub.sh -E $epiData
            if [[ $motionScrubCheck == "" ]]; then
              echo "motionScrub=${motionscrubFlag}" >> $rsParamFile
            fi
          else
            if [[ $motionScrubCheck != "" ]]; then
              $scriptDir/motionScrub.sh -E $epiData
            fi
          fi

          ###############################################





          ##### -P 3 (seedVoxelCorrelation) ###########

              ##### seedVoxelCorrelation variables ######################

              #EPI data
              epiDataCheck=`cat $rsParamFile | grep "epiRaw" | tail -1`
              if [[ $epiDataCheck != "" ]]; then
                epiData=`cat $rsParamFile | grep "epiRaw" | tail -1 | awk -F"=" '{print $2}'`
              else
                echo "EPI data needs to be specified."
                exit 1
              fi

              #Seeds/ROIs (-R/-r)
              seedROICheck=`cat $rsParamFile | grep "seeds=" | tail -1 | awk -F"=" '{print $2}'`
              if [[ $roiList != "" ]]; then
                for i in $roiList
                  do
                   seedROI="$seedROI -r $i"
                done
                seedROIOption="$seedROI"
              else
                if [[ $seedROICheck != "" ]]; then
                  seedROIOption="$seedROICheck"
                else
                  echo "Seed/ROIs need to be specified (-r)."
                  exit 1
                fi
              fi
              

              ##Flags that CAN be set but aren't required:
              #-m motionScrubFlag (if 1 or 2) -- defaults to 0 if not assigned
              #-f (use warp from EPI to T1 if fieldMap correction via BBR)
              #-V reviewResults (Create cope to MNI images)

              #Motion Scrubbing
              motionScrubCheck=`cat $rsParamFile | grep "motionScrub=" | tail -1 | awk -F"=" '{print $2}'`
              if [[ $motionScrubCheck != "" ]]; then                  
                motionScrubOption="-m $motionScrubCheck"
              else
                  motionScrubOption=""
              fi

              #FieldMap flag
              fieldMapCheck=`cat $rsParamFile | grep "fieldMapCorrection=" | tail -1 | awk -F"=" '{print $2}'`
              if [[ $fieldMapCheck == 1 ]]; then
                fieldMapOption="-f"
              else
                fieldMapOption=""
              fi

              #Review Results flag
              reviewResultsCheck=`cat $rsParamFile | grep "reviewResultsFlag=" | tail -1 | awk -F"=" '{print $2}'`
              if [[ $reviewResults == 1 ]]; then
                reviewResultsOption="-V"
              else
                if [[ $reviewResultsCheck == 1 ]]; then
                  reviewResultsOption="-V"
                else
                  reviewResultsOption=""
                fi
              fi

              ###############################################

          #Seed Voxel Correlation
          $scriptDir/seedVoxelCorrelation.sh -E $epiData $seedROIOption $motionScrubOption $fieldMapOption $reviewResultsOption

          ###############################################
   
    echo "IsDone_PartIII" >> $rsParamFile

    ###############################################

#############################################################################################
# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% #

fi



