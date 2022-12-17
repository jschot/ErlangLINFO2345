def is_line_ok(line):
    return ('[' in line) and (']' in line)

def is_repare_needed(file):
    with open(file) as f:
        for line in f.readlines()[1:]:
            if not is_line_ok(line):
                return True
        return False

def repare(file):
    if not is_repare_needed(file): return
    content = None
    good_content = []
    with open(file) as f:
        content = f.read().split()
    curr = ""
    for i, line in enumerate(content):
        if i == 0:
            good_content.append(line)
        else:
            if is_line_ok(line):
                if curr != "":
                    good_content.append(curr)
                    curr = ""
                good_content.append(line)
            else:
                curr += line
    good_content.append(curr)
    with open(file, "w") as f:
        f.write("\n".join(good_content))


# print(repare("data/discoveryrate_70_5_20_30.csv"))
# repare("data/discoveryrate_90_5_20_10.csv")
