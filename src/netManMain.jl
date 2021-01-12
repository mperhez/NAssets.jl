using Agents, AgentsPlots, Plots#, LightGraphs, SimpleWeightedGraphs, GraphPlot
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

n = 10
args[:q]=10
args[:Τ]=10
args[:ΔΦ]=1
# params[:graph] = swg
#adata = [:phase,:color]
adata = [:pos]
anim,result = run_model(n,args,params; agent_data = adata)

CSV.write(data_dir*"exp_raw/"*"steps.csv",result)