#! /bin/bash

# Wrapper for chef to catch STDOUT and STDERR into a file,
# necessary because this is run with sudo

usage(){
  cat <<EOL

  Usage: $0 -s <CHEF_CMD> -j <JSON_FILE> -c <CHEF_CONFIG> -o <RUN_LIST> -L <CHEF_LOG_FILE> -A <LOG_LINE_TO_APPEND> -P <LOG_LINE_TO_PREPEND>
   -s Absolute path to the executable chef command.
   -j Absolute path to the JSON file.
   -c Absolute path to the chef configuration file.
   -o Comma separated list of run list items (replaces the run list defined within the JSON file).
   -L Absolute path to the for the chef log file to be created.
   -A Log line to append.
   -P Log line to prepend.
   -h Show this stuff.

   This script acts as a wrapper for chef and will redirect STDOUT and STDERR
   into the log file.

   This script is meant to be used only from the process_command daemon.

EOL
}

while getopts "s:j:c:o:L:A:P:h" optname
do
  case "$optname" in
    "s")
      # path to the chef-client binary
      CHEF_CMD="$OPTARG"
      ;;
    "j")
      # the opsworks json
      JSON_FILE="$OPTARG"
      ;;
    "c")
      # the chef configuration file
      CHEF_CONFIG="$OPTARG"
      ;;
    "o")
      # the run list items
      RUN_LIST="$OPTARG"
      ;;
    "L")
      # the log file to use
      CHEF_LOG_FILE="$OPTARG"
      ;;
    "A")
      # log line to append
      LOG_LINE_TO_APPEND="$OPTARG"
      ;;
    "P")
      # log line to append
      LOG_LINE_TO_PREPEND="$OPTARG"
      ;;
    "h")
      usage
      exit 0
      ;;
    *)
      echo "Unknown error while processing options"
      usage
      exit 1
      ;;
  esac
done

if
  proxy_lines=`test -r /etc/environment && grep -E "^https?_proxy=" /etc/environment`
then
  eval export $proxy_lines
fi

# LOG_LINE_TO_APPEND can be an empty string
if [ -z "$CHEF_CMD" ] || [ -z "$JSON_FILE" ] || [ -z "$CHEF_CONFIG" ] || [ -z "$RUN_LIST" ] || [ -z "$CHEF_LOG_FILE" ]
then
  echo "[ERROR] Parameter missing."
  usage
  exit 1
fi

_RUBYOPT="-E utf-8"

echo "[$(date  +%c)] About to execute: RUBYOPT=\"$_RUBYOPT\" $CHEF_CMD -j $JSON_FILE -c $CHEF_CONFIG -o $RUN_LIST 2>&1"
# create the log file readable for the aws user
touch "$CHEF_LOG_FILE" && chmod 644 "$CHEF_LOG_FILE"

if [ -n "$LOG_LINE_TO_PREPEND" ]
then
    echo -e "$LOG_LINE_TO_PREPEND" >> "$CHEF_LOG_FILE"
fi

exec &> >(tee -a "$CHEF_LOG_FILE") 2>&1
RUBYOPT="$_RUBYOPT" "$CHEF_CMD" -j "$JSON_FILE" -c "$CHEF_CONFIG" -o "$RUN_LIST"
CHEF_RETURN_CODE=$?

if [ -n "$LOG_LINE_TO_APPEND" ]
then
  echo -e "$LOG_LINE_TO_APPEND" >> "$CHEF_LOG_FILE"
fi

exit $CHEF_RETURN_CODE
