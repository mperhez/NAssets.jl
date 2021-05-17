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
using Logging, LoggingExtras #,Memento
using Dates,TimeZones

include("netManAbm.jl")
loggers = Dict()

function single_run_with_logging(config)
    
    run_label = "$(config.ctl_model)_$(config.size)_$(config.seed)"
    
    #Memento.jl config
    # Memento.reset!()
    # logger = getlogger(@__MODULE__)
    # push!(logger, DefaultHandler(data_dir *  run_label * ".log"))
    # logger = Memento.config!(logger,"info"; fmt="[{date} |{level}|{msg}", substitute=true)
    # delete!(logger.handlers,"console")
    # println(keys(logger.handlers))


    #io = open( data_dir * run_label * "_log.log", "w+")
    # logger = SimpleLogger(io,Logging.Debug)

    # logger = FormatLogger() do io, args
    #     println(io, args._module, " | ", "[", args.level, "] ", args.message)
    # end;
    logger = MinLevelLogger(FileLogger(run_label* "_testing.log"), Logging.Info)

    with_logger(logger) do
        start_time = now()
        log_info("$start_time: start $run_label")
        single_run(config)
        end_time = now()
        log_info("$end_time: end $run_label. Elapsed: $((end_time - start_time))")
    end
    #flush(io)
    #close(io)
    
    
    # return logger
end

data_dir = "data/"
plots_dir = "plots/runs2/"
BenchmarkTools.DEFAULT_PARAMETERS.samples = 100
configs = load_run_configs()


Threads.@threads for config in configs
    single_run_with_logging(config)
end

