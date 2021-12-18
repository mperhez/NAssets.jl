import numpy as np
import networkx as nx
import matplotlib.pyplot as plt

def optimisation_initialisation(Topology_matrix, Traffic_distribution_parameters, pred_main_cost, pred_main_time, reac_main_cost, reac_main_time):

    def relabel_nodes(G, mapping, copy=True):
        if not hasattr(mapping, "__getitem__"):
            m = {n: mapping(n) for n in G} 
        else:
            m = mapping
        if copy:
            return _relabel_copy(G, m)
        else:
            return _relabel_inplace(G, m)

# 1. Read input parameters:
    H=nx.from_numpy_matrix(Topology_matrix)

    #mapping={ 0: 1, 1: 2, 2: 3, 3: 4, 4:5, 5:6, 6:7, 7:8, 8:9, 9:10, 10:11, 11:12, 12:13, 13:14, 14:15, 15:16}
    #H = nx.relabel_nodes(H, mapping)

    nx.draw(H, node_size = 50, with_labels = True)

    #plt.show()

    ##Network:
    #H=G
    global n
    n=len(Topology_matrix)
    global H2
    H2 = H.to_directed()
    global nodes
    nodes=list(H.nodes)
    global nodes_set
    nodes_set=np.arange(0,len(nodes))
    #Attributes of edges
    #nx.set_edge_attributes(H2, 0.1,'weight')
    #H2[12][13]['weight']=0.09999999999999999999999999999999999999
    #H2[1][5]['weight']=0.09999999999999999999999999999999999999
    nx.set_edge_attributes(H2, 10000,'capacity')
    
    global Pred_main_cost
    Pred_main_cost=pred_main_cost
    global Pred_main_time
    Pred_main_time=pred_main_time
    global Reac_main_cost
    Reac_main_cost=reac_main_cost
    global Reac_main_time
    Reac_main_time=reac_main_time

    return




