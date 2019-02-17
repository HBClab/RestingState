#!/bin/bash

# shell wrapper for matlab/octave script to run getroicorrs scripts within docker container

# Run script using Matlab or Octave
haveMatlab=`which matlab`
if [ "$haveMatlab" == "" ]; then
  octave -q /opt/RestingState/run_getroicorrs.m
else
  matlab -nodisplay -r "run /opt/RestingState/run_getroicorrs.m"
fi