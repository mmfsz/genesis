#!/bin/bash

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
MEM_KB=2048
N_CPUS=4
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
if [ ! -f "$GRIDPACK" ]; then
  echo "ERROR: $GRIDPACK does not exist!"
  exit 1
else
  echo "Using gridpack $GRIDPACK"
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
mkdir -p $OUTPUTDIR $OUTPUTDIR_MINI

echo "Condor job logs will be written to $TASKDIR"
echo "Output files will be stored in $OUTPUTDIR and $OUTPUTDIR_MINI"

cat << EOF > submit.cmd
Universe                = Vanilla
Requirements            = ((HAS_SINGULARITY=?=True)&&(Machine =!= LastRemoteHost)&&(Machine != "cabinet-0-0-17.t2.ucsd.edu")&&(Machine != "cabinet-4-4-12.t2.ucsd.edu"))
RequestMemory           = $MEM_KB
RequestCpus             = $N_CPUS

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
x509userproxy           = /tmp/x509up_u$(id -u)
use_x509userproxy       = True

on_exit_remove          = (ExitBySignal == False) && (ExitCode == 0)
max_retries             = 2

MY.SingularityImage     = "/cvmfs/unpacked.cern.ch/registry.hub.docker.com/cmssw/el7:$(uname -m)"
+DESIRED_Sites          = "T2_US_UCSD"
+JobBatchName           = "${DATASET_NAME}_${TAG}"

queue ${NJOBS}
EOF

condor_submit submit.cmd