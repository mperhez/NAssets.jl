using Agents, AgentsPlots, Plots, LightGraphs, SimpleWeightedGraphs, GraphPlot, GraphRecipes
using CSV
using DataFrames
using Random
using Match
using LinearAlgebra
using StatsBase
using Distributions
using StatsPlots

include("netManAbm.jl")

data_dir = "data/"
plots_dir = "plots/"

# exps = Dict()
args = Dict()
params = Dict()


ntw_graph = load_network_graph()
ctl_graph = load_control_graph()
q_agents = nv(ntw_graph)+nv(ctl_graph)

n = 120
args[:q]=q_agents
args[:Τ]=10
args[:ΔΦ]=1
args[:ntw_graph]=ntw_graph
args[:ctl_graph]=ctl_graph
# params[:graph] = swg               
#adata = [:phase,:color]
adata = [:pos,in_pkt_trj,out_pkt_trj,flow_table,statistics]
mdata = [:mapping]
anim,result_agents,result_model = run_model(n,args,params; agent_data = adata, model_data = mdata)

CSV.write(data_dir*"exp_raw/"*"steps_agents.csv",result_agents)
CSV.write(data_dir*"exp_raw/"*"steps_model.csv",result_model)



ags = last(result_agents,q_agents)
 
# for  i=1:size(ags,1)
#     r[!,i]
# end



# p = plot(title="Data Traffic")
# for i=1:size(ags,1)
#     plot!(p,ags[:statistics][i])
# end


df_stats = DataFrame(tick=Int[],ne_id=Int[],throughput_in=Float64[])
for  i=1:size(ags,1)
    for r in ags[i,:statistics]
        push!(df_stats,(r.tick,r.ne_id,r.throughput_in))
    end
    #push!(df_stats, ags[i,:statistics].ticks,ags[i,:statistics].ne_id,ags[i,:statistics].throughput_in)
end

@df df_stats plot(:tick,:throughput_in,group=:ne_id,m=".")
png("tpt_plot.png")


#
# t1 = [10, 19, 11, 8, 9, 7, 9, 10, 7, 10, 11, 11, 9, 10, 10, 10, 10, 9, 8, 10, 11]
# t2 = [19, 11, 8, 9, 7, 9, 10, 7, 10, 11, 11, 9, 10, 10, 10, 10, 9, 8, 10]
# t3 = [19, 30, 8, 9, 7, 9, 10, 7, 10, 11, 11, 9, 10, 10, 10, 10, 9, 8]

#  p1 = t1[5] - t1[1] / 4
# p2 = t1[10] - t1[5] / 4
# p3 = t1[15] - t1[10] / 4
# p3 = t1[20] - t1[15] / 4

#6.5, 7.75, 7.5, 7.5