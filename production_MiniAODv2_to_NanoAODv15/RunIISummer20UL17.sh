#!/bin/bash
input_file=$1 # e.g. output_1.root
input_mini_dir_path=$2
output_nano_dir_path=$3 # this directory is created in the submit script
EVENTS=$4
NORUN=$5

input_mini_file="${input_mini_dir_path}/${input_file}"
tmp_mini_file="MiniAODv2.root"
tmp_nano_file="NanoAODv15.root"
output_nano_file="${output_nano_dir_path}/${input_file}"


echo "========================================"
echo "input_file = " $input_file
echo "input_mini_dir_path = " $input_mini_dir_path
echo "output_nano_dir_path = " $output_nano_dir_path
echo "EVENTS = " $EVENTS
echo "NORUN = " $NORUN

echo "input_mini_file = " $input_mini_file
echo "output_nano_file = " $output_nano_file
echo "========================================"

# Retrieve and set X509_USER_PROXY
# Note: custom_proxy_path relies on the submit script to have copied the proxy in afs 
user=$(whoami)
initial=${user:0:1}
uid=$(id -u)
custom_proxy_path="/afs/cern.ch/user/$initial/$user/x509up_u$uid"
X509_USER_PROXY="${X509_USER_PROXY:-/tmp/x509up_u$(id -u)}"
echo "X509_USER_PROXY = $X509_USER_PROXY"
if [[ -f "$tmp_proxy" ]]; then
    export X509_USER_PROXY="$tmp_proxy"
elif [[ -f "$custom_proxy_path" ]]; then
    export X509_USER_PROXY="$custom_proxy_path"
elif [[ -n "$X509_USER_PROXY" && -f "$X509_USER_PROXY" ]]; then
    echo Proxy already set and exists, e.g. on UAF - do nothing
else
    echo "Error: X509 user proxy not found or inaccessible"
    exit 1
fi
echo -e "\n --> Check proxy status with voms-proxy-info"
voms-proxy-info

# Setup cms environment
if [ -r /cvmfs/cms.cern.ch/cmsset_default.sh ]; then
    echo -e "\n --> Source environment:  source /cvmfs/cms.cern.ch/cmsset_default.sh"
    source /cvmfs/cms.cern.ch/cmsset_default.sh
else
    echo "ERROR! Couldn't find $OSGVO_CMSSW_Path/cmsset_default.sh or /cvmfs/cms.cern.ch/cmsset_default.sh or $OSG_APP/cmssoft/cms/cmsset_default.sh"
    exit 1
fi

function setup_cmssw() {
  CMSSW_VERSION=$1
  export SCRAM_ARCH=$2
  source /cvmfs/cms.cern.ch/cmsset_default.sh
  if [ -r $CMSSW_VERSION/src ] ; then
    echo release $CMSSW_VERSION already exists
  else
    scram p CMSSW $CMSSW_VERSION
  fi
  cd $CMSSW_VERSION/src
  echo "moved to $PWD"
  eval `scram runtime -sh`

  scram b -j 4
  cd ../..
}


function stageout {
    COPY_SRC=$1
    COPY_DEST=$2
    retries=0
    COPY_STATUS=1
    until [ $retries -ge 5 ]
    do
        echo "Stageout attempt $((retries+1)): env -i X509_USER_PROXY=${X509_USER_PROXY} gfal-copy -p -f -t 7200 --verbose --checksum ADLER32 ${COPY_SRC} ${COPY_DEST}"
        env -i X509_USER_PROXY=${X509_USER_PROXY} gfal-copy -p -f -t 7200 --verbose --checksum ADLER32 ${COPY_SRC} ${COPY_DEST}
        COPY_STATUS=$?
        if [ $COPY_STATUS -ne 0 ]; then
            echo "Failed stageout attempt $((retries+1))"
        else
            echo "Successful stageout with $retries retries"
            break
        fi
        retries=$[$retries+1]
        echo "Sleeping for 5m"
        sleep 5m
    done
    if [ $COPY_STATUS -ne 0 ]; then
        echo "Removing output file because gfal-copy crashed with code $COPY_STATUS"
        env -i X509_USER_PROXY=${X509_USER_PROXY} gfal-rm --verbose ${COPY_DEST}
        REMOVE_STATUS=$?
        if [ $REMOVE_STATUS -ne 0 ]; then
            echo "Uhh, gfal-copy crashed and then the gfal-rm also crashed with code $REMOVE_STATUS"
            echo "You probably have a corrupt file sitting on hadoop now."
            exit 1
        fi
    fi
}


# ============ Copy file over ===============
# Copy gridpack to destination
echo -e "\n --> Copy MINIAOD file to current directory" 
echo -e "\n pwd"
pwd
export REP="/store"
COPY_SRC="davs://redirector.t2.ucsd.edu:1095/${input_mini_file/\/ceph\/cms}"
echo "COPY_SRC  = $COPY_SRC"
COPY_DEST="file://${PWD}/${tmp_mini_file}"
stageout $COPY_SRC $COPY_DEST
echo -e "\n ls -lrth"
ls -lrth


# ============ MiniAODv2 -> NanoAODv15 ===============

# Setup environment
setup_cmssw CMSSW_15_0_15_patch4 el8_amd64_gcc12 

tmp_mini_file="MiniAODv2.root"
tmp_nano_file="NanoAODv15.root"
# Create config file
cmsDriver.py  \
    --eventcontent NANOAODSIM \
    --customise Configuration/DataProcessing/Utils.addMonitoring \
    --datatier NANOAODSIM \
    --conditions 150X_mc2017_realistic_v1 \
    --step NANO \
    --era Run2_2017,run2_nanoAOD_106Xv2 \
    --python_filename NanoAODv15_cfg.py \
    --fileout file:NanoAODv15.root \
    --filein file:MiniAODv2.root \
    --no_exec \
    --mc \
    -n $EVENTS;


if [[ "$NORUN" != "true" ]]; then 
    # Run production
    cmsRun NanoAODv15_cfg.py; 
    if [ ! -f ${tmp_nano_file} ]; then
        echo "Error: File ${tmp_nano_file} does not exist. Exiting."
        exit 1
    fi

    # Stage out
    
    COPY_SRC="file://${PWD}/${tmp_nano_file}"
    COPY_DEST="davs://redirector.t2.ucsd.edu:1095/${output_nano_file}"
    stageout $COPY_SRC $COPY_DEST
fi

echo "Successfully stored NanoAODv15 file at $output_nano_file"

# == NanoAODv15 ===================================
