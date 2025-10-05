#!/bin/bash
set -euo pipefail

# Function to display usage message
usage() {
  echo "Usage: $0 -g GRIDPACK -c CAMPAIGN -n NEVENTS -j NJOBS [-t TAG]"
  exit 1
}

# Arguments default values
GRIDPACK=""
CAMPAIGN=""
NEVENTS=""
NJOBS=""
TAG=""  # Optional argument
MEMORY=2 # MB
N_CPUS=1
BASEDIR=`pwd`

# Parse command-line options using getopts
while getopts ":g:c:n:j:t:" opt; do
  case $opt in
    g) GRIDPACK=$OPTARG ;;
    c) CAMPAIGN=$OPTARG ;;
    n) NEVENTS=$OPTARG ;;
    j) NJOBS=$OPTARG ;;
    t) TAG=$OPTARG ;;  # Optional argument for TAG
    \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
    :) echo "Option -$OPTARG requires an argument." >&2; usage ;;
  esac
done

# Ensure that all required options are provided
if [ -z "$GRIDPACK" ] || [ -z "$CAMPAIGN" ] || [ -z "$NEVENTS" ] || [ -z "$NJOBS" ]; then
  usage
fi

# Check if the gridpack file exists
#if [ ! -f "$GRIDPACK" ]; then
#  echo "ERROR: $GRIDPACK does not exist!"
#  exit 1
#else
echo "Using gridpack $GRIDPACK"
#fi

# Proxy 
# check if x509 proxy exists, and then copy it to afs
X509_USER_PROXY="${X509_USER_PROXY:-/tmp/x509up_u$(id -u)}"
proxy_path="/afs/cern.ch/user/$(whoami | head -c 1)/$(whoami)/x509up_u$(id -u)"
if [[ -f "$X509_USER_PROXY" ]]; then
  if [[ -d "/afs/cern.ch" ]]; then
        cp "$X509_USER_PROXY" "$proxy_path"
  else
    echo "Error: Found this proxy $X509_USER_PROXY but not running on lxplus?"
    exit 1
  fi
else
    echo "Error: X509 user proxy not found at $X509_USER_PROXY"
    exit 1
fi


# Create output task dir
DATASET_NAME="${GRIDPACK##*/}"          # get the filename from the path
DATASET_NAME="${DATASET_NAME%%_4f_LO*}" # remove everything from "_4f_LO" onwards
DATASET_NAME="${DATASET_NAME}_TuneCP5_${CAMPAIGN}_NANOGEN"
#TASKNAME=$(basename "$GRIDPACK" | sed 's/\.tar\.xz$//')
TASKDIR=$PWD/tasks/CondorTask_$DATASET_NAME
if [[ "$TAG" != "" ]]; then
    TASKDIR=${TASKDIR}_$TAG
fi
if [[ -d $TASKDIR ]]; then
    echo "ERROR: $TASKDIR already exists; move or delete it and run again"
    exit 1
fi

# Make new package
TARPACKAGE=${CAMPAIGN}.tar.gz
echo "Creating new package $TARPACKAGE"
sh make_package "$CAMPAIGN"
EXIT_CODE=$?

# Check if the tarball creation was successful
if [ $EXIT_CODE -ne 0 ]; then
  echo "ERROR: sh make_package $TARPACKAGE failed"
  exit 1
fi

# Verify the package was created
if [ ! -f "$TARPACKAGE" ]; then
  echo "ERROR: $TARPACKAGE does not exist!"
  exit 1
else
  echo "Tarball created successfully: $TARPACKAGE"
fi

# Create task directory for condor logs
mkdir -p $TASKDIR
cd $TASKDIR
cp $BASEDIR/executable.sh .
mv $BASEDIR/$TARPACKAGE .

# Create output directory on ceph/
OUTPUTDIRBASE="/ceph/cms/store/user/mmazza/SignalGeneration"
OUTPUTDIR=${OUTPUTDIRBASE}/${TAG}/${DATASET_NAME}
OUTPUTDIR_MINI=${OUTPUTDIR//NANO/MINI}
#mkdir -p $OUTPUTDIR $OUTPUTDIR_MINI

echo "Condor job logs will be written to $TASKDIR"
echo "Output files will be stored in $OUTPUTDIR and $OUTPUTDIR_MINI"

cat << EOF > submit.cmd
Universe                = Vanilla
request_cpus            = ${N_CPUS}
request_memory          = ${MEMORY}

executable              = executable.sh
transfer_executable     = True
arguments               = ${GRIDPACK} ${CAMPAIGN} ${NEVENTS} \$(Process) ${OUTPUTDIR}
transfer_input_files    = $TARPACKAGE
transfer_output_files   = ""

log                     = condor.log
output                  = job.\$(Cluster).\$(Process).\$(Retry).stdout
error                   = job.\$(Cluster).\$(Process).\$(Retry).stderr

should_transfer_files   = YES
when_to_transfer_output = ON_EXIT

on_exit_remove          = (ExitBySignal == False) && (ExitCode == 0)
max_retries             = 2

MY.SingularityImage     = "/cvmfs/unpacked.cern.ch/registry.hub.docker.com/cmssw/el7:$(uname -m)"
+JobFlavour             = "tomorrow"
queue ${NJOBS}
EOF

echo "Submitting job to condor"
condor_submit submit.cmd