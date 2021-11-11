# NAssets.jl (Networked Assets)

A Julia library for the simulation of networked assets from a multi-model perspective. Models currently supported are:

* **Asset Network Model** : Different off-the-shelf network topologies for asset connectivity. Integration with [Julia Graphs](https://juliagraphs.org/) ecosystem for functions generating random topologies plus ability to define own topologies passing the adjacency matrix as a csv file.

* **Agent Network Model**: NAssets.jl assumes agents are controlling the Asset Network. Agent-based model is built on top of [Agents.jl](https://juliadynamics.github.io/Agents.jl/stable/). Different off-the-shelf network topologies for agent network interaction are provided. Integration with Julia Graphs ecosystem for functions generating random topologies plus ability to define own topologies passing the adjacency matrix in a csv file.

* **Network Protocol Model**: NAssets are also Network Elements able to route data packets across the network. NAssets provide a minimal implementation of flow tables and control actions inspired by [OpenFlow](https://en.wikipedia.org/wiki/OpenFlow#:~:text=OpenFlow%20is%20a%20communications%20protocol,or%20router%20over%20the%20network.) protocol.

* **Physical Model**: NAssets deteriorate along the time following a given deterioration function. Initially a simple linear function is used but other functions can be implemented and plugged into the model.

* **Maintenance Model**: Different maintenance strategies can be defined for the NAssets. For example, corrective and preventive.

* **Events Model**: NAssets support scheduling of events for example starting a maintenance activity or randomly simulate failures in the network of assets. 

* **Geographical Model**: NAssets are able to store geo-references. Initially simple coordinates are supported and used in plots and animations.

Models are defined in functions following the structure explained [here](structure.md).


# Running

1. Define a configuration file with the parameters required in the simulation. An example is found in: ``examples/configs.config.csv``

2. A minimal example of a script for running the simulation based on the config file defined previously is: ``src/run_sim.jl``

# Use Cases

* NAssets.jl can be used to simulate complex scenarios of traffic re-routing and network maintenance in digital network infrastructures. See for example [Integrating Asset Management and Traffic Engineering](https://www.youtube.com/watch?v=MDatb4EII7k)


# Credits / Acknowledgement 


NAssets.jl was developed in the [Asset Management Group](https://www.ifm.eng.cam.ac.uk/research/asset-management/) of the [DIAL Laboratory](https://www.ifm.eng.cam.ac.uk/research/dial/) of the University of Cambridge. Initial development took place in the context of the [NG-CDI](https://www.ng-cdi.org/) programme funded by [BT](https://www.bt.com/) and [EPSRC](https://epsrc.ukri.org/).



# TODO

NAssets.jl is still Work-In-Progress:

* Improve documentation
* Generate Julia package
* ...

# Packages used by NAssets.jl

* [Agents]()
* [MetaGraphs]()
* [AgentsPlots]()
* [Plots]()
* [LightGraphs]()
* [SimpleWeightedGraphs]()
* [GraphPlot]()
* [GraphRecipes]()
* [NetworkLayout]()
* [Tables]()
* [DataFrames]()
* [CSV]()
* [JSON]()
* [Serialization]()
* [DelimitedFiles]()
* [BritishNationalGrid]()
* [ZipFile]()
* [Shapefile]()
* [Random]()
* [Match]()
* [LinearAlgebra]()
* [StatsBase]()
* [Distributions]()
* [StatsPlots]()
* [SparseArrays]()
* [Laplacians]()
* [DataStructures]()
* [RollingFunctions]()
* [BenchmarkTools]()
* [Statistics]()
* [Logging]()
* [LoggingExtras]()
* [LoggingFacilities]()
* [Dates]()
* [TimeZones]()
* [PyCall]()