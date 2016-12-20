#!/bin/bash

infile=$1

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
  warnFlag=`fslswapdim ${infile} ${flipFlag} ${infile%.nii.gz}_MNI.nii.gz`
  warnFlagCut=`echo ${warnFlag} | awk -F":" '{print $1}'`


  #Reorienting the file may require swapping out the flag orientation to match the .img block
  if [[ $warnFlagCut == "WARNING" ]]; then
	fslorient -swaporient ${infile%.nii.gz}_MNI.nii.gz
  fi

else

  echo "No need to reorient.  Dataset already in RPI orientation."

  if [ ! -e ${infile%.nii.gz}_MNI.nii.gz ]; then

    cp ${infile} ${infile%.nii.gz}_MNI.nii.gz

  fi

fi


#Output should now be in RPI orientation and ready for analysis
