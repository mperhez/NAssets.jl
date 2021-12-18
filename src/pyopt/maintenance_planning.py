import numpy as np
import networkx as nx
import matplotlib.pyplot as plt
from gurobipy import *


def maintenance_planning(current_time_step, Services, Predicted_RUL_matrix):
    def findTuple(elem):
        for t in arcs_sol_2[kl]:
            if t[0]==elem:
                return t
        return None
    def all_simple_paths(G, source, target, cutoff=None):
        if source not in G:
            raise nx.NetworkXError('source node %s not in graph'%source)
        if target not in G:
            raise nx.NetworkXError('target node %s not in graph'%target)
        if cutoff is None:
            cutoff = len(G)-1
            return _all_simple_paths_graph(G, source, target, cutoff=cutoff)

    def _all_simple_paths_graph(G, source, target, cutoff=None):
        if cutoff < 1:
            return
        visited = [source]
        stack = [iter(G[source])]
        while stack:
            children = stack[-1]
            child = next(children, None)
            if child is None:
                stack.pop()
                visited.pop()
            elif len(visited) < cutoff:
                if child == target:
                    yield visited + [target]
                elif child not in visited:
                    visited.append(child)
                    stack.append(iter(G[child]))
            else: #len(visited) == cutoff:
                if child == target or target in children:
                    yield visited + [target]
                stack.pop()
                visited.pop()
    from optimisation_initialisation import H2, nodes, n, Pred_main_time, Pred_main_cost, Reac_main_time, Reac_main_cost
    global maint_in_progress
    global original_routes
    # 1. Input parameters
    #n=len(Topology_matrix)
    T=len(Predicted_RUL_matrix[0])
    time_periods=np.arange(0,T)
    d_step=1
    #Sources and sinks of connections:
    sources=np.squeeze(np.asarray(Services[:,0]))
    sinks=np.squeeze(np.asarray(Services[:,1]))
    #[7,12,14]
    kl_set=np.arange(0,len(sources))
    #demand
    d= [[400 for x in range(len(kl_set))] for y in range(len(time_periods))] 
    
    # 2. Create different sets of arcs required for optimisation
    #Arcs that lie on a possible path from source to sink for this specific connection:
    arcs=[]
    arcs_all_dupl=[]
    for kl in kl_set:
        paths_kl = nx.all_simple_paths(H2, source=sources[kl], target=sinks[kl])    
        arcs_kl=[]
        for i in list(paths_kl):
            for j in np.arange(0,len(i)-1):
                arcs_kl.append((i[j],i[j+1]))
                arcs_all_dupl.append((i[j],i[j+1]))
        arcs_kl_no_duplicates=list(dict.fromkeys(arcs_kl))
        arcs.append(arcs_kl_no_duplicates)
    arcs_all=list(dict.fromkeys(arcs_all_dupl))

    arcs_both=[]
    arcs_single=[]
    for a in arcs_all:
        if a[::-1] in arcs_all:
            if a[::-1] not in arcs_both:
                arcs_both.append(a)
        else:
            arcs_single.append(a)

    arcs_all_no_arcs=[]
    for kl in kl_set:
        arcs_all_no_arcs.append([item for item in arcs_all if item not in arcs[kl]])

    arcs_set=np.arange(0,len(arcs_all))
    arcs_both_set=np.arange(0,len(arcs_both))
    arcs_single_set=np.arange(0,len(arcs_single))

    #3. Disruption (links and nodes that are subject to failure):

    disr_arcs_2=[]
    disr_arcs_2_reverse= [arc[::-1] for arc in disr_arcs_2]

    p_a=np.zeros((4,T))

    # Input parameters:
    #prev_main_a=[-5,-7,-2,-5]
    prev_main_a=[]
    C_rea_a=[150,150,150,150]
    C_pre_a=[100,100,100,100]
    t_rea_a=[5,5,5,5]
    t_pre_a=[3,3,3,3]

    disr_arcs_2_set=np.arange(0,len(disr_arcs_2))

    disr_nodes=[]
    p_v=[]
    bar_t=[]
    C_rea_v=[]
    C_pre_v=[]
    t_rea_v=[]
    t_pre_v=[]

    if current_time_step==10:
        maint_in_progress=np.zeros((n,1000))

    #print("2pred", Predicted_RUL_matrix)

    for i in range(n):
        a=(-Predicted_RUL_matrix[i,:]+9)/36
        a[a < 0] = 0
        #print(Predicted_RUL_matrix[i,:])
        #print(a)
        if not np.all((a == 0)):
            if maint_in_progress[i,current_time_step]==0:
                disr_nodes.append(i)
                p_v.append(a.tolist())
                c=next((i for i, x in enumerate(a.tolist()) if x), None)
                #print(a)
                if c==0:
                    bar_t.append(Predicted_RUL_matrix[i,0])
                else:
                    bar_t.append(c+8)
                # Input parameters:
                #C_rea_v=[150,150,150,150]
                #C_pre_v=[100,100,100,100]
                #t_rea_v=[5,5,5,5]
                #t_pre_v=[3,3,3,3]
                C_rea_v.append(Reac_main_cost)
                C_pre_v.append(Pred_main_cost)
                t_rea_v.append(Reac_main_time)
                t_pre_v.append(Pred_main_time)
    #print(maint_in_progress[1,current_time_step])

    Prev_main=Predicted_RUL_matrix[:,0]-101
    #print(Prev_main)
    #print(disr_nodes)
    prev_main_v=np.take(Prev_main,disr_nodes)

    disr_nodes_set=np.arange(0,len(disr_nodes))

    disr_arcs=disr_arcs_2

    for i in range(len(disr_nodes)):
        new_disr_arcs=[(pointsFrom, pointsTo) for (pointsFrom, pointsTo) in arcs_all if (disr_nodes[i]==pointsTo or disr_nodes[i]==pointsFrom)]
        disr_arcs=disr_arcs+new_disr_arcs

    #print(disr_arcs)
    disr_arcs_set=np.arange(0,len(disr_arcs))

    # 4. Optimization model:
    m = Model('Rerouting_model')

    # 4.1 Optimisation model - Decision variables:
    x = m.addVars(time_periods, kl_set, arcs_all, lb=0.0, ub=GRB.INFINITY, vtype=GRB.CONTINUOUS, name="x")
    wa = m.addVars(time_periods, disr_arcs_2, lb=0.0, ub=GRB.INFINITY, vtype=GRB.BINARY, name="wa")
    Ia=m.addVars(time_periods,disr_arcs_2, lb=0.0, ub=GRB.INFINITY, vtype=GRB.BINARY, name="Ia")
    za=m.addVars(time_periods, disr_arcs_2, lb=0.0, ub=GRB.INFINITY, vtype=GRB.BINARY, name="za")
    wv = m.addVars(time_periods, disr_nodes, lb=0.0, ub=GRB.INFINITY, vtype=GRB.BINARY, name="wv")
    Iv=m.addVars(time_periods,disr_nodes, lb=0.0, ub=GRB.INFINITY, vtype=GRB.BINARY, name="Iv")
    zv=m.addVars(time_periods, disr_nodes, lb=0.0, ub=GRB.INFINITY, vtype=GRB.BINARY, name="zv")

    m.modelSense = GRB.MINIMIZE



    # 4.2 Optimisation model - Capacity constraints:
    # capacity constraints
    m.addConstrs(
        (quicksum(x[t,kl,arcs_all[a][0],arcs_all[a][1]] for kl in kl_set)<=H2.get_edge_data(*arcs_all[a])['capacity'] for t in time_periods for a in arcs_set), "c1")
    # no capacity at the arc if it is failed

    m.addConstrs(
        (quicksum(x[t,kl,arcs_both[a][0],arcs_both[a][1]]+x[t,kl,arcs_both[a][1],arcs_both[a][0]] for kl in kl_set)<=H2.get_edge_data(*arcs_both[a])['capacity'] for t in time_periods for a in arcs_both_set), "c1.2")
    # no capacity at the arc if it is failed

    m.addConstrs(
        (quicksum(x[t,kl,disr_arcs_2[a][0],disr_arcs_2[a][1]] for kl in kl_set)<=(1-wa[t,disr_arcs_2[a][0],disr_arcs_2[a][1]])*H2.get_edge_data(*disr_arcs_2[a])['capacity']
        for a in disr_arcs_2_set for t in time_periods), "c2.1")

    m.addConstrs(
        (quicksum(x[t,kl,a[0],a[1]] for kl in kl_set)<=(1-wv[t,disr_nodes[v]])*H2.get_edge_data(*a)['capacity']
        for v in disr_nodes_set for a in [edge for edge in H2.out_edges(disr_nodes[v]) if edge in arcs_all]+[edge for edge in H2.in_edges(disr_nodes[v]) if edge in arcs_all] for t in time_periods), "c2.1v")
    #print("current time steps is: ",current_time_step)
    m.addConstrs(
        (quicksum(x[t-current_time_step,kl,a[0],a[1]] for kl in kl_set)*maint_in_progress[v,t]==0
        for v in range(0,n) for a in [edge for edge in H2.out_edges(v) if edge in arcs_all]+[edge for edge in H2.in_edges(v) if edge in arcs_all] for t in range(current_time_step, current_time_step+T)), "c_maint_in_progress")

    # demand
    m.addConstrs(
        (quicksum(x[t,kl,a[0],a[1]] for a in [edge for edge in H2.in_edges(v) if edge in arcs_all])<=d[t][kl]
        for t in time_periods for kl in kl_set for v in nodes), "c30")

    if current_time_step==10:
        m.addConstrs(
            (quicksum(x[t,kl,a[0],a[1]] for a in [edge for edge in H2.out_edges(sources[kl]) if edge in arcs_all])==d[t][kl] 
            for t in time_periods for kl in kl_set), "c3")
    # flow conservation
    m.addConstrs(
        (quicksum(x[t,kl,a[0],a[1]] for a in [edge for edge in H2.in_edges(v) if edge in arcs_all])==quicksum(x[t,kl,a[0],a[1]] for a in [edge for edge in H2.out_edges(v) if edge in arcs_all])
        for t in time_periods for kl in kl_set for v in [v for v in nodes if ((v!=sources[kl]) & (v!=sinks[kl]))]), "c4")


    #m.addConstrs(
        #(quicksum(x[t,kl,a[0],a[1]] for a in H2.out_edges(sinks[kl]))==0
        #for t in time_periods for kl in kl_set), "c5")

    m.addConstrs(
        (quicksum(x[t,kl,a[0],a[1]] for a in arcs_all_no_arcs[kl])==0
        for t in time_periods for kl in kl_set), "c6")

    m.addConstrs(
        (Ia[t,disr_arcs[a][0],disr_arcs[a][1]]==quicksum(za[s,disr_arcs_2[a][0],disr_arcs_2[a][1]] for s in range(t+1))
        for a in disr_arcs_2_set for t in time_periods), "c7")

    m.addConstrs(
        (Iv[t,disr_nodes[v]]==quicksum(zv[s,disr_nodes[v]] for s in range(t+1))
        for v in disr_nodes_set for t in time_periods), "c7v")

    m.addConstrs(
        ((quicksum(wa[t,disr_arcs_2[a][0],disr_arcs_2[a][1]] for t in time_periods)*d_step-t_pre_a[a])*Ia[T-1,disr_arcs[a][0],disr_arcs[a][1]]==0
        for a in disr_arcs_2_set), "c8")

     #m.addConstrs(
        # ((quicksum(wv[t,disr_nodes[v]] for t in time_periods)*d_step-t_pre_v[v])*Iv[T-1,disr_nodes[v]]==0
        # for v in disr_nodes_set), "c8v")
    m.addConstrs(
        ((quicksum(wv[s,disr_nodes[v]] for s in time_periods)*d_step-t_pre_v[v])*zv[t,disr_nodes[v]]==0 for v in disr_nodes_set for t in range(0,(T-t_pre_v[v]+1))), "c8v1")

    m.addConstrs(
        ((quicksum(wv[s,disr_nodes[v]] for s in time_periods)*d_step-(T-t))*zv[t,disr_nodes[v]]==0 for v in disr_nodes_set for t in range((T-t_pre_v[v]+1),T)), "c8v2")


    m.addConstrs(
        (quicksum(za[t,disr_arcs_2[a][0],disr_arcs_2[a][1]] for t in time_periods)<=1
        for a in disr_arcs_2_set), "c9")

    m.addConstrs(
        (quicksum(zv[t,disr_nodes[v]] for t in time_periods)<=1
        for v in disr_nodes_set), "c9v")

    m.addConstrs(
        (za[t,disr_arcs_2[a][0],disr_arcs_2[a][1]]>=wa[t,disr_arcs_2[a][0],disr_arcs_2[a][1]]-wa[t-1,disr_arcs_2[a][0],disr_arcs_2[a][1]]
        for a in disr_arcs_2_set for t in time_periods[1:]), "c10")

    m.addConstrs(
        (zv[t,disr_nodes[v]]>=wv[t,disr_nodes[v]]-wv[t-1,disr_nodes[v]]
        for v in disr_nodes_set for t in time_periods[1:]), "c10v")

    m.addConstrs(
        (za[time_periods[0],disr_arcs_2[a][0],disr_arcs_2[a][1]]>=wa[time_periods[0],disr_arcs_2[a][0],disr_arcs_2[a][1]]
        for a in disr_arcs_2_set), "c11")

    m.addConstrs(
        (zv[time_periods[0],disr_nodes[v]]>=wv[time_periods[0],disr_nodes[v]] for v in disr_nodes_set), "c11v")

    #m.addConstr(
       # (zv[3,8]==1), "c12")


    w_penalty=0.5
    #bar_x=[[[0 for a in arcs_set] for kl in kl_set] for t in time_periods]
    if current_time_step==10:
        obj0=0
    else:
        obj0=0
        for t in time_periods:
            for a in arcs_set:
                for kl in kl_set:
                    if original_routes[kl,arcs_all[a][0]]==arcs_all[a][1]:
                        obj0=obj0+1-x[t,kl,arcs_all[a][0],arcs_all[a][1]]/400
                    else:
                        obj0=obj0+x[t,kl,arcs_all[a][0],arcs_all[a][1]]/400


    w_penalty=0.05
    w_lost=1
    w_pred=0.05
    w_reac=1000
    w_demand=0.05


    obj_reac_main=0
    for v in disr_nodes_set:
        if bar_t[v]<10:
            obj_reac_main=obj_reac_main+w_reac*C_rea_v[v]*(1-Iv[min(bar_t[v],T-1),disr_nodes[v]])/(bar_t[v]-prev_main_v[v])
    
    #4.3 Optiisation - Objective function:
    m.setObjective(w_pred*obj0
                    +w_penalty*(quicksum(H2.get_edge_data(*arcs_all[a])['weight']*x[t,kl,arcs_all[a][0],arcs_all[a][1]]/400 for t in time_periods for a in arcs_set for kl in kl_set))
                    #w_penalty*(quicksum(H2.get_edge_data(*arcs_all[a])['weight']*x[T-1,kl,arcs_all[a][0],arcs_all[a][1]]*Pred_main_time  for a in arcs_set for kl in kl_set)-3058+1098)
                    #+w_penalty*(quicksum(H2.get_edge_data(*arcs_all[a])['weight']*x[t,kl,arcs_all[a][0],arcs_all[a][1]] for t in time_periods for a in arcs_set for kl in kl_set)-1960)
                   # + quicksum(w_pred*za[t,disr_arcs_2[a][0],disr_arcs_2[a][1]]*C_pre_a[a]/(t-prev_main_a[a]) for a in disr_arcs_2_set for t in time_periods)
                   # + quicksum(p_a[a,t]*(1-Ia[t,disr_arcs_2[a][0],disr_arcs_2[a][1]])*(C_rea_a[a]+w_lost*quicksum(x[s,kl,arcs_all[a][0],arcs_all[a][1]] for s in [s_t for s_t in range(t,t+t_rea_a[a]) if s_t <T] for kl in kl_set)) for a in disr_arcs_2_set for t in time_periods)
                    + quicksum(w_pred*zv[t,disr_nodes[v]]*C_pre_v[v]/(t-prev_main_v[v]) for v in disr_nodes_set for t in time_periods)
                   # + quicksum(p_v[v][t]*(1-Iv[t,disr_nodes[v]])*(C_rea_v[v]+w_lost*quicksum(x[s,kl,a[0],a[1]] for s in [s_t for s_t in range(t,t+t_rea_v[v]) if s_t <T] for kl in kl_set for a in [edge for edge in H2.in_edges(disr_nodes[v]) or H2.out_edges(disr_nodes[v]) if edge in arcs_all])) for v in disr_nodes_set for t in time_periods))
                   # + quicksum(w_pred*zv[t,disr_nodes[v]]*C_pre_v[v]/(t-prev_main_v[v]) for v in disr_nodes_set for t in time_periods)
                   # + quicksum(p_v[v][t]*(1-Iv[t,disr_nodes[v]])*w_lost*x[t,kl,a[0],a[1]]*t_rea_v[v] for kl in kl_set  for v in disr_nodes_set for t in time_periods for a in [edge for edge in H2.in_edges(disr_nodes[v]) or H2.out_edges(disr_nodes[v]) if edge in arcs_all])
                   # + quicksum(p_v[v][t]*(1-Iv[t,disr_nodes[v]])*C_rea_v[v]*Iv[T-1,disr_nodes[v]] for v in disr_nodes_set for t in time_periods)
                    #+ quicksum(w_reac*C_rea_v[v]*(1-Iv[bar_t[v],disr_nodes[v]])/(bar_t[v]-prev_main_v[v]) for v in disr_nodes_set))
                    +w_demand*quicksum(400-(quicksum(x[t,kl,a[0],a[1]]  for a in [edge for edge in H2.in_edges(sinks[kl])])) for kl in kl_set for t in time_periods)
                    +obj_reac_main)
                    #+ quicksum(w_reac*C_rea_v[v]*(1-Iv[min(bar_t[v],T-1),disr_nodes[v]])/(bar_t[v]-prev_main_v[v]) for v in disr_nodes_set))

    #Optimality Gap
    m.setParam('MIPGap', 0)
    # Solve optimisation problem
    m.optimize()

    # 5. Output:
    maintenance_plan_vector=np.squeeze(np.ones((n,1)))
    maintenance_plan_vector=-maintenance_plan_vector
    for v in disr_nodes_set:
        maint_time=-1
        for t in time_periods:
            if zv[t,disr_nodes[v]].x==1 and t<10:
                maint_time=t
                if t+t_pre_v[v]>10 and t<10:
                    maint_in_progress[disr_nodes[v],current_time_step+10:current_time_step+10+t_pre_v[v]-(10-t)]=1
        maintenance_plan_vector[disr_nodes[v]]=maint_time
    #print(quicksum(p_v[v][t]*(1-Iv[t,disr_nodes[v]].x)*C_rea_v[v] for v in disr_nodes_set for t in time_periods))
    #print(maint_in_progress[8,60:70])
    if current_time_step==10:
        original_routes=np.squeeze(np.zeros((len(kl_set),n)))
    Routes=np.squeeze(np.zeros((len(kl_set),n+2)))
    #print(Routes)
    current_routes=np.squeeze(np.zeros((len(kl_set),n)))
    #Routes = np.array(([]))
    for t in time_periods:
        #print(t)
        arcs_sol=[]
        arcs_sol_2=[]
        arcs_sol_2_reverse=[]
        for kl in kl_set:
            arcs_sol_kl=[]
            for a in arcs_set:
                if x[t,kl,arcs_all[a][0],arcs_all[a][1]].x>0:
                    arcs_sol_kl.append((arcs_all[a][0],arcs_all[a][1]))
                    arcs_sol.append((arcs_all[a][0],arcs_all[a][1]))
            arcs_sol_2.append(arcs_sol_kl)
            arcs_sol_2_reverse.append([arc[::-1] for arc in arcs_sol_kl])
            
            routes = []
            startRoutes = list(filter(lambda elem: elem[0]==sources[kl], arcs_sol_kl))
            for i in range(len(startRoutes)):
                tempList = []
                currentTuple = startRoutes [i]
                tempList.append(currentTuple[0])
                tempList.append(currentTuple[1])
                while True:
                    if currentTuple[1]==sinks[kl]:
                        break
                    else:
                        nextTuple = findTuple(currentTuple[1])
                        currentTuple = nextTuple
                        tempList.append(currentTuple[1])
                routes.append(tempList)
            flow=[]
            for i in range(len(routes)):
                min_flow=min(x[t,kl,routes[i][j],routes[i][j+1]].x for j in range(len(routes[i])-1))
                flow.append(int(min_flow))
            #print(t,sources[kl],sinks[kl],routes,flow)
            vect=np.squeeze(np.ones((n,1)))
            vect=-vect
            for i in range(len(routes)):
                for j in range(len(routes[i])-1):
                    vect[routes[i][j]]=routes[i][j+1]
            if t==0:
                Routes[kl,0]=0
                Routes[kl,1]=kl
                Routes[kl,2:n+2]=vect
                current_routes[kl,:]=vect
                if current_time_step==10:
                    original_routes[kl,:]=vect
            elif t<10:
                if (np.not_equal(vect,current_routes[kl,:])).any():
                    #s=len(Routes)
                    vect_2=np.squeeze(np.zeros((n+2,1)))
                    vect_2[2:n+2]=vect
                    vect_2[1]=kl
                    vect_2[0]=t-4
                    if (t-4)<=0:
                        #print("kl==>",kl,"<==")
                        #print(" n==>",n,"<==")
                        #print(" vect==>",vect,"<==")
                        #print(Routes)
                        #print(Routes[kl,2:n+2])
                        Routes[kl,2:n+2]=vect
                    else:
                    #if (np.not_equal(vect,original_routes[kl,:])).any():
                    #    vect_2[0]=t
                   # else:
                       # vect_2[0]=t
                        Routes=np.append(Routes,vect_2)
                    current_routes[kl,:]=vect
    #print(Routes)
    #print(obj1)
    #print(quicksum(zv[t,disr_nodes[v]].x*C_pre_v[v]/(t-prev_main_v[v]) for v in disr_nodes_set for t in time_periods))
    #print(quicksum(p_v[v][t]*(1-Iv[t,disr_nodes[v]].x)*w_lost*x[t,kl,a[0],a[1]].x*t_rea_v[v] for kl in kl_set   for t in time_periods for v in disr_nodes_set for a in [edge for edge in H2.in_edges(disr_nodes[v]) or H2.out_edges(disr_nodes[v]) if edge in arcs_all]))
    #print(quicksum(C_rea_v[v]*(1-Iv[T-1,disr_nodes[v]].x)/(bar_t[v]+8-prev_main_v[v]) for v in disr_nodes_set))


    #print(disr_nodes)
    #print(maint_in_progress[:,current_time_step])
    #print("bart",bar_t)
    return maintenance_plan_vector, Routes