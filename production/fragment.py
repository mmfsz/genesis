import FWCore.ParameterSet.Config as cms

externalLHEProducer = cms.EDProducer(
    "ExternalLHEProducer",
    args=cms.vstring("GRIDPACK_SED_PLACEHOLDER"),
    nEvents=cms.untracked.uint32(NEVENTS_SED_PLACEHOLDER),
    generateConcurrently=cms.untracked.bool(False),
    numberOfParameters=cms.uint32(1),
    outputFile=cms.string("cmsgrid_final.lhe"),
    scriptName=cms.FileInPath("GeneratorInterface/LHEInterface/data/run_generic_tarball_cvmfs.sh")
)

from Configuration.Generator.Pythia8CommonSettings_cfi import *
from Configuration.Generator.MCTunes2017.PythiaCP5Settings_cfi import *
from Configuration.Generator.PSweightsPythia.PythiaPSweightsSettings_cfi import *

generator = cms.EDFilter(
    "Pythia8ConcurrentHadronizerFilter",                # for dipoleRecoil = on
    maxEventsToPrint=cms.untracked.int32(1),
    pythiaPylistVerbosity=cms.untracked.int32(1),
    filterEfficiency=cms.untracked.double(1.),
    pythiaHepMCVerbosity=cms.untracked.bool(False),
    comEnergy=cms.double(13000.),
    PythiaParameters=cms.PSet(
        pythia8CommonSettingsBlock,
        pythia8CP5SettingsBlock,
        pythia8PSweightsSettingsBlock,
        processParameters = cms.vstring(
            "SpaceShower:dipoleRecoil = on",            # for dipoleRecoil = on
        ),
        parameterSets=cms.vstring(
            "pythia8CommonSettings",
            "pythia8CP5Settings",
            "pythia8PSweightsSettings",
            "processParameters",                        # for dipoleRecoil = on
        )
    )
)

ProductionFilterSequence = cms.Sequence(generator)