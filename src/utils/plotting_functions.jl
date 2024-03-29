"""
Plots a subgraph that is part of a greater one
global ids in property :eid.
"""
function plot_subg(sg)
    return graphplot(sg
                    ,names = [ get_prop(sg,i,:eid) for i=1:nv(sg)]
          )
end
"""
 Plots a multiagent control network
"""
function plot_ctl_network_multi( model; kwargs...,)

    nsize = 0.13
    lwidth = 0.5

    method = model.ctrl_model == GraphModel(4) ? :sfdp : :circular
    Random.seed!(model.seed)

    ctl_p = graphplot(
        model.ctl_graph
        ,names = [ i for i in 1:nv(model.ctl_graph) ]
                #[ get_control_agent(i,model) for i in 1:nv(model.ctl_graph) ]
        ,method = method#:sfdp#:stress#:shell# #:spectral #:circular
        #TODO check if required, not working atm
        #,func = NetworkLayout.SFDP.layout(adjacency_matrix(model.ctl_graph),2)
        , curvature_scalar = 0.0
        ,size=(300,200)
        ,node_weights = [ i > 9 ? 1 : 5 for i in 1:nv(model.ctl_graph)]
        ,nodeshape = :circle
        # ,nodecolor = [ has_active_controlled_assets(
        #                 getindex(model,model.ctl_graph[i,:aid]),model
        #                ) ? :lightblue : :lightgray for i in 1:nv(model.ctl_graph) ]
        # ,markerstrokecolor = :dimgray
        # ,edgecolor=:dimgray
        ,markerstrokewidth = 1.1
        ,node_size=nsize
        ,edgestyle = :dot
        ,titlefontcolor=:white
        ,curves = false
    )
    #TODO replace buggy annotation not thread-safe
    # annotate!((-0.7,0.72,Plots.text("Control Network", 11, :black, :center)))
    annotate!((0.0,0.72,Plots.text("Control Network", 11, :black, :center)))
        
    return ctl_p

end
"""
 Plots a single agent control network
"""
function plot_ctl_network_mono(model; kwargs...,)

    ctl_p = Plots.plot(circle_shape(0,0,0.1)
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

    return ctl_p

end
"""
 Plots message exchange among control agents
"""
function plot_ctl_throughput(model;kwargs...)
    tpt_v = get_ag_msg(model)
    max_y = maximum(tpt_v)+5
    tpt_p = Plots.plot(title="tpt",titlefontcolor=:white,ylims=[0,max_y])
    # for i=1:nv(model.ctl_graph)
    #     a = getindex(model,model.ctl_graph[i,:aid])
        # tpt_v = get_throughput_up(a,model)
    
    # log_info("Plotting...")
    # log_info(tpt_v)
    tpt_p = Plots.plot!(tpt_v,xlims=[0,model.N], linealpha=0.5
        # , line=:stem
        ,ylabel = "Quantity of agent messages"
        ,legend = false#:outerright
        )
    # end

    annotate!((3*(model.N/4),max_y+1,Plots.text("Control Msgs", 11, :black, :center)))

    return tpt_p
end
"""
 Plots the underlying controlled network
"""
function plot_asset_networks(model;kwargs...)
    
    nsize = 0.2
    lwidth = 0.5
    condition_color = cgrad([:red, :yellow, :green],collect(0.00:0.01:1))
    method = model.ntw_model == GraphModel(4) ? :stress : :circular
    Random.seed!(model.seed)

    edge_color_dict = Dict()
    edge_width_dict = Dict()
    edge_style_dict = Dict()
    node_color_dict = Dict()

    for e in edges(model.base_ntw_graph)
        if model.ticks > 0
            if is_active_flow((e.src,e.dst),model)
                edge_color_dict[(e.src,e.dst)] = :green
                edge_width_dict[(e.src,e.dst)] = 3
                edge_style_dict[(e.src,e.dst)] = model.ticks % 3 > 0 ? model.ticks % 3 > 1 ? :dashdot : :solid : :dot
            else
                edge_color_dict[(e.src,e.dst)] = has_edge(model.ntw_graph,e.src,e.dst) || has_edge(model.ntw_graph,e.dst,e.src) ? :dimgray : :white
                edge_width_dict[(e.src,e.dst)] = 1
                edge_style_dict[(e.src,e.dst)] = :solid
            end
        else
            edge_color_dict[(e.src,e.dst)] = :red
            edge_width_dict[(e.src,e.dst)] = 1
            edge_style_dict[(e.src,e.dst)] = :solid
        end
        
    end
    
    ruls = [ Int(round(get_state(getindex(model,i)).rul)) for i in 1:nv(model.ntw_graph)]
    
    # rearrange ruls splitting array in 2 and starting with second half to match plotting algorithms, IDKW.   
    ruls = vcat(ruls[nv(model.ntw_graph)÷2+1:nv(model.ntw_graph)],ruls[1:nv(model.ntw_graph)÷2])

    node_colors = [ ruls[i] > 0 ? condition_color[ruls[i]] : :red for i=1:nv(model.ntw_graph) ] 
    # log_info(model.ticks," RULs: $(ruls)")
    ntw_p = graphplot(
        model.base_ntw_graph
        ,names = [get_eid(i,model) for i=1:nv(model.ntw_graph)] #[ i for i in ruls ]
        , method = method
        ,size=(300,200)
        ,dpi=400
        ,node_weights = [ get_eid(i,model) > 9 ? 1 : 10 for i in 1:nv(model.ntw_graph)]  #[ i > 9 ? 1 : 10 for i in 1:nv(model.ntw_graph)]
        ,nodeshape = :hexagon
        ,nodecolor = node_colors
        # ,markerstrokecolor = :dimgray
        ,edgecolor= edge_color_dict
        ,edgewidth= edge_width_dict
        ,edgestyle = edge_style_dict
        #,arrow = arrow(:closed, :tail)
        ,markerstrokewidth = 1.1
        ,node_size=nsize
        ,palette = [:lightgray, :red]
        #,titlefontsize=1
        ,titlefontcolor=:white
    )
    
    # annotate!((-0.7,0.75,Plots.text("Infrastructure Condition & Flows View", 11, :black, :center)))
    annotate!((0.0,0.75,Plots.text("Asset Condition & Flows", 11, :black, :center)))

    return ntw_p
end
"""
 Plots an empty placeholder
"""
function plot_empty()
    return Plots.plot(title="false", titlefontcolor=:white ,showaxis = false, ticks=false,grid=false)
end
"""
 Plots throughput of the underlying controlled network
"""
function plot_throughput(model;kwargs...)
    max_y = 500
    tpt_p = Plots.plot(title="tpt",titlefontcolor=:white,ylims=[0,max_y])
    for i=1:nv(model.ntw_graph)
        sne = getindex(model,get_eid(i,model))
        #tpt_v = get_throughput_up(sne,model)
        tpt_v = get_throughput_trj(sne)
        # log_info(model.ticks,sne.id,"==> tpt_trj: $tpt_v")
        tpt_p = Plots.plot!(tpt_p,tpt_v
        ,xlims=[0,model.N]
        , linealpha=0.5
        # , line=:stem
        ,label = "$i"
        ,ylabel = "MB"
        ,legend = :outerright#false#
        )
    end
    #TODO: This annotation breaks the multithreading as it does not receive the plot object, it seems to take the last one, which might clash among threads.
    # annotate!((3*(model.N/4),max_y+1,Plots.text("Throughput ($(model.interval_tpt) steps)", 11, :black, :center)))
    # annotate!((3*(model.N/4),max_y+5,Plots.text("Throughput", 11, :black, :center)))
    annotate!((2.5*(model.N/4),max_y+15,Plots.text("Throughput", 11, :black, :center)))

    return tpt_p
end
"""
 Plots packet loss of the underlying controlled network
"""
function plot_packet_loss(model;kwargs...)
    max_y = model.pkt_per_tick
    pktl_p = Plots.plot(title="Packet Loss",titlefontcolor=:white,ylims=[0,max_y])
    for i=1:nv(model.ntw_graph)
        sne = getindex(model,get_eid(i,model))
        pktl_v = get_packet_loss_trj(sne)

        pktl_p = Plots.plot!(pktl_p,pktl_v
        ,xlims=[0,model.N]
        , linealpha=0.5
        ,label = "$i"
        ,ylabel = "Q"
        ,legend = :outerright
        )
    end
    #TODO: This annotation breaks the multithreading as it does not receive the plot object, it seems to take the last one, which might clash among threads.
    annotate!((3*(model.N/4),max_y+1,Plots.text("Packet Loss", 11, :black, :center)))

    return pktl_p
end

"""
Main plotting function calls others
"""
function plotabm_networks(model;kwargs...)
    
    l =  @layout([A{0.01h}; [B C ; D E]])  #(2,2) #@layout [a{1w} [grid(1,2) b{0.2h}] ] #@layout [a{1w};(1,2)]

    title = Plots.plot(title = "Plot title", grid = false, showaxis = false, ticks=false, bottom_margin = -50Plots.px)

    ctl_p = model.ctrl_model != GraphModel(1) ? # Centralised
            plot_ctl_network_multi(model;kwargs...) :
            plot_ctl_network_mono(model;kwargs...)
    

    ctl_r = model.ctrl_model != GraphModel(1) ? plot_ctl_throughput(model; kwargs) : plot_empty()

    ntw_p = plot_asset_networks(model; kwargs)
    
    bottom_right_p = plot_throughput(model; kwargs)#plot_packet_loss(model; kwargs) # 

    p = Plots.plot(title,ctl_p,ctl_r,ntw_p,bottom_right_p, layout=l
    , size=(600,400),dpi=400)

    #p = ntw_p
    
    return p
end

"""
  Plots the bare base map using the shp file passed
"""
function plot_base_map(shp_file)
    shp_map_uk_regions = load_map(shp_file)
    #df_shp_map_uk_regions = DataFrame(shp_map_uk_regions)
    points = []
    
    dpi = 300
    size = (400,500)

    p = plot(shp_map_uk_regions,alpha=0.07,palette=:cork,dpi = dpi,xlims=[0,8e5],size=size,showaxis=false,grid=false,ticks=false,label="")
    
    return p
end

"""
    Plot network on top of the given geo plot passed
"""
function plot_geo_network(base_geo_plot,df_net)
    dpi = 300
    size = (400,500)
	p = @df df_net scatter!(base_geo_plot,:lon,:lat,markersize=1,alpha=0.5,dpi=dpi,markerstrokewidth=0,label="",color=:red,legend=:topright, markershape=:octagon) 
    return p
end

"""
    Plot network on top of the given geo plot passed
"""
function plot_geo_network(base_geo_plot,g::MetaGraph)
    dpi = 300
    size = (400,500)
    n_v = nv(g)
    lons = [ get_prop(g,i,:lon) for i=1:n_v]
    lats = [ get_prop(g,i,:lat) for i=1:n_v]
    p = graphplot!(base_geo_plot,g,x=lons,y=lats,alpha=0.3,dpi=dpi,size=size,nodesize=4.5,aspect_ratio=1,curvature_scalar=0.5,nodecolor="#FDF3C4"
    ,names=collect(1:n_v)
    ,fontsize=3, edgecolor = :green)
    return p 
end

"""
It plots one step at a time, receiving all steps in a vector of vector of NetworkAssetState
"""
function plot_geo_network_step(base_geo_plot,g::MetaGraph,sne_steps::Vector{Vector{NetworkAssetState}},step)
    dpi = 300
    size = (400,500)
    
    condition_color = cgrad([:red, :yellow, :green],collect(0.01:0.01:1))

    lons = [ get_prop(g,i,:lon) for i=1:nv(g)]
    lats = [ get_prop(g,i,:lat) for i=1:nv(g)]
    ruls = [sne_steps[i][step] for i=1:nv(g) ]

    p = graphplot!(base_geo_plot,g,x=lons,y=lats,alpha=0.3,dpi=dpi,size=size,nodesize=2,aspect_ratio=1,curvature_scalar=0.5,nodecolor=[ condition_color[i] for i in ruls ])
    return p 
end

"""
It plots one step at a time, receiving all steps in a DataFrame with data coming from NetworkAssetState
"""
function plot_geo_network_step(base_geo_plot,g::MetaGraph,sne_steps::DataFrame,step)
    dpi = 300
    size = (400,500)
    
    condition_color = cgrad([:red, :yellow, :green],collect(0.01:0.01:1))

    lons = [ get_prop(g,i,:lon) for i=1:nv(g)]
    lats = [ get_prop(g,i,:lat) for i=1:nv(g)]
    ruls = [ r.rul for r in eachrow(sne_steps[sne_steps[!,:t] .== step,:])]./100

    p = graphplot!(base_geo_plot,g,x=lons,y=lats,alpha=0.3,dpi=dpi,size=size,nodesize=2,aspect_ratio=1,curvature_scalar=0.5,nodecolor=[ condition_color[i] for i in ruls ])
    return p 
end

function plot_geo_network_step(base_geo_plot,g::MetaGraph,v_props::Dict{Symbol,Symbol},e_props::Dict{Symbol,Symbol},t::Int64)
    dpi = 300
    size = (400,500)
    
    v_size = 4.5
    v_shape = :hexagon
    n_v = nv(g)
    lons = [ get_prop(g,i,:lon) for i=1:n_v]
    lats = [ get_prop(g,i,:lat) for i=1:n_v]
    e_color,e_width,e_style = get_edge_plot_props_step(g,t,e_props)
    v_color = get_vertex_plot_props_step(g,t,v_props)
    g_plot = graphplot!(
                        base_geo_plot
                        ,g
                        ,x=lons,y=lats
                        ,alpha=0.3
                        ,names = collect(1:n_v)
                        ,node_weights = [ i >9 ? 1 : 10 for i=1:n_v ]
                        ,node_size = v_size
                        ,nodecolor = v_color
                        ,nodeshape = v_shape
                        ,edgecolor = e_color
                        ,edgewidth = e_width
                        ,edgestyle = e_style
                        ,left_margin = -400Plots.px
                        ,right_margin = -250Plots.px
                        ,fontsize=3
                        ,dpi=dpi,size=size, aspect_ratio=1,curvature_scalar=0.5
                        )
    return g_plot
end

"""
Plot network according to arguments
# """
# function plot_network(g::MetaGraph,)
# end


########TODO REVIEW#############

function prepare_graph!(g::MetaGraph,snes_ts::Vector{Vector{NetworkAssetState}},model_ts::Vector{ModelState},props::Dict{Symbol,Symbol})

    rul_prop = props[:rul] 
    up_prop = props[:up]
    tpt_prop = props[:tpt]
    drop_prop = props[:drop]

        #vertices
        for nid=1:nv(g)
            sne_ts = snes_ts[nid]
            set_prop!(g,nid,rul_prop,[ s.rul for s in sne_ts ][1:end-1])#remove last to have equal ticks to edges
            set_prop!(g,nid,up_prop,[ s.up for s in sne_ts ][1:end-1])
            set_prop!(g,nid,drop_prop,[ s.drop_pkt for s in sne_ts ][1:end-1])
        end

        #edges
        for e in edges(g)
            if e.src < e.dst
                edge_ts = [ haskey(s.links_load,(e.src,e.dst)) ? s.links_load[(e.src,e.dst)] : haskey(s.links_load,(e.dst,e.src)) ? s.links_load[(e.dst,e.src)] : 0  for s in model_ts ]
                set_prop!(g,e.src,e.dst,tpt_prop, edge_ts)
                set_prop!(g,e.dst,e.src,tpt_prop, edge_ts)
            end
            
        end
    return g
end


"""
labels is a dictionary where keys are: :tpt for througput and :up for node alive.
"""
function get_edge_plot_props_step(g::MetaGraph,t::Int64,props::Dict{Symbol,Symbol})
    colors = Dict(1=>:blue,14=>:green,7=>:purple,8=>:orange)
    e_color = Dict()
    e_width = Dict()
    e_style = Dict()

    for e in edges(g)
        if get_prop(g,e,props[:tpt])[t] > 0
            e_color[(e.src,e.dst)] = "#2F9D96"#"#1C5E5A" #:green
            e_width[(e.src,e.dst)] = 3
            e_style[(e.src,e.dst)] = t % 3 > 0 ? t % 3 > 1 ? :dashdot : :solid : :dot
        else
            e_width[(e.src,e.dst)] = 1
            e_style[(e.src,e.dst)] = :solid
            if get_prop(g,e.src,props[:up])[t] && get_prop(g,e.dst,props[:up])[t]
                e_color[(e.src,e.dst)] = :gray
            else
                e_color[(e.src,e.dst)] = :white
            end
        end
    end

    return e_color, e_width, e_style
end

function get_vertex_plot_props_step(g::MetaGraph,t::Int64,props::Dict{Symbol,Symbol})
    condition_color = cgrad(["#FF5964", "#FDF3C4", "#669bbc"],collect(0.00:0.01:1))

    ups = [ get_prop(g,v,props[:up])[t] for v=1:nv(g) ]
    ruls = [ get_prop(g,v,props[:rul])[t] for v=1:nv(g) ]
    ruls = vcat(ruls[nv(g)÷2+1:nv(g)],ruls[1:nv(g)÷2])
    
    v_color = [ ruls[i] > 0 ? condition_color[Int(round(ruls[i]))+1] : :white for i=1:length(ruls)]
    
    return v_color
end


function plot_graph_step(g::MetaGraph,v_props::Dict{Symbol,Symbol},e_props::Dict{Symbol,Symbol},t::Int64)
    Random.seed!(seed)
    method = :stress
    v_size = 0.4
    v_shape = :hexagon

    e_color,e_width,e_style = get_edge_plot_props_step(g,t,e_props)
    v_color = get_vertex_plot_props_step(g,t,v_props)
    g_plot = graphplot(
                        g
                        ,method = method
                        ,names = collect(1:nv(g))
                        ,node_weights = [ i >9 ? 1 : 10 for i=1:nv(g) ]
                        ,node_size = v_size
                        ,nodecolor = v_color
                        ,nodeshape = v_shape
                        ,edgecolor = e_color
                        ,edgewidth = e_width
                        ,edgestyle = e_style
                        ,bottom_margin = -30Plots.px
                        )
    return g_plot
end

"""
It plots throughput and reference for one step of an animation of t timesteps
"""
function plot_tpt_step(snes_ts::Vector{Vector{NetworkAssetState}},snes_ref_ts::Vector{Vector{NetworkAssetState}},model_ts::Array{ModelState, 1},t::Int64)
    max_x = 300
    colors = Dict(1=>:blue,14=>:green,7=>:purple,8=>:orange)

    #get end node of each active flow (service)
    end_snes_ts = [[1,7,8,14] for tk=1:t]#[ [f[2] for f in model_ts[t].active_flows if f[3] == f_E || f[3] == f_SE] for t=1:t ]
    sort!(end_snes_ts)
    p = plot(xlims=[0,max_x],ylims=[0,250]
    ,xlabel="Time",ylabel="Throughput. (MB)"
    #,xticks=false
    ,legend=false#:outertop#:outerright
    )
    for end_sne in end_snes_ts[t]
        tpts_ref = hcat([ get_throughput_trj(snes_ref_ts[sne],max_x) for sne=1:length(snes_ref_ts) if sne in end_sne ]...)
        p = plot!(tpts_ref, color = colors[end_sne], alpha=0.2
        #,linestyle=:dot 
        )
        tpts = hcat([ get_throughput_trj(snes_ts[sne],t) for sne=1:length(snes_ts) if sne == end_sne ]...)

        p = plot!(p,tpts,color=colors[end_sne])
    end
    if t == 80
        print(get_throughput_trj(snes_ts[1],t))
    end
    return p
end


"""
It plots throughput for one step of an animation of t timesteps
"""
function plot_tpt_step(snes_ts::Vector{Vector{NetworkAssetState}},end_services::Vector{Tuple{Int64,Int64}},t::Int64)
    max_x = 300
    colors = Dict(1=>:blue,14=>:green,7=>:purple,8=>:orange)

    #get end node of each active flow (service)
    end_snes_ts = [end_services for tk=1:t]#[ [f[2] for f in model_ts[t].active_flows if f[3] == f_E || f[3] == f_SE] for t=1:t ]
    sort!(end_snes_ts)
    p = plot(xlims=[0,max_x],ylims=[0,250]
    ,xlabel="Time",ylabel="Throughput (MB)"
    #,xticks=false
    ,legend=:outertop#:outerright
    )
    for end_sne in end_snes_ts[t]
        println("doing $end_sne ...")
        
        # tpts = hcat([ get_throughput_trj(snes_ts[sne],t) for sne=1:length(snes_ts) if sne == last(end_sne) ]...)

        tpts = get_throughput_trj(snes_ts[last(end_sne)],t)

        # if last(end_sne) in [8,14]
            p = plot!(p,tpts,color=colors[last(end_sne)])
        # end
    end
    if t == 80
        print(get_throughput_trj(snes_ts[1],t))
    end
    return p
end

function plot_maintenance_cost_step(snes_ts::Vector{Vector{NetworkAssetState}},model_ts::Array{ModelState, 1},t::Int64)
    costs = zeros(1:t)    
    if t > 1

        ruls = [  snes_ts[sne][tk].on_maintenance ? snes_ts[sne][tk].rul : -1.0  for sne=1:length(snes_ts), tk=1:t ]

        is_starts = hcat(Bool.(zeros(1:length(snes_ts))),[  !snes_ts[sne][tk-1].on_maintenance && snes_ts[sne][tk].on_maintenance ? true : false for sne=1:length(snes_ts),tk=2:t ])

        is_actives = transpose(hcat([ is_in.(sne,
                                            [ unique(vcat([ vcat(f[1],f[2]) for f in model_ts[tk].active_flows ]...)) for tk=1:t ]) for sne in collect(1:length(snes_ts)) ]...))



        costs = cumsum(sum(eachrow(
                    maintenance_cost.(
                        ruls,
                        is_starts,
                        is_actives,
                        5, 4, 10, 3
                    )
                )))

        if t == 140
         
        println("=========RULS=============")
        print(ruls)
        print("\n")
        println("========IS_STARTS==============")
        print(is_starts)
        print("\n")
        println("========IS_ACTIVEs==============")
        print(is_actives)
        print("\n")
        println("==========COSTS============")
        print(costs)
        print("\n")
        end
        
    end
    
    return plot(
                costs
                ,legend = false
                ,ylims=[0,1000]
                ,xlims=[0,300]
            )


    # sum_dp = sum(eachrow([  snes_ts[sne][tk].drop_pkt  for sne=1:length(snes_ts), tk=1:t ]))

end



function plot_maintenance_cost_step(snes_ts1::Vector{Vector{NetworkAssetState}},snes_ts2::Vector{Vector{NetworkAssetState}},snes_ts3::Vector{Vector{NetworkAssetState}},model_ts::Vector{ModelState},t::Int64)
    costs = zeros(3,t)
    
    snes_ts = [snes_ts1,snes_ts2,snes_ts3]
    
    if t > 1

        for sr=1:length(snes_ts)
            ruls = [  snes_ts[sr][sne][tk].on_maintenance ? snes_ts[sr][sne][tk].rul : -1.0  for sne=1:length(snes_ts[sr]), tk=1:t ]

            is_starts = hcat(Bool.(zeros(1:length(snes_ts[sr]))),[  !snes_ts[sr][sne][tk-1].on_maintenance && snes_ts[sr][sne][tk].on_maintenance ? true : false for sne=1:length(snes_ts[sr]),tk=2:t ])

            is_actives = transpose(hcat([ is_in.(sne,
                                                [ unique(vcat([ vcat(f[1],f[2]) for f in model_ts[tk].active_flows ]...)) for tk=1:t ]) for sne in collect(1:length(snes_ts[sr])) ]...))



            costs[:,sr] = cumsum(sum(eachrow(
                        maintenance_cost.(
                            ruls,
                            is_starts,
                            is_actives,
                            5, 4, 10, 3
                        )
                    )))
        end
        
    end
    
    return plot(
                costs
                ,legend = false
                ,ylims=[0,1000]
                ,xlims=[0,300]
            )


    # sum_dp = sum(eachrow([  snes_ts[sne][tk].drop_pkt  for sne=1:length(snes_ts), tk=1:t ]))

end

"""
Function that prepare serialised time series of control agents for plotting
"""
function prepare_service_paths(services,ca_ts)
    t = length(ca_ts)
    paths = [ collect(values(ca_ts[tk].active_paths)) for tk=1:t ]
    path_lengths = [ [ (first(path),last(path),length(path)) for path in paths[tk] ] for tk=1:t ] 
    
    return hcat([ vcat([ [ p[3] for p in path_lengths[tk] if p[1] == first(s) && p[2] == last(s) ] for tk=1:t ]...) for s in services ]...)
end

"""
It loads serialised data for all the runs in the passed directory 
"""
function load_run_data(services,data_dir::String)

    run_data = []
    ca_ts = Dict()
    snes_ts = Dict()
    model_ts = Dict()
    root = data_dir
    sdirs = readdir(root)

    for dir in sdirs
        println("processing : $dir ...")
        files = readdir(joinpath(root,dir))
        for file in files
            mdsp = split(file,"_steps_model.bin")
            nesp = split(file,"_steps_nelements.bin")
            agsp =  split(file,"_steps_ctl_agents.bin")
            mdata = length(mdsp) > 1 ? deserialize(joinpath(root, dir,file)) : nothing

            if !isnothing(mdata)
                #key: last of directory + unique run label
                model_ts[first(mdsp)*"_"*last(split(dir,"_"))] = mdata
            end

            snedata = length(nesp) > 1 ? deserialize(joinpath(root, dir,file)) : nothing 

            if !isnothing(snedata)
                snes_ts[first(nesp)*"_"*last(split(dir,"_"))] = snedata
            end

            ctlagdata = length(agsp) > 1 ? deserialize(joinpath(root, dir, file)) : nothing 

            if !isnothing(ctlagdata)
                ca_ts[first(agsp)*"_"*last(split(dir,"_"))] = ctlagdata
            end
        end
    end

    for k in keys(model_ts)
        push!(run_data,
            (label = k,
            snes_ts=snes_ts[k]
            ,ca_ts=ca_ts[k]
            ,model_ts=model_ts[k]
            ,ctl_model = split(k,"_")[5]
            ,fail_prop= last(split(k,"_"))
            ,seed = length(split(k,"_")) > 11 ? split(k,"_")[10] : split(k,"_")[7]
            )
        )
    end

    return run_data
end


"""
It plots cost for three time series at a time
"""

function plot_maintenance_cost_step(snes_ts1::Vector{Vector{NetworkAssetState}},snes_ts2::Vector{Vector{NetworkAssetState}},snes_ts3::Vector{Vector{NetworkAssetState}},model_ts1::Array{ModelState, 1},model_ts2::Array{ModelState, 1},model_ts3::Array{ModelState, 1},t::Int64)
    costs = []#zeros(3,t)
    
    snes_ts = [snes_ts1,snes_ts2,snes_ts3]
    model_ts = [model_ts1,model_ts2,model_ts3]

    if t > 1

        for sr=1:length(snes_ts)
            ruls = [  snes_ts[sr][sne][tk].on_maintenance ? snes_ts[sr][sne][tk].rul : -1.0  for sne=1:length(snes_ts[sr]), tk=1:t ]

            is_starts = hcat(Bool.(zeros(1:length(snes_ts[sr]))),[  !snes_ts[sr][sne][tk-1].on_maintenance && snes_ts[sr][sne][tk].on_maintenance ? true : false for sne=1:length(snes_ts[sr]),tk=2:t ])

            is_actives = transpose(hcat([ is_in.(sne,
                                                [ unique(vcat([ vcat(f[1],f[2]) for f in model_ts[sr][tk].active_flows ]...)) for tk=1:t ]) for sne in collect(1:length(snes_ts[sr])) ]...))



            push!(costs,cumsum(sum(eachrow(
                        maintenance_cost.(
                            ruls,
                            is_starts,
                            is_actives,
                            5, 4, 10, 1 #coeficients for dt, l, p & r costs (see function docs)
                        )
                    ))))
        end
        #print(costs[1])    
    end
    
    p = plot(
        title = "Total Costs"
        ,title_location = :right
        ,titlefont = font(8)
        ,legend = :topleft
        #,legend = false
        ,ylims=[0,1500]
        ,xlims=[0,300]
        ,legendfontsize=6
        ,ylabel="£"
        ,xlabel="Time"
        ,guidefontsize=6
        )

    labels = ["Corrective", "Preventive", "Optimal"]
    colors = [:orange,:purple,:green]
     for c=1:length(costs)
         p = plot!(p,costs[c],label=labels[c],color=colors[c])
     end
    return p

    # sum_dp = sum(eachrow([  snes_ts[sne][tk].drop_pkt  for sne=1:length(snes_ts), tk=1:t ]))

end
