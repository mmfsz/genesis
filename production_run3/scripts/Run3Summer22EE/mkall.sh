#!/bin/bash
SCRIPT_DIR=$(dirname ${BASH_SOURCE[0]}) # parent directory
source $SCRIPT_DIR/../utils.sh          # setup_cmssw, inject_fragment, set_lhegs_seed

FRAGMENT=$1
GRIDPACK=$2
CAMPAIGN=$3
EVENTS=$4
SEED=$5
NORUN=$6

if [[ "$CAMPAIGN" != "Run3Summer22EE" ]]; then
  echo "Error: running configs for Run3Summer22EE but CAMPAIGN is set to ${CAMPAIGN}"
  exit 1
fi

echo "========================================"
echo "SCRIPT_DIR = " $SCRIPT_DIR
echo "ls SCRIPT_DIR"
ls $SCRIPT_DIR
echo "CAMPAIGN = " $CAMPAIGN
echo "FRAGMENT = " $FRAGMENT
echo "GRIDPACK = " $GRIDPACK
echo "EVENTS = " $EVENTS
echo "SEED = " $SEED
echo "NORUN = " $NORUN
echo "========================================"


# == GEN,LHE =====================================
echo "========================================"
echo "     Running LHEGEN production          "
echo "========================================"
# Prepid: HIG-Run3Summer22EEwmLHEGS
setup_cmssw CMSSW_12_4_14_patch3 el8_amd64_gcc10 --no_scramb
FRAGMENT_CMSSW=$(inject_fragment $FRAGMENT $GRIDPACK $EVENTS)
echo "FRAGMENT_CMSSW = " $FRAGMENT_CMSSW
scram b -j8
cd ../..

cmsDriver.py $FRAGMENT_CMSSW \
    --python_filename HIG-LHEGS_${CAMPAIGN}_cfg.py \
    --eventcontent RAWSIM,LHE \
    --customise Configuration/DataProcessing/Utils.addMonitoring \
    --datatier GEN-SIM,LHE \
    --fileout file:HIG-LHEGS_${CAMPAIGN}.root  \
    --conditions 124X_mcRun3_2022_realistic_postEE_v1 \
    --beamspot Realistic25ns13p6TeVEarly2022Collision \
    --customise_commands process.source.numberEventsInLuminosityBlock="cms.untracked.uint32(100)" \
    --step LHE,GEN,SIM \
    --geometry DB:Extended \
    --era Run3 \
    --no_exec \
    --mc \
    -n $EVENTS 


set_lhegs_seed HIG-LHEGS_${CAMPAIGN}_cfg.py $SEED

if [ "$NORUN" != "true" ]; then 
    #cmsRun HIG-LHEGS_${CAMPAIGN}_cfg.py 2>&1 | tee tmp.log
    ((cmsRun HIG-LHEGS_${CAMPAIGN}_cfg.py | tee tmp.log) 3>&1 1>&2 2>&3 | tee tmp.log) 3>&1 1>&2 2>&3
    
    echo "cat tmp.log"
    cat tmp.log

    if [ -f "HIG-LHEGS_${CAMPAIGN}.root" ]; then
        echo "Output file HIG-LHEGS_${CAMPAIGN}.root exists."
    else
        echo "Error: Output file HIG-LHEGS_${CAMPAIGN}.root does not exist."
        exit 1
    fi

    # Check the custom log file for specific error messages during Madgraph execution 
    if grep -q "unweighted_events.lhe.gz': No such file or directory" tmp.log; then
        echo -e "\n Error detected in stderr of Madgraph execution. Exiting with code 1."
        exit 1
    fi
    if grep -q "this should never happen" tmp.log; then
        echo -e "\n Error detected in stdout of Madgraph execution. Exiting with code 1."
        exit 1
    fi
fi


# == DRPremix ========================================
echo "========================================"
echo "     Running DRPremix production        "
echo "========================================"
# Prepid: HIG-Run3Summer22EEDRPremix
# Pileup: /Neutrino_E-10_gun/Run3Summer21PrePremix-Summer22_124X_mcRun3_2022_realistic_v11-v2/PREMIX
RANDOM_PILEUPFILES=$(shuf -n 5 $SCRIPT_DIR/pileup_files.txt | tr '\n' ',') # select 5 random pileup files
RANDOM_PILEUPFILES=${RANDOM_PILEUPFILES::-1} # trim last comma

setup_cmssw CMSSW_12_4_14_patch3 el8_amd64_gcc10

cmsDriver.py  --python_filename HIG-DRPremix_${CAMPAIGN}_cfg.py \
    --eventcontent PREMIXRAW \
    --customise Configuration/DataProcessing/Utils.addMonitoring \
    --datatier GEN-SIM-RAW \
    --fileout file:HIG-DRPremix_${CAMPAIGN}.root \
    --pileup_input $RANDOM_PILEUPFILES \
    --conditions 124X_mcRun3_2022_realistic_postEE_v1 \
    --step DIGI,DATAMIX,L1,DIGI2RAW,HLT:2022v14 \
    --procModifiers premix_stage2,siPixelQualityRawToDigi \
    --geometry DB:Extended \
    --filein file:HIG-LHEGS_${CAMPAIGN}.root \
    --datamix PreMix \
    --era Run3 \
    --no_exec \
    --mc \
    -n $EVENTS

if [ "$NORUN" != "true" ]; then 
    cmsRun HIG-DRPremix_${CAMPAIGN}_cfg.py
    if [ -f "HIG-DRPremix_${CAMPAIGN}.root" ]; then
        echo "Output file HIG-DRPremix_${CAMPAIGN}.root exists."
    else
        echo "Error: Output file HIG-DRPremix_${CAMPAIGN}.root does not exist."
        exit 1
    fi
fi
#rm HIG-LHEGS_${CAMPAIGN}.root

# RECO (but in same config file as DRPremix)
echo "========================================"
echo "     Running RECO production            "
echo "========================================"

cmsDriver.py  --python_filename HIG-RECO_${CAMPAIGN}_cfg.py \
    --eventcontent AODSIM \
    --customise Configuration/DataProcessing/Utils.addMonitoring \
    --datatier AODSIM \
    --fileout file:HIG-RECO_${CAMPAIGN}.root \
    --conditions 124X_mcRun3_2022_realistic_postEE_v1 \
    --step RAW2DIGI,L1Reco,RECO,RECOSIM \
    --procModifiers siPixelQualityRawToDigi \
    --geometry DB:Extended \
    --filein file:HIG-DRPremix_${CAMPAIGN}.root \
    --era Run3 \
    --no_exec \
    --mc \
    -n $EVENTS

if [ "$NORUN" != "true" ]; then 
    cmsRun HIG-RECO_${CAMPAIGN}_cfg.py
    if [ -f "HIG-RECO_${CAMPAIGN}.root" ]; then
        echo "Output file HIG-RECO_${CAMPAIGN}.root exists."
    else
        echo "Error: Output file HIG-RECO_${CAMPAIGN}.root does not exist."
        exit 1
    fi
fi
#rm HIG-DRPremix_${CAMPAIGN}.root

# == MiniAODv4 ===================================
echo "========================================"
echo "     Running MiniAODv4 production       "
echo "========================================"
# Prepid: HIG-Run3Summer22EEMiniAODv4
setup_cmssw CMSSW_13_0_13 el8_amd64_gcc11

cmsDriver.py  --python_filename HIG-MiniAODv4_${CAMPAIGN}_cfg.py \
    --eventcontent MINIAODSIM \
    --customise Configuration/DataProcessing/Utils.addMonitoring \
    --datatier MINIAODSIM \
    --fileout file:HIG-MiniAODv4_${CAMPAIGN}.root \
    --conditions 130X_mcRun3_2022_realistic_postEE_v6 \
    --step PAT \
    --geometry DB:Extended \
    --filein file:HIG-RECO_${CAMPAIGN}.root \
    --era Run3,run3_miniAOD_12X \
    --no_exec \
    --mc \
    -n $EVENTS

if [ "$NORUN" != "true" ]; then 
    cmsRun HIG-MiniAODv4_${CAMPAIGN}_cfg.py
    if [ -f "HIG-MiniAODv4_${CAMPAIGN}.root" ]; then
        echo "Output file HIG-MiniAODv4_${CAMPAIGN}.root exists."
    else
        echo "Error: Output file HIG-MiniAODv4_${CAMPAIGN}.root does not exist."
        exit 1
    fi
fi
#rm HIG-RECO_${CAMPAIGN}.root 

# == NanoAODv9 ===================================
echo "========================================"
echo "     Running NanoAODv9 production       "
echo "========================================"
# Prepid: HIG-Run3Summer22EENanoAODv12
setup_cmssw CMSSW_13_0_13 el8_amd64_gcc11
git cms-init --upstream-only
git cms-addpkg PhysicsTools/NanoAOD
scram b -j8
cd ../..

cmsDriver.py  --python_filename HIG-NanoAODv12_${CAMPAIGN}_cfg.py \
    --eventcontent NANOEDMAODSIM \
    --customise Configuration/DataProcessing/Utils.addMonitoring \
    --datatier NANOAODSIM \
    --fileout file:HIG-NanoAODv12_${CAMPAIGN}.root \
    --conditions 130X_mcRun3_2022_realistic_postEE_v6 \
    --step NANO \
    --scenario pp \
    --filein file:HIG-MiniAODv4_${CAMPAIGN}.root \
    --era Run3 \
    --no_exec \
    --mc \
    -n $EVENTS
  
if [ "$NORUN" != "true" ]; then 
    cmsRun HIG-NanoAODv12_${CAMPAIGN}_cfg.py
    if [ -f "HIG-NanoAODv12_${CAMPAIGN}.root" ]; then
        echo "Output file HIG-NanoAODv12_${CAMPAIGN}.root exists."
    else
        echo "Error: Output file HIG-NanoAODv12_${CAMPAIGN}.root does not exist."
        exit 1
    fi
fi
