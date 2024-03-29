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
# #[1/37] CV:1.0 C2V:-2.0 C3:1.0
# launch --rewgt_name=scan_CV_1p0_c2V_1p0_c3_1p0_C3_1p0
# set NEW 1 1.0 # CV
# set NEW 2 1.0 # c2V
# set NEW 3 1.0 # c3
# set NEW 4 1.0 # C3

# create couplings 
#c2V = [-2, -1.75, -1.5, -1.25, -1.0, -0.75, -0.5, -0.25, 0.0, 
        # 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.1, 
        # 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0,
        # 2.25, 2.5, 2.75, 3.0, 3.25, 3.5, 3.75, 4.0]

l_c2V = [-2.0, -1.0, 0.0, 1.0, 2.0, 3.0, 4.0]
l_c3 = [-0.5, 0.0, 0.5, 1.0, 1.5, 2.0, 3.0, 4.0, 5.0, 6.0]



#

def numStr(num):
    return str(num).replace('.','p').replace('-','m')

#

counter = 1
n_tot = str(len(l_c2V)*len(l_c3))
table = ['rwtg c2V c3']
for c2V in l_c2V:
    for c3 in l_c3:
        text.append('\n\n#['+str(counter)+'/'+n_tot+'] CV:1.0 c2V:'+str(c2V)+' c3:'+str(c3))
        text.append('\nlaunch --rewgt_name=scan_CV_1p0_C2V_'+numStr(c2V)+'_C3_'+numStr(c3))
        text.append('\nset NEW 1 1.0 # CV')
        text.append('\nset NEW 2 ' + str(c2V) + ' # C2V')
        text.append('\nset NEW 3 ' + str(c3) + ' # C3')

        table.append('\n'+str(counter)+' '+str(c2V)+' '+str(c3))

        counter += 1

with open('./'+args.output+'/mg_reweight_card.dat', 'w') as f:
    f.writelines(text)

with open('./'+args.output+'/table_reweight_card.lst', 'w') as f:
    f.writelines(table)