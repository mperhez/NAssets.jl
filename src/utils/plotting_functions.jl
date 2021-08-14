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

    node_colors = [ ruls[i] > 0 ? condition_color[ruls[i]] : :lightgray for i=1:nv(model.ntw_graph) ] 
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
        log_info(model.ticks,sne.id,"==> pktl_trj: $pktl_v")
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
	p = @df df_net scatter!(base_geo_plot,:bng_lon,:bng_lat,markersize=1,alpha=0.5,dpi=dpi,markerstrokewidth=0,label="",color=:red,legend=:topright, markershape=:octagon) 
    return p
end

"""
    Plot network on top of the given geo plot passed
"""
function plot_geo_network(base_geo_plot,g::MetaGraph)
    dpi = 300
    size = (400,500)
    lons = [ get_prop(g,i,:bng_lon) for i=1:nv(g)]
    lats = [ get_prop(g,i,:bng_lat) for i=1:nv(g)]
    p = graphplot!(base_geo_plot,g,x=lons,y=lats,alpha=0.3,dpi=dpi,size=size,nodesize=2,aspect_ratio=1,curvature_scalar=0.5,nodecolor=:red)
    return p 
end

"""
It plots one step at a time, receiving all steps in a vector of vector of NetworkAssetState
"""
function plot_geo_network_step(base_geo_plot,g::MetaGraph,sne_steps::Vector{Vector{NetworkAssetState}},step)
    dpi = 300
    size = (400,500)
    
    condition_color = cgrad([:red, :yellow, :green],collect(0.01:0.01:1))

    lons = [ get_prop(g,i,:bng_lon) for i=1:nv(g)]
    lats = [ get_prop(g,i,:bng_lat) for i=1:nv(g)]
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

    lons = [ get_prop(g,i,:bng_lon) for i=1:nv(g)]
    lats = [ get_prop(g,i,:bng_lat) for i=1:nv(g)]
    ruls = [ r.rul for r in eachrow(sne_steps[sne_steps[!,:t] .== step,:])]./100

    p = graphplot!(base_geo_plot,g,x=lons,y=lats,alpha=0.3,dpi=dpi,size=size,nodesize=2,aspect_ratio=1,curvature_scalar=0.5,nodecolor=[ condition_color[i] for i in ruls ])
    return p 
end