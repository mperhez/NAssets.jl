export ϕ

@enum ControlModel CENTRALISED=1 DISTRIBUTED=2

function ϕ(t,T,pulse)
    α = 0.5
    Β = 0.5
    if isnothing(pulse)
        new_phase = t > 0 ? t - 1 : T  # phase function
    else
        new_phase = round(α * t + Β)
    end
end
"""
Agent emits pulse
"""
# function pulse(agent,model)
#     if(agent.phase == agent.T)
#         agent.color = :white
#
#         for n in agent.neighbors
#             na = first(filter(a->a.id == n,Set(allagents(model))))
#             push!(na.inbox,(agent.id, model.graph.weights[agent.id,na.id]))
#         end
#     else
#         agent.color = :black
#     end
# end

function update_neighbours(agent,model)
    neighbours = space_neighbors(agent,model,1)
    for n in neighbours
        ag_n = find_agent(n,model)
        push!(ag_n.inbox,agent.id)
    end
end

function pulse(agent,model)
    if(round(agent.phase,digits=2) == model.:Τ)
        agent.color = :white
        update_neighbours(agent,model)
        agent.phase = 0.0
    else
        agent.color = :blue
    end
end


"""
Agent processes pulses "observed"/"received" from neighbors
"""
function process_pulses(agent,model)
    if agent.phase < model.:Τ
        agent.phase = round(agent.phase + 0.1,digits=2)
    else
        agent.phase = round(agent.phase - model.:Τ,digits=2)
    end

    if !isempty(agent.inbox)
        if length(agent.inbox) > agent.maxN
            agent.phase = round(min(model.:Τ,agent.phase+model.:ΔΦ),digits=2)
            agent.maxN = length(agent.inbox)
        elseif length(agent.inbox) == agent.maxN &&
                maximum(agent.inbox) > agent.maxId
            agent.phase = round(min(model.:Τ,agent.phase+model.:ΔΦ),digits=2)
            agent.maxId = maximum(agent.inbox)
        end
    end
agent.inbox = []
end


function pulse_received(pulses,strategy)
    return if length(pulses) > 1
        @match strategy begin
        :NEAR  =>
                # This seems the most sensible, as all are received simoultaneosuly
                # intensity (greater distance less intensity)
                last(sort(pulses,by=x->x[2]))
        :MIXED =>
                #intensity and fraction of time step (distance * index)
                #TODO review: as intensity distance may need to be reversed and then multiplied
                # by index, then get the first.
                last(sort(pulses,by=x->findfirst(isequal(x),pulses)*x[2]))
        _     =>
                #FIFO
                first(pulses)
        end
    elseif isempty(pulses)
        Nothing
    else
        first(pulses)
    end
end

"""
Find agent in the model given the id
"""
function find_agent(id,model)
    first(filter(a->a.id == id,Set(allagents(model))))
end

"""
    load the graph of the network to control
"""

function load_network_graph()
    Random.seed!(123)
    #ntw = smallgraph("house")
    ntw = watts_strogatz(10,4,0.8)
    #gplot(ntw,layout=circular_layout,nodelabel=nodes(ntw))
    return ntw
end


"""
    load the graph of the control system
"""

function load_control_graph()
    Random.seed!(123)
    ntw = complete_graph(1)# watts_strogatz(25,4,0.8)
    #gplot(ntw,layout=circular_layout,nodelabel=nodes(ntw))
    return ntw
end

function plotabm_networks_multi(
    model;
    kwargs...,
)

    nsize = 0.13
    lwidth = 0.5

    l = @layout [a{1w};b]
    ntw_p = graphplot(
        model.ntw_graph
        ,names = [get_sne_id(i,model) for i=1:nv(model.ntw_graph)]
        , method = :circular
        ,size=(300,200)
        ,node_weights = [ get_sne_id(i,model) > 9 ? 1 : 10 for i in 1:nv(model.ntw_graph)]
        ,nodeshape = :hexagon
        ,nodecolor = [ is_up(getindex(model,get_sne_id(i,model))) ? :lightblue : :red for i in 1:nv(model.ntw_graph) ]
        ,markerstrokecolor = :dimgray
        ,edgecolor=:dimgray
        ,markerstrokewidth = 1.1
        ,node_size=nsize
        ,titlefontsize=1
        ,titlefontcolor=:white
    )
    
    annotate!((-0.4,0.75,Plots.text("Asset Network", 11, :black, :center)))

    ctl_p = graphplot(
        model.ctl_graph
        ,names = [ get_control_agent(i,model) for i in 1:nv(model.ctl_graph) ]
        , method = :circular
        ,size=(300,200)
        ,node_weights = [ i > 9 ? 1 : 1 for i in 1:nv(model.ctl_graph)]
        ,nodeshape = :circle
        ,nodecolor = [ getindex(model,get_control_agent(i,model)).state.color for i in 1:nv(model.ctl_graph) ]
        ,markerstrokecolor = :dimgray
        ,edgecolor=:dimgray
        ,markerstrokewidth = 1.1
        ,node_size=nsize
        ,edgestyle = :dot
        ,curves = false
    )
    annotate!((-0.4,0.72,Plots.text("Control Network", 11, :black, :center)))

    p = Plots.plot(ctl_p,ntw_p, layout=l, size=(300,600))
    
    return p

end


function plotabm_networks_mono(
    model;
    kwargs...,
)

    nsize = 0.4
    lwidth = 0.5

    l =  @layout([A{0.01h}; [B C ; D E]])  #(2,2) #@layout [a{1w} [grid(1,2) b{0.2h}] ] #@layout [a{1w};(1,2)]

    title = plot(title = "Plot title", grid = false, showaxis = false, ticks=false, bottom_margin = -50Plots.px)

    ctl_p = plot(circle_shape(0,0,0.1)
                 , seriestype = [:shape]
                 , lw=0.5 
                 , c=:lightblue
                 , linecolor=:black
                 , legend = false
                 #, fillalpha = 0.5
                 , aspect_ratio = 1
                 , showaxis = false
                 ,xlims=[-1,1]
                 ,ylims=[-1,1]
                 ,grid = false
                 ,ticks=false
                 ,titlefontcolor=:white
                )
    annotate!((-1,0.72,Plots.text("Single Controller", 11, :black, :center)))

    ctl_r = plot(title="false", titlefontcolor=:white ,showaxis = false, ticks=false,grid=false)

    ntw_p = graphplot(
        model.ntw_graph
        ,names = [get_sne_id(i,model) for i=1:nv(model.ntw_graph)]
        , method = :circular
       # ,size=(300,200)
        ,node_weights = [ get_sne_id(i,model) > 9 ? 1 : 10 for i in 1:nv(model.ntw_graph)]  #[ i > 9 ? 1 : 10 for i in 1:nv(model.ntw_graph)]
        ,nodeshape = :hexagon
        ,nodecolor = [ is_up(getindex(model,get_sne_id(i,model))) ? :lightgray : :red for i in 1:nv(model.ntw_graph) ]
        ,markerstrokecolor = :dimgray
        ,edgecolor= model.ticks < 1 ? :red : :dimgray
        ,markerstrokewidth = 1.1
        ,node_size=nsize
        ,palette = [:lightgray, :red]
        #,titlefontsize=1
        ,titlefontcolor=:white
    )
    
    annotate!((-0.7,0.75,Plots.text("Asset Network", 11, :black, :center)))

    tpt_p = plot(title="tpt",titlefontcolor=:white,ylims=[0,30])
    for i=1:nv(model.ntw_graph)
        sne = getindex(model,get_sne_id(i,model))
        tpt_p = plot!([ s.in_pkt for s in sne.state_trj ],xlims=[0,model.N], line=:stem, linealpha=0.5)
    end
    
    annotate!((-1,33,Plots.text("Throughput", 11, :black, :center)))

    p = Plots.plot(title,ctl_p,ctl_r,ntw_p,tpt_p, layout=l, size=(800,600))
    
    return p#ntw_p

end

function plotabm_networks(
    model;
    kwargs...
)
    if nv(model.ctl_graph) > 1
        return plotabm_networks_multi(model;kwargs...)
    else
        return plotabm_networks_mono(model;kwargs...)
    end
end



function get_control_agent(asset_id::Int,model)
    return model.mapping_ctl_ntw[asset_id]
end

function get_controlled_assets(agent_id::Int,model)
    assets = filter(k->model.mapping_ctl_ntw[k] == agent_id,keys(model.mapping_ctl_ntw))
    #println("assets controlled by $(agent_id) are: $(length(assets))")
    return assets
end

function set_control_agent!(asset_id::Int, agent_id::Int, model)
    getindex(model,asset_id).controller_id = agent_id
    #TODO Consider removing this line below
    #To avoid putting info in model
    model.mapping_ctl_ntw[asset_id] = agent_id
end

function soft_drop_node(model)
    #-1 pick node to remove
    #0 on_switch event
    #1remove from network
    #2in controller: update topology and paths
    #in switch detect path/port not available and ask controller

    dpn_ids = [3] # dropping node id
    dpt = 80 # dropping time

    if model.ticks == dpt

        for dpn_id in dpn_ids
            for nb in all_neighbors(model.ntw_graph,get_address(dpn_id,model))
                link_down!(get_sne_id(nb,model),dpn_id,model)
            end
            #soft remove 
            dpn_ag = getindex(model,dpn_id)
            set_down!(dpn_ag)
            delete!(model.mapping_ctl_ntw,dpn_id)
            model.ntw_graph = soft_remove_vertex(model.ntw_graph,get_address(dpn_id,model))
            
        end
        
        
    end
    
end



function hard_drop_node(model)
    #-1 pick node to remove
    #0 on_switch event
    #1remove from network
    #2in controller: update topology and paths
    #in switch detect path/port not available and ask controller

    dpn_ids = [3] # dropping node id
    dpt = 80 # dropping time

    if model.ticks == dpt

        for dpn_id in dpn_ids
            for nb in all_neighbors(model.ntw_graph,get_address(dpn_id,model))
                link_down!(get_sne_id(nb,model),dpn_id,model)
            end
            #remove 
            dpn_ag = getindex(model,dpn_id)
            #kill_agent!(dpn_ag,model)
            set_down!(dpn_ag)
            delete!(model.mapping_ctl_ntw,dpn_id)
            #remove_vertices!(model.ntw_graph,[get_address(i,model) for i in dpn_ids])
            model.ntw_graph = remove_vertex(model.ntw_graph,get_address(dpn_id,model))
            update_addresses_removal!(dpn_id,model)
        end
        
        
    end
    
end

function soft_remove_vertex(g::AbstractGraph,dpn_id::Int)
    sm_g = sparse(g)
    sm_new_g = deepcopy(sm_g)

    [ if i == dpn_id || j == dpn_id ; sm_new_g[i,j] = 0 end for i=1:nv(g), j=1:nv(g)]

    # for i=1:nv(g)
    #     for j=1:nv(g)
    #         if i == dpn_id || j == dpn_id
    #             new_ntw[i,j] = 0
    #         end
    #     end
    # end
    #[i >=dpn_id ? labels[i] = i+1 : labels[i] = i  for i in keys(labels)]
    return SimpleGraph(sm_new_g)
end

function remove_vertex(g::AbstractGraph,dpn_id::Int)
    sm_g = sparse(g)
    sm_new_g = spzeros((nv(g)-1),(nv(g)-1))
    for i=1:nv(g)
        for j=1:nv(g)
            #println(" $i,$j value: $(sparse(ntw)[i,j])")
                x,y =   i < dpn_id && j < dpn_id ? (i,j) : 
                        i < dpn_id && j > dpn_id ? (i,j-1) : 
                        i > dpn_id && j < dpn_id ? (i-1,j) : 
                        i > dpn_id && j > dpn_id ? (i-1,j-1) : (0,0)
                
                if x > 0 && y > 0
                    sm_new_g[x,y] = sm_g[i,j]
                    sm_new_g[y,x] = sm_g[j,i]
                end
        end
    end
    #[i >=dpn_id ? labels[i] = i+1 : labels[i] = i  for i in keys(labels)]
    return SimpleGraph(sm_new_g)
end

function remove_vertices(g::AbstractGraph,dpn_ids::Array{Int})
    new_g = g
    for dpn_id in dpn_ids
        new_g = remove_vertex!(new_g,dpn_id)
    end
    return new_g
end
"""
Given a SimNE id it returns its ntw node address.
"""
function get_address(sne_id::Int,model)::Int
    res = filter(p->p[2] == sne_id,pairs(model.mapping_ntw_sne))
    #println(" Pair? $res")
    return !isempty(res) ? first(keys(res)) : -1
end

"""
Given a ntw node address it returns the corresponding SimNE id
"""
function get_sne_id(address::Int,model)::Int
    return model.mapping_ntw_sne[address]
end

function update_sne_address!(sne_id::Int,new_address::Int,model)
    #curr_address = get_address(sne_id,model)
    model.mapping_ntw_sne[new_address] = sne_id
end

"""
Update (ntw node) addresses of SimNE agents after removal of a given SimNE
"""
function update_addresses_removal!(dpn_id::Int,model)
    available_addr = get_address(dpn_id,model)
    #println("Current length of g: $(nv(model.ntw_graph))")
    for addr::Int=available_addr:nv(model.ntw_graph)
        #println("Address $addr and its type: $(typeof(addr))")
        update_sne_address!(
            get_sne_id(addr+1,model),
            addr,
            model
            )
    end
    delete!(model.mapping_ntw_sne,length(model.ntw_graph)+1)
end

function circle_shape(h,k,r)
    θ = LinRange(0,2*π, 500)
    h .+ r*sin.(θ), k .+ r*cos.(θ)
end

