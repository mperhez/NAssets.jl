using Agents, AgentsPlots, Plots#, LightGraphs, SimpleWeightedGraphs, GraphPlot
using CSV
using DataFrames
using Random
using Match

include("selforgAbm.jl")

dir = ""

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

CSV.write("steps.csv",result)

## bar plot

# res_g = groupby(result,:step)
# ons = []
# for g in res_g
#     push!(ons,count(v->v.color == :white,eachrow(g)))
# end

#bar(ons,ylims=(0,nv(params[:phase])),m='o')


# whites(v) = v["color"] .== "white" ? 1 : 0
# colors_steps = [ (v.step,whites(v)) for v in eachrow(result) ]
# print(colors_steps)


#count(whites,eachrow(result))


##
# comment

# A = [
#     0 1 1
#     0 0 1
#     0 0 0
#     ]
#
# sources = [1,2,1,1,4]
# destinations = [2,3,3,4,3]
# weights = [0.5,0.8,1.0,0.2,0.7]
#
# swg = SimpleWeightedGraph(sources,destinations,weights)
# nodelabel = 1:nv(swg)
# gplot(swg,nodelabel=nodelabel)
