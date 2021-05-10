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

include("netManAbm.jl")

data_dir = "data/"
plots_dir = "plots/runs2/"
BenchmarkTools.DEFAULT_PARAMETERS.samples = 100

configs = load_run_configs()

for config in configs
    single_run(config)
end