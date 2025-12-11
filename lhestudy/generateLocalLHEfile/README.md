# LHE Event Generation 
This script can be used to quickly generate LHE events from a gridpack. It simply unpacks the tarball and runs the script  `runcmsgrid.sh`
provided inside the tarball.

Usage:
```
bash generate_lhe.sh <FULL_GRIDPACK_PATH> <NEVENTS>
```

Note: 
- ```FULL_GRIDPACK_PATH``` has to be the absolute path
- A random seed is set inside `generate_lhe.sh` such that the events production is deterministic 
- The script `runcmsgrid.sh` is called with the hardcoded value of 4 CPUs. This can be changed inside `generate_lhe.sh`.
- If the gridpack was generated with el7, the script has to run inside a singularity. Inside the singularity, `ceph` is not visible so the gridpacks have to be copied locally temporarily. 

Example:
```
bash generate_lhe.sh /home/users/mmazza/projects/genesis/lhestudy/generateLocalLHEfile/gridpacks/VBSWWH_OS_VBSCuts_13TeV_4f_LO_MG_2_9_18_c2v_1p0_c3_1p0_c2Vc3scan_slc7_amd64_gcc10_CMSSW_12_4_8_tarball.tar.xz 10000
```

Optionally start an el7 singularity before running the previous command: 
```
cmssw-cc7
```