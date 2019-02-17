#!/bin/bash

# shell wrapper for matlab/octave script to run getroicorrs scripts within docker container

  octave -q /opt/RestingState/run_getroicorrs.m \
  /data/derivatives/sublists/sublist.txt \
  /data/derivatives/sublists/sublist-rois.txt 
