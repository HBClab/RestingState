#!/bin/bash

# shell wrapper for matlab/octave script to run getroicorrs scripts within docker container
input_dir=$1
subList=$2
roiList=$3
scriptdir=$(dirname "$0")

  octave -q "${scriptdir}"/run_getroicorrs.m \
  "${input_dir}" \
  "${subList}" \
  "${roiList}"
