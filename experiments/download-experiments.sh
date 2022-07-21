#!/bin/bash

### This script downloads raw experiment data zip files
### to the local directory for reproducing and extending
### the research into instrumentation and storage of DoS
### flooding experiments and others.
###
### The data files are hosted on zenodo, at the record ID
### described in the code below.

# Exit if any subquery has non-zero exit status.
set -e

EXPERIMENTS_DIR=$(pwd)

EXPECTED_NUM_EXPERIMENTS=28

ZENODO_ID="6828809"
ZENODO_RECORD="https://zenodo.org/record/$ZENODO_ID"
ZENODO_RECORD_FILES="$ZENODO_RECORD/files"

echo "Fetching metadata of experiment files..."

# To obtain a list of the URLs to get each experiment from:
# 1. Fetch the webpage which enumerates each experiment's
#    download link.
# 2. Keep only those HTML lines which contain experiment
#    download link hrefs.
# 3. Strip the " character.
# 4. Strip the > character.
exp_file_urls=$(
  curl -s $ZENODO_RECORD \
  | grep -o "$ZENODO_RECORD_FILES.*" \
  | tr -d '"' \
  | tr -d '>'
)

echo "Checking that all $EXPECTED_NUM_EXPERIMENTS experiments are present..."

pids=()
for exp_url in $exp_file_urls; do
  exp_name=$(basename $exp_url)
  # Download experiments that are not already present.
  # Downloads are done queitly and in the background.
  if [[ ! -f $exp_name ]]; then
    (wget -q $exp_url) &
    pids+=($!)
  fi
done
if [[ ${#pids[@]} -gt 0 ]]; then
  echo "Downloading ${#pids[@]} missing experiments from expected $EXPECTED_NUM_EXPERIMENTS..."
  for pid in "${pids[@]}"; do
    # Wait for all experiment downloads to complete.
    wait $pid
  done
fi

# Expect that, after downloading missing experiments,
# the total number of experiments matches expectation.
found_num_exps=$(
  ls *.zip \
  | wc -l
)
if [[ $found_num_exps == $EXPECTED_NUM_EXPERIMENTS ]]; then
  echo "All expected experiments are present"
  exit 0
else
  echo "Missing some experiments: expected $EXPECTED_NUM_EXPERIMENTS but only found $found_num_exps in the local filesystem"
  exit 1
fi