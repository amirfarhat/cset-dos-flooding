#!/bin/bash

# Helper to check if a supplied file exists.
check_present() {
  file_to_check=$1
  if [[ -z $file_to_check ]]; then
    basename_file="$(basename $file_to_check)"
    echo "Cannot find file $basename_file"
    exit 1
  fi
}

# Helper to check if a supplied directory exists.
check_directory_exists() {
  directory_to_check=$1
  callback=$2
  if [[ ! -d $directory_to_check ]]; then
    basename_directory="$(basename $directory_to_check)"
    if [[ ! -z "$callback" ]]; then
      $callback
      echo ""
    fi
    echo "Cannot find directory \"$basename_directory\""
    exit 1
  fi
}

# Helper to verbosely remove an existing file.
log_remove_file() {
  file=$1
  if [[ -f $file ]]; then
    rm $file
    echo "Removed `basename $file`"
  fi
}

# Helper to bootstrap ClickHouse schema before insertion.
bootstrap_clickhouse() {
  db_name=$1
  python3 $SCRIPT_HOME/bootstrap_clickhouse.py -d $db_name -s $CLICKHOUSE_SQL
}

# Helper to bootstrap PostgreSQL schema before insertion.
bootstrap_db() {
  db_name=$1

  # Create database if not exists.
  (sudo su postgres -c "psql template1 -c 'CREATE DATABASE ${db_name}'" || true) > /dev/null 2>&1
  echo "Created DB ${db_name}"

  # Bootstrap DB for experiments.
  python3 $SCRIPT_HOME/bootstrap_db.py -d $db_name \
                                       -p $FUNCTIONS_AND_PROCEDURES_PATH
}

# Helper to bootstrap PostgreSQL while redirecting stdout
# to /dev/null.
quietly_bootstrap_db() {
  db_name=$1
  bootstrap_db $db_name 1> /dev/null
}

# Helper to run ANALYZE on PostgreSQL.
run_analyze_on_db() {
  db_name=$1
  (sudo su postgres -c "psql ${db_name} -c 'ANALYZE'" || true) > /dev/null 2>&1
}

SCRIPT_HOME=$(dirname $(readlink -f $0))

# This directory houses helper SQL files for
# grouping experiments into a database.
SQL_HOME="$SCRIPT_HOME/sql"
CLICKHOUSE_SQL="$SQL_HOME/bootstrap_clickhouse.sql"
FUNCTIONS_AND_PROCEDURES_PATH="$SQL_HOME/functions_and_procedures.sql"
check_present $FUNCTIONS_AND_PROCEDURES_PATH
check_present $CLICKHOUSE_SQL

# This directory houses the experiment data
# used in the paper.
EXPERIMENT_HOME="$SCRIPT_HOME/../experiments"
mkdir -p $EXPERIMENT_HOME

# This directory is used for logging during the
# process of grouping experiments.
GROUP_LOGGING_DIR="/home/ubuntu/group_logging"