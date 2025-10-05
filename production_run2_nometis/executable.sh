#!/bin/bash

GRIDPACK=$1 #full path to input gridpack
CAMPAIGN=$2
NEVENTS=$3
IJOB=$4
SEED=$(( $IJOB + 99 )) #seed cannot be 0
OUTPUTDIR=$5

#X509_USER_PROXY=$1
# Retrieve and set X509_USER_PROXY
user=$(whoami)
initial=${user:0:1}
uid=$(id -u)
proxy_path="/afs/cern.ch/user/$initial/$user/x509up_u$uid"

if [[ -f "$proxy_path" ]]; then
    export X509_USER_PROXY="$proxy_path"
elif [[ -n "$X509_USER_PROXY" && -f "$X509_USER_PROXY" ]]; then
    # Already set and exists (e.g., on UAF) - do nothing
else
    echo "Error: X509 user proxy not found or inaccessible"
    exit 1
fi

function stageout {
    COPY_SRC=$1
    COPY_DEST=$2
    retries=0
    COPY_STATUS=1
    until [ $retries -ge 10 ]
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

# Setup cms environment
if [ -r "$OSGVO_CMSSW_Path"/cmsset_default.sh ]; then
    echo "sourcing environment: source $OSGVO_CMSSW_Path/cmsset_default.sh"
    source "$OSGVO_CMSSW_Path"/cmsset_default.sh
elif [ -r "$OSG_APP"/cmssoft/cms/cmsset_default.sh ]; then
    echo "sourcing environment: source $OSG_APP/cmssoft/cms/cmsset_default.sh"
    source "$OSG_APP"/cmssoft/cms/cmsset_default.sh
elif [ -r /cvmfs/cms.cern.ch/cmsset_default.sh ]; then
    echo "sourcing environment: source /cvmfs/cms.cern.ch/cmsset_default.sh"
    source /cvmfs/cms.cern.ch/cmsset_default.sh
else
    echo "ERROR! Couldn't find $OSGVO_CMSSW_Path/cmsset_default.sh or /cvmfs/cms.cern.ch/cmsset_default.sh or $OSG_APP/cmssoft/cms/cmsset_default.sh"
    exit 1
fi

# Check inputs and environment
echo -e "\n--- Header output ---\n" 
echo "GRIDPACK: $GRIDPACK"
echo "CAMPAIGN: $CAMPAIGN"
echo "NEVENTS: $NEVENTS"
echo "SEED: $SEED"
echo "OUTPUTDIR: $OUTPUTDIR"

echo "GLIDEIN_CMSSite: $GLIDEIN_CMSSite"
echo "hostname: $(hostname)"
echo "uname -a: $(uname -a)"
echo "time: $(date +%s)"
#echo "tag: $(getjobad tag)"
#echo "taskname: $(getjobad taskname)"

echo -e "\n --> Check linux version with cat /etc/os-release"
cat /etc/os-release

echo -e "\n --> Check proxy status with voms-proxy-info"
voms-proxy-info

# Copy gridpack to destination
echo -e "\n --> Copy gridpack to current directory" 
echo -e "\n pwd"
pwd

export REP="/store"
COPY_SRC="davs://redirector.t2.ucsd.edu:1095/${GRIDPACK/\/ceph\/cms\/store/$REP}"
COPY_DEST="file://${PWD}/$(basename $GRIDPACK)"
stageout $COPY_SRC $COPY_DEST

echo -e "\n ls -lrth"
ls -lrth

# Unzip tarball
echo -e "\n --> Unzip tarball ${CAMPAIGN}.tar.gz" 
tar -xzf ${CAMPAIGN}.tar.gz

echo -e "\n ls -lrth"
ls -lrth

# Run main script
echo -e "\n --> Run mkall.sh \n" 
if [[ -f $PWD/$(basename $GRIDPACK) ]]; then
    sh scripts/${CAMPAIGN}/mkall.sh $PWD/fragment.py $PWD/$(basename $GRIDPACK) $CAMPAIGN $NEVENTS $SEED 
fi

CMSRUN_STATUS=$?
echo -e "\n ls -lrth"
ls -lrth
echo "CMSRUN_STATUS = $CMSRUN_STATUS"
if [[ $CMSRUN_STATUS != 0 ]]; then
    echo "Removing output file because cmsRun crashed with exit code $?"
    rm *.root
    exit 1
fi

# Copy output files over
OUTDIR="${OUTPUTDIR/\/ceph\/cms\/store/$REP}"
gfal-mkdir -p $OUTDIR
echo "Creating output dir: $OUTDIR"
env -i X509_USER_PROXY=${X509_USER_PROXY} gfal-mkdir -p $OUTDIR


OUTPUTNAME="output"
echo -e "\n --> Begin copying output to $OUTDIR" 
echo "time before copy: $(date +%s)"

echo "Copy MiniAODv2_${CAMPAIGN}.root"
COPY_SRC="file://${PWD}/MiniAODv2_${CAMPAIGN}.root"
COPY_DEST="davs://redirector.t2.ucsd.edu:1095/${OUTDIR//NANO/MINI}/${OUTPUTNAME}_${IJOB}.root"
stageout $COPY_SRC $COPY_DEST

echo "Copy NanoAODv9_${CAMPAIGN}.root"
COPY_SRC="file://${PWD}/NanoAODv9_${CAMPAIGN}.root"
COPY_DEST="davs://redirector.t2.ucsd.edu:1095/${OUTDIR}/${OUTPUTNAME}_${IJOB}.root"
stageout $COPY_SRC $COPY_DEST

echo -e "\n --> End copying output" 
echo "time at end: $(date +%s)"

