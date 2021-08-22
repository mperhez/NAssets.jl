using Agents: vertices
using MetaGraphs: add_vertex!, has_edge
using Agents, AgentsPlots, Plots, LightGraphs, MetaGraphs, SimpleWeightedGraphs, GraphPlot, GraphRecipes, NetworkLayout
using Tables, DataFrames
using CSV, JSON, Serialization, DelimitedFiles
using BritishNationalGrid
using ZipFile, Shapefile
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
using Logging,LoggingExtras, LoggingFacilities
using Dates,TimeZones
using PyCall

script_dir = pwd() * "/src/pyopt/" #@__DIR__ 
pushfirst!(PyVector(pyimport("sys")."path"), script_dir)
opt_init = pyimport("optimisation_initialisation")
opt_run = pyimport("maintenance_planning")
np = pyimport("numpy")

csv_custom_nodes = "/home/mep53/workspace/data/bt/metro-access/"*"nodes_t2_t3_150618_CutA.csv"
csv_custom_links = "/home/mep53/workspace/data/bt/metro-access/"*"New21CNCoreTopology.csv"
shp_geo_uk = "/home/mep53/workspace/uk/geo/"*"NUTS_UK_2018.shp"

include("netManAbm.jl")
loggers = Dict()

simplified_logger(logger) = TransformerLogger(logger) do log
    log.   
    merge(log, (; message = "$(log.message)"
    , file="", line="", _module=""
    ))
end

function single_run_with_logging(config)
    run_label = get_run_label(config)
    io = stdout
    logger = MessageOnlyLogger(io,Logging.Info)
    with_logger(logger) do
        start_time = now()
        log_info("$start_time: start $run_label")
        single_run(config)
        end_time = now()
        log_info("$end_time: end $run_label. Elapsed: $((end_time - start_time))")
    end
end

function single_run_with_file_logging(config)
    
    run_label = get_run_label(config)

    io = open( data_dir * run_label * "_log.log", "w+")
    # logger = SimpleLogger(io,Logging.Debug)

    # logger = FormatLogger() do io, args
    #     log_info(io, args._module, " | ", "[", args.level, "] ", args.message)
    # end;
    # logger = MinLevelLogger(FileLogger(run_label* "_testing.log"), Logging.Info) |> simplified_logger
    
    # logger = OneLineTransformerLogger(MinLevelLogger(FileLogger( data_dir * run_label* ".log"), Logging.Info)#|> OneLineTransformerLogger
    # logger = SimpleLogger(stdout, Logging.Debug) |> OneLineTransformerLogger
    logger = MessageOnlyLogger(io,Logging.Info)
    with_logger(logger) do
        start_time = now()
        log_info("$start_time: start $run_label")
        single_run(config)
        end_time = now()
        log_info("$end_time: end $run_label. Elapsed: $((end_time - start_time))")
    end
    flush(io)
    close(io)
end

data_dir = "data/"
plots_dir = "plots/"
BenchmarkTools.DEFAULT_PARAMETERS.samples = 100
configs = load_run_configs()
#Logging.disable_logging(Logging.Info)
#enable logs
Logging.disable_logging(Logging.BelowMinLevel)
Threads.@threads for config in configs
    single_run_with_logging(config)
    #single_run_with_file_logging(config)
end