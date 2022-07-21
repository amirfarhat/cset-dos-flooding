#!/bin/bash

### This script summarizes information about cloud
### experiments.

# Exit if any subquery has non-zero exit status.
set -e

SCRIPTS_DIR=$(pwd)
EXPERIMENTS_DIR="$SCRIPTS_DIR/../experiments"
CLOUD_PATTERN="$EXPERIMENTS_DIR/cloud_proxy_and*" 

# Print header.
# TODO

for e in $(find $CLOUD_PATTERN -maxdepth 0 -type d); do
  # Determine the experiment's attack rate.
  attack_rate=$(jq -r '.attack_rate' $e/metadata/config.json)

  # Determine if the experiment uses HTTPS.
  https=$(jq -r '.run_proxy_with_https' $e/metadata/config.json)
  if [[ $https == 1 ]]; then
    https="Y"
  else
    https="N"
  fi

  # Determine if the experiment uses CoAPS.
  coaps=$(jq -r '.run_proxy_with_dtls' $e/metadata/config.json)
  if [[ $coaps == 1 ]]; then
    coaps="Y"
  else
    coaps="N"
  fi

  # Get the experiment's compressed size.
  compressed_size=$(du -h "$e.zip" | awk '{ printf $1 }')
  
  # Get the experiment's uncompressed size, by
  # exlcuding post-processed data files.
  uncompressed_size=$(du -hc "$e" --exclude "*.parquet" --exclude "*.pcap.out" --exclude "*.metrics.csv" | tail -n 1 | awk '{ printf $1 }')

  # Determine the compression ratio.
  num_compressed_size=$(echo -n $compressed_size | tr -d 'M')
  num_uncompressed_size=$(echo -n $uncompressed_size | tr -d 'M')
  compression_ratio=$(bc <<<"scale=2; $num_uncompressed_size / $num_compressed_size")

  # Count the number of message observed
  messages_observed=$(./get_parquet_size.py "$e/*/*.parquet")

  echo "$attack_rate,$https,$coaps,$compressed_size,$compressed_size,$uncompressed_size,$compression_ratio,$messages_observed"
done