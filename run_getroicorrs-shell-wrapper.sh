#!/bin/bash

# shell wrapper for matlab/octave script to run getroicorrs scripts within docker container
subList=$1
roiList=$2
scriptdir=$(dirname "$0")

  octave -q "${scriptdir}"/run_getroicorrs.m \
  ${subList} \
  ${roiList}
