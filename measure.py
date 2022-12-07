import pandas as pd
import numpy as np

df = pd.read_csv("discoveryrate.csv")

turn = dict()
discoverednodes = dict()

for i, row in df.iterrows() :
    if row.ID in turn.keys() :
        turn[row.ID] = turn[row.ID]+1
    else :
        turn[row.ID] = 1
    if row.ID in discoverednodes.keys() :
        for elem in set(row.Table.replace("[", "").replace("]", "").split(",")) :
            discoverednodes[row.ID].add(elem)
    else :
        discoverednodes[row.ID] = set(row.Table.replace("[", "").replace("]", "").split(","))

for i in discoverednodes.keys() :
    print("Noeud {} : {}% en {} turn".format(i,(len(discoverednodes[i])/50)*100,turn[i]))
