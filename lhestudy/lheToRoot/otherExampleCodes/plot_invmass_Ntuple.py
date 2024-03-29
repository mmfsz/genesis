import ROOT
ROOT.ROOT.EnableImplicitMT()

import argparse

parser = argparse.ArgumentParser(description='plot dilepton invariant mass spectrum')
parser.add_argument('--type', choices=['dilepton', 'dijet'], help='which spectrum to plot')
parser.add_argument('--files', metavar='FILE', nargs='+', help='ROOT files to process')
parser.add_argument('--output', default=None, help='output file name, without extension')
args = parser.parse_args()

linecolor = [ROOT.kRed, ROOT.kBlue, ROOT.kGreen, ROOT.kOrange, ROOT.kMagenta, ROOT.kCyan, ROOT.kYellow, ROOT.kBlack]


 
def construct_spec(df):
    if args.type == 'dilepton':
        ids = " || ".join([f"abs(pid) == {id}" for id in [11, 13, 15]])
    elif args.type == 'dijet':
        ids = " || ".join([f"abs(pid) == {id}" for id in [1, 2, 3, 4, 5, 21]])
    else:
        raise ValueError("invalid type")

    df_2partons = df.Define("FinalStatePartons", f"status == 1 && ({ids})") 
    df_2partons = df_2partons.Define("FSP_px", "px[FinalStatePartons]")
    df_2partons = df_2partons.Define("FSP_py", "py[FinalStatePartons]")
    df_2partons = df_2partons.Define("FSP_pz", "pz[FinalStatePartons]")
    df_2partons = df_2partons.Define("FSP_energy", "energy[FinalStatePartons]")
    df_2partons = df_2partons.Define("FSP_mass", "mass[FinalStatePartons]")
    df_2partons = df_2partons.Define("FSP_pt", "sqrt(FSP_px*FSP_px + FSP_py*FSP_py)")
    df_2partons = df_2partons.Define("FSP_eta", "0.5*log((FSP_energy + FSP_pz)/(FSP_energy - FSP_pz))")
    df_2partons = df_2partons.Define("FSP_phi", "atan2(FSP_py, FSP_px)")
    df_2partons = df_2partons.Define("spec", "InvariantMass(FSP_pt, FSP_eta, FSP_phi, FSP_mass)")
    h = df_2partons.Histo1D(ROOT.RDF.TH1DModel("massspec", "invmass;m[GeV];A.U.", 50,50,150), "spec", "eventweight")
    return h

histos = {}
for file in args.files:
    print(file)
    name = file.split("/")[-1].split(".")[0]
    df = ROOT.RDataFrame("events", file)
    h = construct_spec(df)
    h.Print()
    histos[name] = h

    

# Produce plot
ROOT.gStyle.SetOptStat(0); ROOT.gStyle.SetTextFont(42)
c = ROOT.TCanvas("c", "", 800, 700)
c.Draw()
c.SetLogy()
c.SetLogx()
for ic,(name,h) in enumerate(histos.items()):
    print("processing: ", name, "\t ", ic)

    h.SetTitle("")

    h.SetLineColor(linecolor[0])
    h_clone = h.Clone(name)
    h_clone.SetLineColor(linecolor[ic])
     
    if ic == 0:
        print("drawing: ", name)
        h_clone.GetXaxis().SetMoreLogLabels()
        h_clone.DrawClone('h')
    else:
        print("drawing: ", name)
        h_clone.DrawClone('hsame')
c.BuildLegend(0.7, 0.7, 0.9, 0.9)

if args.output:
    c.SaveAs(args.output + ".pdf")
    c.SaveAs(args.output + ".png")
else:
    c.SaveAs(f"plot_{args.type}.pdf")
    c.SaveAs(f"plot_{args.type}.png")
