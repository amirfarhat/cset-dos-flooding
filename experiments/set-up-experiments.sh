#!/bin/bash

### This script processes and groups experiments
### into clickhouse for compatible running with
### notebooks.

# Exit if any subquery has non-zero exit status.
set -e

EXPERIMENTS_DIR=$(pwd)
SCRIPTS_DIR="$EXPERIMENTS_DIR/../scripts"
GROUP_EXPERIMENTS_SCRIPT="$SCRIPTS_DIR/group_experiments.sh"

if [[ ! -d $SCRIPTS_DIR ]]; then
  echo "The directory containing scripts is not in the expected location $SCRIPTS_DIR. Make sure it is there before proceeding"
  exit 1
fi

if [[ ! -f $GROUP_EXPERIMENTS_SCRIPT ]]; then
  echo "Cannot find the experiment grouping script. Make sure it is there before proceeding"
  exit 1
fi

# Make sure that ClickHouse is on.
(sudo clickhouse start 1> /dev/null) &
wait

# Make sure PostgreSQL is on.
sudo systemctl start postgresql

cd $SCRIPTS_DIR

# First process and group the cloud experiments.
./group_experiments.sh -h -e "cloud_proxy_and_*" -d "clouddb"

# Then process and group the multiclient experiments.
./group_experiments.sh -h -e "multiclient_cloud_*" -d "multiclientdb"

# Then process and group the gigabit experiments.

# Begin with experiments having no tcpdump.
# Note that experiments without tcpdump data
# have no data to be inserted into the datbase.
./group_experiments.sh -sh -e "gigabit_attack_50sec_without_tcpdump,gigabit_attack_100sec_without_tcpdump" -d "gigabitdb"

# And then experiments having tcpdump, but split
# into two batches, and group into the database.
./group_experiments.sh -h -e "gigabit_attack_20sec_with_tcpdump" -d "gigabitdb"
./group_experiments.sh -h -e "gigabit_attack_35sec_with_tcpdump" -d "gigabitdb"
./group_experiments.sh -h -e "gigabit_attack_50sec_with_tcpdump" -d "gigabitdb"
./group_experiments.sh -h -e "gigabit_attack_75sec_with_tcpdump" -d "gigabitdb"
./group_experiments.sh -h -e "gigabit_attack_100sec_with_tcpdump" -d "gigabitdb"