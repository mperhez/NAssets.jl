using Agents, AgentsPlots, Plots, LightGraphs, MetaGraphs, SimpleWeightedGraphs, GraphPlot, GraphRecipes
using StructTypes, Tables, DataFrames
using CSV, JSON, JSON3, JSONTables, Serialization, DelimitedFiles
using Random
using Match
using LinearAlgebra
using StatsBase
using Distributions
using StatsPlots
using SparseArrays
using Laplacians
using DataStructures
using RollingFunctions
using BenchmarkTools
using Statistics
using Memento
using Dates,TimeZones

include("netManAbm.jl")
loggers = Dict()

function single_run_with_logging(config)
    run_label = "$(config.ctl_model)_$(config.size)_$(config.seed)"
    # io = open( data_dir * run_label * "_log.txt", "w+")
    # logger = SimpleLogger(io,Logging.Debug)
    # with_logger(logger) do
        # @info("start run $run_label")
        # single_run(config)
        # @info("end run $run_label")
    # end
    # flush(io)
    # close(io)
    start_time = now()
    log_info("$start_time: start $run_label")
    single_run(config)
    end_time = now()
    log_info("$end_time: end $run_label. Elapsed: $((end_time - start_time))")
end

data_dir = "data/"
plots_dir = "plots/runs2/"
BenchmarkTools.DEFAULT_PARAMETERS.samples = 100

configs = load_run_configs()

for config in configs
    single_run_with_logging(config)
end

