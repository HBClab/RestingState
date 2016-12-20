#!/bin/bash

########################################################################
# Quick script to open up the ICA_gui program in Matlab
########################################################################

scriptPath=`perl -e 'use Cwd "abs_path";print abs_path(shift)' $0`
scriptDir=`dirname $scriptPath`

filenameICA=run_ica.m;
cat > $filenameICA << EOF

% It is matlab script
close all;
clear all;
addpath('${scriptDir}');
ICA_gui;
EOF


# Run script using Matlab or Octave
haveMatlab=`which matlab`
if [ "$haveMatlab" == "" ]; then
  echo "ERROR: Octave is not yet supported"
  # octave --no-window-system $indir/$filenameQC 
else
  matlab -r run_ica
fi


exit

