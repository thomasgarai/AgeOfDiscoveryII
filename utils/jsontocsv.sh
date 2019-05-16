#!/usr/bin/env bash
#
# jsonv 0.2.0
# A Bash command line tool for converting JSON to CSV
#
# Copyright (c) 2013 Paul Engel, released under the MIT license
# https://github.com/archan937/jsonv.sh
#
# Get a JSON file
#
# Example (e.g. example.json)
#
#     [
#       {
#         "name": "Dagny Taggart",
#         "id": 1,
#         "age": 39
#       }, {
#         "name": "Francisco D'Anconia",
#         "id": 8,
#         "age": 40
#       }, {
#         "name": "Hank Rearden (a.k.a \"The Tank\")",
#         "id": 12,
#         "age": 46
#       }
#     ]
#
# Command line usage
#
# Call `jsonv` and pass the paths of the values used for the CSV columns (comma separated).
# Optionally, you can pass a prefix for the paths as a second argument.
#
# Example
#
#     $ cat examples/simple.json | ./jsonv id,name,age
#     1,"Dagny Taggart",39
#     8,"Francisco D'Anconia",40
#     12,"Hank Rearden (a.k.a \"The Tank\")",46
#
#     $ cat examples/simple.json | ./jsonv id,name,age > example.csv
#     $ cat example.csv
#     1,"Dagny Taggart",39
#     8,"Francisco D'Anconia",40
#     12,"Hank Rearden (a.k.a \"The Tank\")",46
#

dir=$(cd `dirname $0` && pwd)

if [[ $dir =~ \/bin$ ]]; then
  awk=$dir/.jsonv/json.awk
  log=$dir/.jsonv/log
  json=$dir/.jsonv/json
  tokens=$dir/.jsonv/tokens
  map=$dir/.jsonv/map
else
  awk=$dir/utils/json.awk
  log=$dir/tmp/log
  json=$dir/tmp/json
  tokens=$dir/tmp/tokens
  map=$dir/tmp/map
fi

get_key () {
  echo $1 | xargs | gawk -F. '{
    for (i = 1; i <= NF; i++) {
      if (i > 1) {
        printf ",";
      }
      printf "\""$i"\"";
    }
  }'
}

echo_log () {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> $log
}

jsonv () {
  echo_log "Writing JSON file"
  cat /dev/stdin > $json

  echo_log "Writing tokens file"
  echo -e "$json\n" | gawk -f $awk > $tokens

  echo_log "Deriving keys"
  keys=()
  for path in ${1//,/ }; do
    keys+=($(get_key $path))
  done

  echo_log "Deriving prefix"
  prefix=''
  if [ "$2" != "" ]; then
    prefix=$(get_key $2)","
  fi

  echo_log "Counting entries"
  count=$(cat $tokens | sed 's/^[\["a-z,]*//g' | sed 's/,.*//g' | gawk '/^[0-9]+$/ && !_[$0]++' | gawk -F\t 'BEGIN{max==""} ($1 > max) {max=$1} END{print max}')

  echo_log "Writing map file"
  row=''
  for key in "${keys[@]}"; do
    row="$row[$prefix"INDEX",$key]\t"
  done
  echo -e $row | gawk -F\t -v n="$count" '{for(i=0;i<=n;i++) print}' | gawk -F\t '{gsub("INDEX",NR-1,$0); print $0}' > $map

  echo_log "Deriving line format"
  format=''
  for ((i=1; i<=${#keys[@]}; i++)); do
    if [ $i -gt 1 ]; then
      format+='","'
    fi
    format+="a[\$"$i"]"
  done

  echo_log "Compiling CSV output"
  program="'FNR==NR{a[\$1]=\$2; next} {print $format}'"
  eval "gawk -F\\\t $program $tokens $map"

  echo_log "Done."
  echo "=====================" >> $log
}

if [[ "$1" == "-v" || "$1" == "--version" ]]; then
  echo "0.2.0"
elif [ "$1" != "" ]; then
  jsonv $1 $2
fi