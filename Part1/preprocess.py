f = open("discoveryrate1000-50-100.csv", "r")
fw = open("discoveryrate1000_50_100.csv", "w+")

data = f.read()
isList = False
count = 0
for i in range(len(data)):
    if data[i] == '[':
        isList = True
    if data[i] == ']':
        isList = False
        
    if isList:
        if data[i] != ' ' and data[i] != '\n':
            fw.write(data[i])
    else :
        fw.write(data[i])
    
    


f.close()
fw.close()