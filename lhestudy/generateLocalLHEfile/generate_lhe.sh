#!/bin/bash
# generate_lhe.sh
# Usage: bash generate_lhe.sh <FULL_GRIDPACK_PATH> <NEVENTS>
# Example:
# bash generate_lhe.sh /home/users/mmazza/projects/genesis/lhestudy/generateLocalLHEfile/gridpacks/VBSWWH_OS_VBSCuts_13TeV_4f_LO_MG_2_9_18_c2v_1p0_c3_1p0_c2Vc3scan_slc7_amd64_gcc10_CMSSW_12_4_8_tarball.tar.xz 10000

GRIDPACK_TARBALL="$1"
NEVENTS="$2"

# Check inputs
if [[ -z "$GRIDPACK_TARBALL" || -z "$NEVENTS" ]]; then
  echo "Usage: bash $0 <FULL_GRIDPACK_PATH_WITH_TARBALL> <NEVENTS>"
  exit 1
fi

# Ensure the input file exists
if [[ ! -f "$GRIDPACK_TARBALL" ]]; then
  echo "Error: Gridpack not found at $GRIDPACK_TARBALL"
  exit 1
fi

# Derive gridpack name by stripping the _tarball.tar.xz suffix
GRIDPACK_NAME=$(basename "$GRIDPACK_TARBALL" _tarball.tar.xz)

# Define output directory and file
OUTDIR="/ceph/cms/store/user/mmazza/lheFiles"
OUTFILE="${OUTDIR}/${GRIDPACK_NAME}.lhe"

# Create and move into temporary directory
WORKDIR="test_gridpack_tmp_"${GRIDPACK_NAME}
mkdir -p "$WORKDIR"
cd "$WORKDIR" || exit 1

# Extract gridpack
echo "Extracting gridpack: $GRIDPACK_TARBALL"
tar -xaf "$GRIDPACK_TARBALL"

# Run the gridpack
echo "Running runcmsgrid.sh with $NEVENTS events..."
# ./runcmsgrid.sh <NEVENTS> <RANDOM_SEED> <N_CPUS>
./runcmsgrid.sh "$NEVENTS" 123 4

# Move the output file
echo "Moving cmsgrid_final.lhe to $OUTFILE"
mv cmsgrid_final.lhe "$OUTFILE"

# Clean up
cd ..
rm -rf "$WORKDIR"

echo "✅ Done! LHE file saved to: $OUTFILE"
