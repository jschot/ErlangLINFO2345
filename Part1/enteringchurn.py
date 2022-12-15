import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import copy

df = pd.read_csv("Churn2.csv")

L = []
x = []
y = []
for i, row in df.iterrows() :
    L.append(row.Count)

Count = 0
for i in range(0,max(L)+2) :
    x.append(i)
    if i in L :
        Count += L.count(i)
    y.append(Count/len(L))
print(x)
print(y)
# plotting the points 
plt.plot(x, y)
  
# naming the x axis
plt.xlabel('Turn')
# naming the y axis
plt.ylabel('Percentage of entering node in more than 75% views')
  
# giving a title to my graph
plt.title('Entering churn rate by turn')
  
# function to show the plot
plt.show()