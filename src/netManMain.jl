using Agents, AgentsPlots, Plots, LightGraphs, SimpleWeightedGraphs, GraphPlot, GraphRecipes
using CSV
using DataFrames
using Random
using Match


include("netManAbm.jl")

data_dir = "data/"
plots_dir = "plots/"

# exps = Dict()
args = Dict()
params = Dict()


ntw_graph = load_network_graph()
ctl_graph = load_control_graph()

n = 10
args[:q]=10
args[:Τ]=10
args[:ΔΦ]=1
args[:ntw_graph]=ntw_graph
args[:ctl_graph]=ctl_graph
# params[:graph] = swg
#adata = [:phase,:color]
adata = [:pos,in_pkt_trj,out_pkt_trj]
mdata = [:mapping]
anim,result_agents,result_model = run_model(n,args,params; agent_data = adata, model_data = mdata)

CSV.write(data_dir*"exp_raw/"*"steps_agents.csv",result_agents)
CSV.write(data_dir*"exp_raw/"*"steps_model.csv",result_model)