#!/bin/bash

# Exit if any subquery has non-zero exit status.
set -e

SCRIPT_HOME=$(dirname $(readlink -f $0))
UTILS_PATH="$SCRIPT_HOME/shell_utils.sh"

# Import general shell utils.
source $UTILS_PATH

usage() {
  cat <<EOM
  Usage:
    $(basename $0) -e exp_name_inputs -d db_name -c clean_before_processing -f use_file_based_grouping -s skip_grouping -h clickhouse -o only_clean
    exp_name_inputs         - the names of the experiment that this script will process. Should
                              be comma-separated. Supports the use of wildcard in names. Experiment
                              names must not be zipped or compressed.
    db_name                 - the name of the database we should insert experiments' data into
    clean_before_processing - flag to determine whether data must be fetched from deter
    use_file_based_grouping - flag to determine whether experiment data is to be grouped in a file
    skip_grouping           - flag to determine whether we only want to bulk process experiments without grouping
    clickhouse              - flag to determine whether experiment data is to be grouped in clickhouse, if not file-based grouping.
                              Defaults to PostgreSQL otherwise
    only_clean              - flag to choose only to clean experiments
EOM
}

# Parse command line arguments
clean_before_processing=0
use_file_based_grouping=0
skip_grouping=0
clickhouse=0
only_clean=0
while getopts e:d:cfsho opt; do
  case $opt in
    e) exp_name_inputs=$OPTARG;;
    d) db_name=$OPTARG;;
    c) clean_before_processing=1;;
    f) use_file_based_grouping=1;;
    s) skip_grouping=1;;
    h) clickhouse=1;;
    o) only_clean=1;;
    *) usage
       exit 1;;
  esac
done

# Check that expected inputs are passed in to the script
if [[ -z "$exp_name_inputs" ]] || [[ -z "$db_name" ]]; then
  usage;
  exit 1
fi

# Make directory to store the groupping's logs
group_logging_dir="$GROUP_LOGGING_DIR"
if [[ $use_file_based_grouping == 1 ]]; then
  log_dir="$group_logging_dir/file_$db_name"
else
  log_dir="$group_logging_dir/db_$db_name"
fi
mkdir -p $log_dir

# Split input exp_names by comma into bash array exp_name_inputs_array
readarray -td, exp_name_inputs_array <<<"$exp_name_inputs,"; unset 'exp_name_inputs_array[-1]';

# Assert that there are no zip files in supplied names
for e in ${exp_name_inputs_array[@]}; do
  if [[ $e == *.zip ]]; then
    echo "Experiment $e is a .zip file, this is not allowed"
    exit 1
  fi
done

# Now enable filename globbing to retain regex 
# properties right before processing.
set +f 

# Find the collection of matching experiments. Look for
# zip-terminated experiment files since all experiments
# have a zip-terminated original file.
declare -A unzipped_exp_name_map_zipped_exp_dir
for e in ${exp_name_inputs_array[@]}; do
  num_dirs_found=$(find $EXPERIMENT_HOME/$e -maxdepth 0 -type d 2> /dev/null | wc -l)
  num_zips_found=$(find $EXPERIMENT_HOME/$e.zip -maxdepth 0 -type f 2> /dev/null | wc -l)

  if [[ $num_zips_found == 0 ]]; then
    # We found no experiments with matching names.
    echo "Experiment $e not found"
    exit 1
  fi
  if [[ $num_zips_found -lt $num_dirs_found ]]; then
    # We found some experiments which don't have an
    # original zip file.
    echo "Some experiments do not have original zip file. $num_zips_found zips, $num_dirs_found dirs"
    exit 1
  fi

  # Then add any found zipped experiment directories.
  # that have not been added yet.
  for zipped_exp_dir in $(find $EXPERIMENT_HOME/$e.zip -maxdepth 0 -type f); do
    exp_name=$(basename $zipped_exp_dir)
    unzipped_exp_name=${exp_name%.zip}
    unzipped_exp_name=$(echo -e "$unzipped_exp_name" | tr -d '[:space:]')
    if ! contains $unzipped_exp_name $unzipped_exp_name_map_zipped_exp_dir; then
      unzipped_exp_name_map_zipped_exp_dir[$unzipped_exp_name]=$zipped_exp_dir
    fi
  done
done

# Set all the experiment names and directories found.
exp_dirs_found=()
exp_names_found=()
for exp_name in "${!unzipped_exp_name_map_zipped_exp_dir[@]}"; do
  exp_dir=${unzipped_exp_name_map_zipped_exp_dir[$exp_name]}
  exp_names_found+=($exp_name)
  exp_dirs_found+=($exp_dir)
done

# Prompt the user whether they wish to process all experiments
echo "Found the following experiments:"
for i in ${!exp_names_found[@]}; do
  num=$(($i+1))
  echo "    $num. ${exp_names_found[$i]}"
done
echo -n "Do you wish include all the above experiments? [y/n]: "
read process_all_found_exps

# Determine the subset of experiments which to process
exp_dirs_to_process=()
if [[ -z "$process_all_found_exps" ]] || [[ $process_all_found_exps == "y" ]]; then
  # If the user accepts all experiments, note that
  exp_dirs_to_process=${exp_dirs_found[@]}
else
  # Otherwise, allow the user to choose the subset 
  # of experiments to process
  for i in ${!exp_dirs_found[@]}; do
    num=$(($i+1))
    exp_dir=$(echo "${exp_dirs_found[$i]}")
    exp_name=$(basename $exp_dir)
    echo -n "Include $num. $exp_name? [y/n]: "
    read process_exp_flag
    if [[ -z "$process_exp_flag" ]] || [[ $process_exp_flag == "y" ]]; then
      exp_dirs_to_process+=($exp_dir)
    fi
  done
fi

# Clean all selected experiments to fresh starting state
if [[ $clean_before_processing == 1 ]]; then
  echo ""
  echo -n "Cleaning all experiments..."
  for exp_dir in ${exp_dirs_to_process[@]}; do
    exp_name=$(basename $exp_dir)
    bash $SCRIPT_HOME/clean_experiment.sh $exp_name 1> /dev/null
  done
  echo "Done"
fi

main() {
  process_exp() {
    exp_dir=$1
    exp_name=$(basename $exp_dir)
    echo "    Processing $exp_name..."
    (time bash $SCRIPT_HOME/process_experiment.sh $exp_name) &> "$log_dir/process_$exp_name.log"
  }

  group_experiments_to_db() {
    exp_name_inputs=$1

    if [[ $clickhouse == 1 ]]; then
      bootstrap_clickhouse $db_name
      bash $SCRIPT_HOME/group_experiments_to_clickhouse.sh -n -e $exp_name_inputs -d $db_name
    else
      quietly_bootstrap_db $db_name
      bash $SCRIPT_HOME/group_experiments_to_db.sh -n -e $exp_name_inputs -d $db_name
      echo "Running analyze"
      time run_analyze_on_db $db_name
    fi
  }

  group_experiments_to_file() {
    exp_name_inputs=$1
    bash $SCRIPT_HOME/group_experiments_to_file.sh -n -e $exp_name_inputs -d $db_name
  }

  time (
    echo ""
    echo "Processing experiments:"
    pids=()
    for exp_dir in ${exp_dirs_to_process[@]}; do
      process_exp $exp_dir &
      pids+=($!)
    done
    for pid in "${pids[@]}"; do
      # Waiting on a specific PID makes the wait command return with the exit
      # status of that process. Because of the 'set -e' setting, any exit status
      # other than zero causes the current shell to terminate with that exit
      # status as well.
      wait $pid
    done
  )

  if [[ $skip_grouping == 0 ]]; then
    time (
      echo ""
      echo "Grouping experiments:"

      if [[ $use_file_based_grouping == 1 ]]; then
        group_experiments_to_file $exp_name_inputs
      else
        group_experiments_to_db $exp_name_inputs
      fi
    )
  fi
}

( time main ) 2>&1 | tee "$log_dir/main.log"