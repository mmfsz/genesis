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
# launch --rewgt_name=scan_CV_1p0_C2W_1p0_C2Z_1p0_C3_1p0
# set NEW 1 1.0 # CV
# set NEW 2 1.0 # C2W
# set NEW 3 1.0 # C2Z
# set NEW 4 1.0 # C3

# create couplings 
#c2W = [-2, -1.75, -1.5, -1.25, -1.0, -0.75, -0.5, -0.25, 0.0, 
        # 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.1, 
        # 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0,
        # 2.25, 2.5, 2.75, 3.0, 3.25, 3.5, 3.75, 4.0]

l_c2W = [-2.0, -1.0, 0.0, 0.5, 1.0, 1.5, 2.0, 3.0, 4.0]

# # 361 19
# l_c2W = [-2.0, -1.0, #2
#         -0.6, -0.4, -0.2, 0.0, #4
#         0.2, 0.4, 0.6,   #3
#         1.0, #1
#         1.4, 1.6, 1.8, #3
#         2.0, 2.2, 2.4, 2.6, #4
#         3.0, 4.0] #2

# # 225
# l_c2W = [-2.0, -1.0, #2
#         -0.6, -0.3, #2
#         0.0, #1
#         0.3, 0.6,   #2
#         1.0, #1
#         1.4, 1.7, #
#         2.0, 
#         2.3, 2.6, #
#         3.0, 4.0] #

# # 121
# l_c2W = [-2.0, -1.0, #2
#         -0.5, #2
#         0.0, #1
#         0.5,   #2
#         1.0, #1
#         1.5, #
#         2.0, 
#         2.5, #
#         3.0, 4.0] #

l_c2Z = l_c2W

#

def numStr(num):
    return str(num).replace('.','p').replace('-','m')

#

counter = 1
n_tot = str(len(l_c2W)*len(l_c2Z))
table = ['rwtg c2W c2Z']
for c2W in l_c2W:
    for c2Z in l_c2Z:
        text.append('\n\n#['+str(counter)+'/'+n_tot+'] CV:1.0 C2W:'+str(c2W)+' C2Z:'+str(c2Z)+' C3:1.0')
        text.append('\nlaunch --rewgt_name=scan_CV_1p0_C2W_'+numStr(c2W)+'_C2Z_'+numStr(c2Z)+'_C3_1p0')
        text.append('\nset NEW 1 1.0 # CV')
        text.append('\nset NEW 2 ' + str(c2W) + ' # C2W')
        text.append('\nset NEW 3 ' + str(c2Z) + ' # C2Z')
        text.append('\nset NEW 4 1.0 # C3')

        table.append('\n'+str(counter)+' '+str(c2W)+' '+str(c2Z))

        counter += 1

with open('./'+args.output+'/mg_reweight_card.dat', 'w') as f:
    f.writelines(text)

with open('./'+args.output+'/table_reweight_card.lst', 'w') as f:
    f.writelines(table)