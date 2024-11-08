#!/usr/bin/env bash

piscem_executable=$1 ## rust executable for piscem rust executable
map_rad=$2 ## rad file output by piscem
whitelist_file=$3 ## whitelist file
rev_comp=$4
threads=$5
output_path=$6

echo "Correcting barcodes"
$piscem_executable generate-permit-list \
    --input $map_rad \
    --unfiltered-pl $whitelist_file \
    --rev-comp $rev_comp \
    --output-dir $output_path

echo "Collation"
$piscem_executable collate \
    --input-dir $output_path \
    --rad-dir $output_path \
    --threads $threads

$piscem_executable deduplicate \
    --input-dir $output_path \
    --threads $threads \
    --rev-comp $rev_comp
