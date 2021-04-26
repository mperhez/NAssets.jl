using Agents, AgentsPlots, Plots, LightGraphs, MetaGraphs, SimpleWeightedGraphs, GraphPlot, GraphRecipes
using CSV
using DataFrames
using Random
using Match
using LinearAlgebra
using StatsBase
using Distributions
using StatsPlots
using SparseArrays
using DelimitedFiles
using Laplacians
using DataStructures
using RollingFunctions

include("netManAbm.jl")

data_dir = "data/"
plots_dir = "plots/"


ctl_model = ControlModel(4)
# exps = Dict()
args = Dict()
params = Dict()

n = 200
args[:N]=n
args[:Τ]=10
args[:ΔΦ]=1
ntw_graph = load_network_graph()
args[:ntw_graph]=ntw_graph
args[:dropping_nodes]=Dict(80=>[3],120=>[2]) # drop time => drop node
# params[:graph] = swg               
#adata = [:phase,:color]
args[:ctrl_model] = ctl_model

q_ctl_agents = 0

if ctl_model == ControlModel(1)
    args[:ctl_graph] = MetaGraph()
    q_ctl_agents = 1
else
    ctl_graph = load_control_graph(ctl_model,nv(ntw_graph))
    args[:ctl_graph]=ctl_graph
    q_ctl_agents = nv(ctl_graph)
end

q_agents = nv(ntw_graph)+q_ctl_agents
args[:q]=q_agents

adata = [get_state_trj,get_condition_ts, get_rul_ts]
mdata = [:mapping_ctl_ntw,get_state_trj]
anim,result_agents,result_model = run_model(n,args,params; agent_data = adata, model_data = mdata)
println("finished run model...")
ags = last(result_agents,q_agents)["get_state_trj"]
ags_1 = vcat([ [ split(string(j-1)*";"*replace(to_string(ags[i][j]),"NetworkAssetState(" => ""),";") for j=1:length(ags[i])] for i=1:length(ags) ]...)

ags_condition = last(result_agents,q_agents)["get_condition_ts"]
ags_rul = last(result_agents,q_agents)["get_rul_ts"]

# println(ags_condition)

    # for i=1:size(ags_condition,1)#nv(ntw_graph)
    #     println("testing $i ...")
    #     println(ags_condition[i])
    #     #println(hcat([i 1; i 2 ; i 3] , ags_condition[i]),';')
    # end

open(data_dir*"exp_raw/"*"condition_agents.csv", "w") do io
    for i=1:nv(ntw_graph)
        writedlm(io,hcat([i 1; i 2 ; i 3] , ags_condition[i]),';')
    end
end;


 open(data_dir*"exp_raw/"*"rul_agents.csv", "w") do io
#     #for i=1:nv(ntw_graph)
         writedlm(io,ags_rul[1:10],';')
#     #end
 end;

model_data = last(result_model)["get_state_trj"]
model_data = [ (m.tick,m.links_load) for m in model_data ]

#ags_1 = [ split(string(i-1)*";"*replace(to_string(ags[j][i]),"NetworkAssetState(" => ""),";") for j=1:length(ags)] for i=1:length(ags[j]) ]
open(data_dir*"exp_raw/"*"steps_agents.csv", "w") do io
    # writedlm(io, ["tick;id;port-edge;count1;count2;count3;flowtable"], ';')
    writedlm(io,ags_1,';') 
end;

open(data_dir*"exp_raw/"*"steps_model.csv", "w") do io
    writedlm(io,model_data,';') 
end;


#print(ags[7][end])




#CSV.write(data_dir*"exp_raw/"*"steps_agents.csv",ags)
#CSV.write(data_dir*"exp_raw/"*"steps_model.csv",result_model)




 
# for  i=1:size(ags,1)
#     r[!,i]
# end
#print(ags)


# p = plot(title="Data Traffic")
# for i=1:size(ags,1)
#     plot!(p,ags[:statistics][i])
# end


# df_stats = DataFrame(tick=Int[],ne_id=Int[],throughput_in=Float64[])
# for  i=1:size(ags,1)
#     for r in ags[i,:statistics]
#         push!(df_stats,(r.tick,r.ne_id,r.throughput_in))
#     end
#     #push!(df_stats, ags[i,:statistics].ticks,ags[i,:statistics].ne_id,ags[i,:statistics].throughput_in)
# end

# @df df_stats plot(:tick,:throughput_in,group=:ne_id,m=".")
# png("tpt_plot.png")


#
# t1 = [10, 19, 11, 8, 9, 7, 9, 10, 7, 10, 11, 11, 9, 10, 10, 10, 10, 9, 8, 10, 11]
# t2 = [19, 11, 8, 9, 7, 9, 10, 7, 10, 11, 11, 9, 10, 10, 10, 10, 9, 8, 10]
# t3 = [19, 30, 8, 9, 7, 9, 10, 7, 10, 11, 11, 9, 10, 10, 10, 10, 9, 8]

#  p1 = t1[5] - t1[1] / 4
# p2 = t1[10] - t1[5] / 4
# p3 = t1[15] - t1[10] / 4
# p3 = t1[20] - t1[15] / 4

#6.5, 7.75, 7.5, 7.5