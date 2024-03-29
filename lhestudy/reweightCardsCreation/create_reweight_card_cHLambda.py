import os
import argparse

parser = argparse.ArgumentParser(description='Create reweight_card.dat to be used in Madgraph and keep track of the couplings')
parser.add_argument('--output', default="", help='Output file name, without extension.')
args = parser.parse_args()

# heading 
text = [
    '# MM: Card created automatically with create_reweight_card.py'
    '\nchange mode NLO       # Define type of Reweighting. For LO sample this command',
    '\n                      # has no effect since only LO mode is allowed.',
    '\nchange helicity False # carry out sum over helicities (CHECK)',
    '\nchange rwgt_dir rwgt'
]
# #[1/37] CV:1.0 Lambda:-2.0 C3:1.0
# launch --rewgt_name=scan_CV_1p0_Lambda_1p0_c3_1p0_C3_1p0
# set NEW 1 1.0 # CV
# set NEW 2 1.0 # Lambda
# set NEW 3 1.0 # c3
# set NEW 4 1.0 # C3

l_Lambda = [500, 1000, 2000, 5000, 10000, 50000, 100000]
l_c3 = [-50.0, -20.0, -10.0, -1., 0.0, 1.0, 2.0, 4.0, 10.0, 30.0, 60.0, 100.0]

#

def numStr(num):
    return str(num).replace('.','p').replace('-','m')

#

counter = 1
n_tot = str(len(l_Lambda)*len(l_c3))
table = ['rwtg Lambda c3']
for Lambda in l_Lambda:
    for c3 in l_c3:
        text.append('\n\n#['+str(counter)+'/'+n_tot+'] Lambda:'+str(Lambda)+' c3:'+str(c3))
        text.append('\nlaunch --rewgt_name=scan_Lambda_'+numStr(Lambda)+'_C3_'+numStr(c3))
        text.append('\nset SMEFTCUTOFF 1 ' + str(Lambda) + ' # Lambda')
        text.append('\nset SMEFT 3 ' + str(c3) + ' # C3')

        table.append('\n'+str(counter)+' '+str(Lambda)+' '+str(c3))

        counter += 1

with open('./'+args.output+'/mg_reweight_card.dat', 'w') as f:
    f.writelines(text)

with open('./'+args.output+'/table_reweight_card.lst', 'w') as f:
    f.writelines(table)