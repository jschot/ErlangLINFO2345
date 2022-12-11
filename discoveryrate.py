import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import copy

df = pd.read_csv("discoveryrate1000.csv")

turn = dict()
discoverednodes = dict()

for i, row in df.iterrows() :
    if row.ID in turn.keys() :
        turn[row.ID] = turn[row.ID]+1
    else :
        turn[row.ID] = 1
    if row.ID in discoverednodes.keys() :
        for elem in set(row.Table.replace("[", "").replace("]", "").split(",")) :
            if turn[row.ID] not in discoverednodes[row.ID].keys():
                ref = copy.deepcopy(discoverednodes[row.ID][turn[row.ID]-1])
                ref.add(elem)
                discoverednodes[row.ID][turn[row.ID]] = ref
            else:
                ref = copy.deepcopy(discoverednodes[row.ID][turn[row.ID]])
                ref.add(elem)
                discoverednodes[row.ID][turn[row.ID]] = ref
    else :
        discoverednodes[row.ID] = dict()
        discoverednodes[row.ID][turn[row.ID]] = set(row.Table.replace("[", "").replace("]", "").split(","))

for i in discoverednodes.keys() :
    print("Noeud {} :  {}N - {}% en {} turn".format(i,len(discoverednodes[i][turn[i]]),(len(discoverednodes[i][turn[i]])/1000)*100,turn[i]))

# x axis values
x = []
for i in range(0,max(turn.values())):
    x.append(i)

# corresponding y axis values
y = [0]
for i in range(1,max(turn.values())):
    sum = 0
    cnt = 0
    for j in range(1,max(turn.keys())) :
        if turn[j] >= i :
            cnt += 1
            sum += (len(discoverednodes[j][i])/1000)*100
    avg = sum/cnt
    y.append(avg)


# plotting the points 
plt.plot(x, y)
  
# naming the x axis
plt.xlabel('Turn')
# naming the y axis
plt.ylabel('Avg discovery rate')
  
# giving a title to my graph
plt.title('Average discovery rate by turn')
  
# function to show the plot
plt.show()