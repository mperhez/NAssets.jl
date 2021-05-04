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
using BenchmarkTools
using Serialization
using Statistics

include("netManAbm.jl")

new_config(seed,ctl_model,size,n_steps,drop_proportion,benchmark, animation) =
    return ( seed = seed
            ,ctl_model=ctl_model
            ,size=size
            ,n_steps=n_steps
            ,drop_proportion=drop_proportion
            ,benchmark = benchmark
            ,animation = animation
            )

function get_dropping_nodes(drop_proportion)
    #TODO calcualte according to proportion
    return Dict(80=>[3],120=>[2]) # drop time => drop node
end

function load_run_configs() 
    configs = []
    for ctl_model in [ControlModel(1)]#,ControlModel(2) ] #instances(ControlModel)
        for size in [10]
            for drop_proportion in [10]
                for seed in [123]
                    push!(configs,new_config(seed,ctl_model,size,200,drop_proportion,false,false))
                end
            end
        end
    end
    return configs
end

function single_run(config)
    Random.seed!(config.seed)
    args = Dict()
    params = Dict()
    args[:N]=config.n_steps
    args[:Τ]=config.size
    args[:ΔΦ]=1
    ntw_graph = load_network_graph(config.seed,config.size)
    args[:ntw_graph]=ntw_graph
    args[:dropping_nodes]= get_dropping_nodes(config.drop_proportion)
    args[:ctrl_model] = config.ctl_model
    args[:seed] = config.seed
    args[:benchmark] = config.benchmark
    args[:animation] = config.animation

    q_ctl_agents = 0

    if config.ctl_model == ControlModel(1)
        args[:ctl_graph] = MetaGraph()
        q_ctl_agents = 1
    else
        ctl_graph = load_control_graph(config.ctl_model,nv(ntw_graph),config.seed)
        args[:ctl_graph]=ctl_graph
        q_ctl_agents = nv(ctl_graph)
    end

    q_agents = nv(ntw_graph)+q_ctl_agents
    args[:q]=q_agents

    adata = [get_state_trj,get_condition_ts, get_rul_ts]
    mdata = [:mapping_ctl_ntw,get_state_trj]
    result_agents,result_model = run_model(config.n_steps,args,params; agent_data = adata, model_data = mdata)
    println("End running model...")
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

    open(data_dir*"runs/$(config.ctl_model)/"*"$(config.size)_$(config.seed)_condition_agents.csv", "w") do io
        for i=1:nv(ntw_graph)
            writedlm(io,hcat([i 1; i 2 ; i 3] , ags_condition[i]),';')
        end
    end;


    open(data_dir*"runs/$(config.ctl_model)/"*"$(config.size)_$(config.seed)_rul_agents.csv", "w") do io
    #     #for i=1:nv(ntw_graph)
            writedlm(io,ags_rul[1:10],';')
    #     #end
    end;

    model_data = last(result_model)["get_state_trj"]
    model_data = [ (m.tick,m.links_load) for m in model_data ]

    #ags_1 = [ split(string(i-1)*";"*replace(to_string(ags[j][i]),"NetworkAssetState(" => ""),";") for j=1:length(ags)] for i=1:length(ags[j]) ]
    open(data_dir*"runs/$(config.ctl_model)/"*"$(config.size)_$(config.seed)_steps_agents.csv", "w") do io
        # writedlm(io, ["tick;id;port-edge;count1;count2;count3;flowtable"], ';')
        writedlm(io,ags_1,';') 
    end;

    open(data_dir*"runs/$(config.ctl_model)/"*"$(config.size)_$(config.seed)_steps_model.csv", "w") do io
        writedlm(io,model_data,';') 
    end;

end

data_dir = "data/"
plots_dir = "plots/runs/"
BenchmarkTools.DEFAULT_PARAMETERS.samples = 100

configs = load_run_configs()

for config in configs
    single_run(config)
end