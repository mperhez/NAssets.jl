#Core structures
include("core/core_structs.jl")
#graph-related
include("core/graph_functions.jl")

#various util functions
include("utils/util_functions.jl")
#logging
include("utils/logging_functions.jl")
#Plotting functions
include("utils/plotting_functions.jl")
# time-to-event functions
include("utils/tte_functions.jl")

#maintenance model
include("phy/maintenance_model.jl")

include("ntw/of_switch.jl")
include("ntw/of_control.jl")
include("ctl/agent_control.jl")

include("phy/physical_model.jl")

include("ntw/network_model.jl")
include("phy/geo_model.jl")

#Main Functions
include("model/netManFunctions.jl")

#Agents.jl function implementation for this model
include("model/netManModel.jl")

#Basic queries
#include("model/queries_basic.jl")
#Multiple queries
include("ctl/queries_multiple.jl")

#end # module
