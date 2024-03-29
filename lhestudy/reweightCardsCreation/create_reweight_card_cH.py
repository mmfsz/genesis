import os
import argparse

parser = argparse.ArgumentParser(description='Create reweight_card.dat to be used in Madgraph and keep track of the couplings')
parser.add_argument('--output', default="", help='Output file name, without extension.')
parser.add_argument('--Lambda', help='Lambda to give to param card.')

args = parser.parse_args()
Lambda = args.Lambda
# heading 
text = [
    '# MM: Card created automatically with create_reweight_card.py'
    '\nchange mode NLO       # Define type of Reweighting. For LO sample this command',
    '\n                      # has no effect since only LO mode is allowed.',
    '\nchange helicity False # carry out sum over helicities (CHECK)',
    '\nchange rwgt_dir rwgt'
]
# #[1/37] CV:1.0 C2V:-2.0 C3:1.0
# launch --rewgt_name=scan_CH_1p0
# set SMEFTCUTOFF 1 500
# set SMEFT 3 1.0 # CH

# create couplings 
# Lambda500
# l_cH = [-2.0, -1.5,
#         -1.0, 0.9, -0.8, -0.7, -0.6, -0.5, -0.4, -0.3, -0.2, -0.1, 
#         0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 
#         1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 
#         2.0, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9,
#         3.0, 3.5, 4.0]
#
# Lambda100000
l_cH = [-3., -2.8, -2.6, -2.4, -2.2,
        -2.0, -1.8, -1.6, -1.4, -1.2, 
        -1.0, -0.8, -0.6, -0.4, -0.2, 
        0.0, 0.2, 0.4, 0.6, 0.8, 
        1.0, 1.2, 1.4, 1.6, 1.8, 
        2.0, 2.2, 2.4, 2.6, 2.8,
        3.0, 3.2, 3.4, 3.6, 3.8, 
        4.0, 4.2, 4.4, 4.6, 4.8, 
        5.0, 5.2, 5.4, 5.6, 5.8, 
        6.0, 6.2, 6.4, 6.6, 6.8, 
        7.0, 7.2, 7.4, 7.6, 7.8,
        8.0, 8.2, 8.4, 8.6, 8.8, 
        9.0, 9.2, 9.4, 9.6, 9.8, 10]

l_cH = np.range(-20, 20)

def numStr(num):
    return str(num).replace('.','p').replace('-','m')

#

counter = 1
n_tot = str(len(l_cH))
table = ['rwtg cH']
for cH in l_cH:
        text.append('\n\n#['+str(counter)+'/'+n_tot+'] CH:'+str(cH))
        text.append('\nlaunch --rewgt_name=scan_CH_'+numStr(cH))
        text.append('\nset SMEFTCUTOFF 1 ' + str(Lambda) + ' # Lambda')
        text.append('\nset SMEFT 3 ' + str(cH) + ' # CH')

        table.append('\n'+str(counter)+' '+str(cH))
        counter += 1

with open('./'+args.output+'/mg_reweight_card_Lambda'+str(Lambda)+'.dat', 'w') as f:
    f.writelines(text)

with open('./'+args.output+'/table_reweight_card_Lambda'+str(Lambda)+'.lst', 'w') as f:
    f.writelines(table)
