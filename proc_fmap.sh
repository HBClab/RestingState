#!/bin/bash
# preprocess GE fmaps a la https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FUGUE/Guide#Step_5_-_Regularising_the_fieldmap

inFile=$1

#Adjust the fieldMap_Hz to rad/s by multiplying by 6.28 (2*pi=6.28)
fslmaths ${inFile} -mul 6.28 ${inFile}

# https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FUGUE/Guide#Step_5_-_Regularising_the_fieldmap
# smooth (1mm), despike, median filter
fugue --loadfmap=${inFile} -s 1 --savefmap=${inFile%.nii.gz}_prepped.nii.gz
fugue --loadfmap=${inFile} --despike --savefmap=${inFile%.nii.gz}_prepped.nii.gz
fugue --loadfmap=${inFile} -m --savefmap=${inFile%.nii.gz}_prepped.nii.gz
