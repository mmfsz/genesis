#!/bin/bash
color='\e[1;32m'
NC='\e[0m'

# USER INPUTS
jobNameTag=test
NJobs=1

# Directories
pathCeph=/ceph/cms/store/user/mmazza/gridpacks
pathCondor=$pathCeph/condor_output/
pathCondorOutput=$pathCondor/job_$jobNameTag

# If directory already exists, exit 
if [ -d pathCondorOutput ]; then
  echo "Directory exists. Exiting."
  exit 1
fi

mkdir -p  $pathCondorOutput
cd $pathCondorOutput


for i in $(seq 1 $NJobs); do 
    echo $i; 
    echo -e "${color}Submit : job ${i}"

    mkdir -p  ${pathCondorOutput}/output_${i}
    cd ${pathCondorOutput}/output_${i}
    

done



