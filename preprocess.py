f = open("discoveryrate.csv", "r")
fw = open("discoveryrate1000.csv", "w+")

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