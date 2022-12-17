import os
from reparator import repare
import matplotlib.pyplot as plt

FOLDER = "data"

def get_file_content(filename):
    with open(filename) as file:
        return file.read().split("\n")

def str_to_id(id):
    return int(id.replace('"', ''))

def str_to_view(view):
    return [int(e.replace("'", "")) for e in view.replace('"', '').replace("]", "").replace("[", "").split(",")]

def get_percentage(filename):
    repare(filename)
    byz_tresh = int(filename.split("_")[1])
    views = {}
    for line in get_file_content(filename)[1:-1]:
        id, view = line.split(",", 1)
        id = str_to_id(id)
        try:
            view = str_to_view(view)
            if not id in views: views[id] = []
            views[id].append(view)
        except:
            print(view)

    total_nodes = 0
    total_byzantines = 0
    for view in views.values():
        for v in reversed(view[-5:]):
            for id in v:
                total_nodes += 1
                if id > byz_tresh:
                    total_byzantines += 1
    return 100*total_byzantines/total_nodes
def print_scores():
    for file in sorted(os.listdir(FOLDER)):
        print(f"{file} : \t {round(get_percentage(os.path.join(FOLDER, file)), 2)}")

def plot_resilience_graph():
    data = {}
    for file in sorted(os.listdir(FOLDER)):
        n, l, v, b = [int(e) for e in file.rstrip((".csv")).split("_")[1:]]
        label = f"L={l}, V={v}"
        if not label in data: data[label] = {"x": [], "y" : []}
        data[label]["x"].append(b)
        data[label]["y"].append(round(get_percentage(os.path.join(FOLDER, file)), 2))
    for label, d in data.items():
        plt.scatter(d["x"], d["y"], label=label)
    plt.title("Resiliance plot")
    plt.ylabel("Proportion of Byzantine samples (%)")
    plt.xlabel("Byzantine Proportion (%)")
    plt.legend(title="Parameters")
    plt.grid()
    plt.savefig("resiliance.pdf")
    plt.show()
plot_resilience_graph()
