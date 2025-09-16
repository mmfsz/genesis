#!/bin/bash

# Script to collect only pileup files that have at least one replica not on tape.

YEAR=$1

# Validate argument
if [[ -z "$YEAR" ]]; then
    echo "Usage: $0 <year> (Options: 2016, 2017, or 2018)" >&2
    exit 1
fi

# Set dataset and output based on year
# Temporary file for all LFNs
if [[ "$YEAR" == "2016" ]]; then
    DATASET="/Neutrino_E-10_gun/RunIISummer20ULPrePremix-UL16_106X_mcRun2_asymptotic_v13-v1/PREMIX"
    OUTPUT_FILE="disk_pileup_files_2016.txt"
    TEMP_FILE="all_files_2016.tmp"
elif [[ "$YEAR" == "2017" ]]; then
    DATASET="/Neutrino_E-10_gun/RunIISummer20ULPrePremix-UL17_106X_mc2017_realistic_v6-v3/PREMIX"
    OUTPUT_FILE="disk_pileup_files_2017.txt"
    TEMP_FILE="all_files_2017.tmp"
elif [[ "$YEAR" == "2018" ]]; then
    DATASET="/Neutrino_E-10_gun/RunIISummer20ULPrePremix-UL18_106X_upgrade2018_realistic_v11_L1v1-v2/PREMIX"
    OUTPUT_FILE="disk_pileup_files_2018.txt"
    TEMP_FILE="all_files_2018.tmp"
else
    echo "Error: Unsupported year '$YEAR'. Use 2016, 2017, or 2018." >&2
    exit 0
fi

echo "Processing dataset: $DATASET"
echo "Output file: $OUTPUT_FILE"



echo "Fetching all files from dataset..."
dasgoclient -query="file dataset=${DATASET}" > "${TEMP_FILE}"

echo "Filtering files with at least one non-tape replica..."
> "${OUTPUT_FILE}"  # Clear output file

while IFS= read -r lfn; do
    # Skip empty lines or headers
    [[ -z "${lfn}" || "${lfn}" == *'http'* ]] && continue
    
    # Query replica sites for this file
    sites=$(dasgoclient -query="site file=${lfn}")
    
    # Check if there's at least one site not ending in _Tape
    non_tape_sites=$(echo "${sites}" | grep -v "_Tape$" | grep -v '^$')
    if [[ -n "${non_tape_sites}" ]]; then
        echo "${lfn}" >> "${OUTPUT_FILE}"
        #echo "Included: ${lfn} (non-tape sites: ${non_tape_sites})"
    #else
        #echo "Excluded: ${lfn} (only tape: ${sites})"
    fi
done < "${TEMP_FILE}"

# Cleanup
rm -f "${TEMP_FILE}"

echo "Done! Disk-accessible files written to ${OUTPUT_FILE} ($(wc -l < "${OUTPUT_FILE}") files)."