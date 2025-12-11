#!/bin/bash
set -e

# Function to display usage message
usage() {
  echo "Usage: $0 -t TAG [-c CAMPAIGN -n NEVENTS -d]"
  echo "Example:"
  echo " $0 -t VBSVVH_VBSCuts_13TeV_4f_LO_MG_2_9_18_c2v_1p0_c3_1p0_c2Vc3scan_slc7_amd64_gcc10_CMSSW_12_4_8 -c 2016"
  exit 1
}

# Arguments default values
TAG="" 
CAMPAIGN=""
NEVENTS="-1" # Run over all events in input file
DRY_RUN=false
MEMORY=2 # MB
N_CPUS=1
BASEDIR=`pwd`

# Parse command-line options using getopts
while getopts ":t:c:j:d" opt; do
  case $opt in
    t) TAG=$OPTARG ;;  
    c) CAMPAIGN=$OPTARG ;;
    n) NEVENTS=$OPTARG ;;
    d) DRY_RUN=true ;;
    \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
    :) echo "Option -$OPTARG requires an argument." >&2; usage ;;
  esac
done

# Ensure that all required options are provided
if [ -z "$TAG" ] ; then
  usage
fi
echo """
TAG = $TAG
CAMPAIGN = $CAMPAIGN
DRY_RUN = $DRY_RUN
"""
# Export proxy on lxplus
# check if x509 proxy exists, and then copy it to afs
X509_USER_PROXY="${X509_USER_PROXY:-/tmp/x509up_u$(id -u)}"
proxy_path="/afs/cern.ch/user/$(whoami | head -c 1)/$(whoami)/x509up_u$(id -u)"
if [[ -d "/afs/cern.ch" ]]; then
  if [[ -f "$X509_USER_PROXY" ]]; then
        echo "Copying proxy to $proxy_path"
        cp "$X509_USER_PROXY" "$proxy_path"
  else
    echo "Warning: Running on lxplus, but X509 user proxy not found at $X509_USER_PROXY"
    exit 1
  fi
fi

# Create output directory on ceph/

# Find all MINI directories remotely
BASE_REMOTE="/store/user/mmazza/SignalGeneration"
OUTPUTDIRBASE=${BASE_REMOTE}/${TAG}/
echo "OUTPUTDIRBASE = $OUTPUTDIRBASE"
mini_dirs=$(env -i X509_USER_PROXY=${X509_USER_PROXY} gfal-ls davs://redirector.t2.ucsd.edu:1095/${OUTPUTDIRBASE} | grep MINI || true)
if [ -z "$mini_dirs" ]; then
  echo "No directories containing 'MINI' found in ${BASE_REMOTE}/${TAG}"
  exit 1
fi
echo "Found the following MINI AOD directories: "
echo "$mini_dirs"

# Loop over each MINI directory and collect paths of root files
for mini_dir in $mini_dirs; do
  input_mini_dir_path="${BASE_REMOTE}/${TAG}/${mini_dir}"
  echo "davs://redirector.t2.ucsd.edu:1095/${input_mini_dir_path}"

  # Count the number of output_*.root files
  output_files=$(env -i X509_USER_PROXY=${X509_USER_PROXY} gfal-ls davs://redirector.t2.ucsd.edu:1095/${input_mini_dir_path} | grep '^output_[0-9]*\.root$' || true)
  njobs=$(echo "$output_files" | wc -l)
  if [ "$njobs" -eq 0 ]; then
    echo "No output_*.root files found in ${input_mini_dir_path}. Skipping."
    continue
  fi

  # Extract campaign (e.g., RunIISummer20UL16APV)
  campaign_long=$(echo "$mini_dir" | grep -oP 'RunIISummer20UL\d+(APV)?')
  echo "campaign_long = $campaign_long"

  # Map to short campaign and era
  case "$campaign_long" in
    *UL16APV) campaign_short="2016APV"; era="Run2_2016_HIPM,run2_nanoAOD_106Xv2" ;;
    *UL16) campaign_short="2016"; era="Run2_2016,run2_nanoAOD_106Xv2" ;;
    *UL17) campaign_short="2017"; era="Run2_2017,run2_nanoAOD_106Xv2" ;;
    *UL18) campaign_short="2018"; era="Run2_2018,run2_nanoAOD_106Xv2" ;;
    *) echo "Unknown campaign: $campaign_long. Skipping."; continue ;;
  esac

  # Check if requested a specific CAMPAIGN
  if [ -n "$CAMPAIGN" ] && [ "$campaign_short" != "$CAMPAIGN" ]; then
    continue
  fi
  # Use executable for this campaign
  executable=${BASEDIR}/${campaign_long}.sh

  # Define output directory
  nano_dir="${mini_dir/MINIGEN/NANOv15}"
  output_nano_dir_path="${BASE_REMOTE}/${TAG}/${nano_dir}"

  # Create task directory
  TASKNAME="${nano_dir}"
  TASKDIR=${BASEDIR}/tasks/CondorTask_${TAG}/${TASKNAME}/
  if [[ -d $TASKDIR ]]; then
    echo "ERROR: $TASKDIR already exists; move or delete it and run again"
    exit 1
  fi
  mkdir -p $TASKDIR
  cd $TASKDIR
  cp $executable .
  chmod +x $executable
  echo "Condor job logs will be written to $TASKDIR"
  echo "Input MINIAOD files will be retrieved from ${input_mini_dir_path}"
  echo "Output NANOAODv15 files will be stored in ${output_nano_dir_path}"

  # Create output directory if it does not exist
  env -i X509_USER_PROXY=${X509_USER_PROXY} gfal-mkdir -p davs://redirector.t2.ucsd.edu:1095/${output_nano_dir_path}

  # Create list_of_inputs.txt with each file on a line
  echo "$output_files" > list_of_inputs.txt

# espresso     = 20 minutes
# microcentury = 1 hour
# longlunch    = 2 hours
# workday      = 8 hours
# tomorrow     = 1 day
# testmatch    = 3 days
# nextweek     = 1 week

cat << EOF > submit.cmd
Universe                = Vanilla
request_cpus            = ${N_CPUS}
request_memory          = ${MEMORY}GB

executable              = ${executable}
transfer_executable     = True
arguments               = \$(input_file) ${input_mini_dir_path} ${output_nano_dir_path} ${NEVENTS} false
#transfer_input_files    = 
transfer_output_files   = ""

log                     = condor.log
output                  = job.\$(Cluster).\$(Process).\$(Retry).stdout
error                   = job.\$(Cluster).\$(Process).\$(Retry).stderr

should_transfer_files   = YES
when_to_transfer_output = ON_EXIT

on_exit_remove          = (ExitBySignal == False) && (ExitCode == 0)
max_retries             = 3

MY.SingularityImage     = "/cvmfs/unpacked.cern.ch/registry.hub.docker.com/cmssw/el8:$(uname -m)"
+JobFlavour             = "longlunch"
queue input_file from list_of_inputs.txt
EOF

  if [ "$DRY_RUN" = true ]; then
    echo "Dry run mode: will not run condor_submit."
    break
  else
    echo "Submitting jobs for ${mini_dir}"
    condor_submit submit.cmd
  fi

  cd ${BASEDIR}

done


