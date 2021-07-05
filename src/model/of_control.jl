


function push_msg!(a::Agent,msg::OFMessage)
    put!(a.queue,msg)
end

function push_pending!(a::AbstractAgent,msg::OFMessage)
    push!(a.pending,msg)
end



function send_msg!(receiver::Int64,msg::OFMessage,model)
    ag = getindex(model,receiver)
    #TODO implement links and get delay of link in ticks
    queue = typeof(ag) == SimNE ? ag.queue : ag.queue
    # log_info("Sent to $receiver msg: $msg")
    put!(queue,msg)
end 

"""
    Function that makes a control agent trigger a flow install in the sne
"""
function install_flow!(a::Agent,path::Array{Int64,1},model::ABM,msg::OFMessage=nothing)
    # find which ones of path I am controlling
    es = get_controlled_assets(a.id,model)
    lpath = isempty(path) ? es : path 
    eois = intersect(es,lpath)
    lpath = [ v for v in lpath]
    
    log_info(model.ticks,a.id,"{$(get_controlled_assets(a.id,model))} install_flow! => path: $path -- es: $es -- eois: $eois - msg: -> $msg")
    
    for e in eois
        i = length(lpath) > 1 ? first(indexin(e,lpath)) : 1
        sne = getindex(model,e)
        i_prev = i > 1 ? i - 1 : i
         
        ports = get_port_edge_list(sne)
 
        # log_info("[$(model.ticks)]{$(a.id)}($(sne.id)) - ports: $(ports) - i: $i - i_prev: $i_prev - e: $e -- lpath : $lpath")
         #Regardless of where the traffic comes
         r_src = "*" #string("h",first(lpath)) 
         r_dst = last(lpath)
         in_port = 0
         if i == 1
             in_port = msg.in_port
             #TODO of_msg remove from pending
         else
             in_port = first([ first(p) for p in ports if parse(Int,p[2][2:end]) == lpath[i_prev]])
         end
         out_port = 0
         
         if i < length(lpath)
            next_port = filter(p->parse(Int,p[2][2:end]) == lpath[i+1],ports)
            out_port = isempty(next_port) ? -1 : first(first(next_port))
         end
         
         if out_port >= 0 
            flow = Flow(  sne.id
                    ,MRule(string(in_port)
                    ,string(r_src)
                    ,string(r_dst))
                    ,[out_port]
                    ,OFS_Output)
            qid = msg.id
            install_msg = OFMessage(next_ofmid!(model), model.ticks,e,1,OFPR_ADD_FLOW,(flow=flow,qid=qid))
            send_msg!(e,install_msg,model)
         else
            log_info(model.ticks,a.id,"ERROR: Unable to find port")            
         end

         next_sne = out_port > 0 ? lpath[i+1] : lpath[i]
        #  log_info(model.ticks,a.id,"--> ($(sne.id),$(next_sne))")
    end
   
end

function process_msg!(a::Agent,msg::OFMessage,model)

    
  
    @match msg.reason begin
        Ofp_Protocol(1) =>  
                        begin
                            log_info(model.ticks,a.id,"in_pkt -> $msg ===> prv_queries:  $(a.previous_queries)")
                            in_packet_handler(a,msg,model)
                        end
        Ofp_Protocol(2) => 
                            begin
                                # sneid_print = first(get_controlled_assets(a.id,model))
                                # sne_print = getindex(model,sneid_print)

                                # log_info(model.ticks,a.id,"BEFORE port_delete -> $msg ==>  $(get_state(sne_print).flow_table) ===> all ports: $(get_port_edge_list(sne_print))")

                                port_delete_handler(a,msg,model)

                                # log_info(model.ticks,a.id,"AFTER port_delete -> $msg ==>  $(get_state(sne_print).flow_table) ===> all ports: $(get_port_edge_list(sne_print))")
                            end
        _ => begin
            log_info("[$(model.ticks)]($(a.id)) -> match default")
            end
    end

    state = get_state(a)
    state.in_of_msg+=1.0
    set_state!(a,state)
end

"""
msg: SimNE.id, in_port, DPacket
"""
function in_packet_handler(a::Agent,msg::OFMessage,model)
    path::Array{Int64,1} = []
    found = false
   
    if msg.dpid != dst
        path = do_query!(msg,a,model)
        found = isempty(path) ? false : true
    else
        found = true
    end
   
    if found 
        install_flow!(a,path,model,msg)
        get_state(a).active_paths[(first(path),last(path))] = path
    end
end

"""
    Get query exclusions for a given message
    @Deprecated
"""
function get_exclusions(msg::OFMessage,model)
    exc = Int64[]
        
    # Avoid returning original source node
    if msg.dpid != msg.data.src
        push!(exc,msg.data.src)
    end

    # If packet is not originated in a host connected to this sne
    if msg.in_port != 0
        #find out previous sne node
        ports = get_port_edge_list(getindex(model,msg.dpid))
        prv_id = parse(Int64,filter(x->x[1]==msg.in_port,ports)[1][2][2:end])
        # if previous node has not been already pushed to exc
        if msg.data.src != prv_id
            push!(exc,prv_id)
        end
    end

    return exc   
end

function pending_pkt_handler(a::Agent,model)
    # if model.ticks in 80:1:90 && a.id == 10
    # end
    new_pending = []
    if !isempty(a.pending)
        # log_info(model.ticks,a.id,25,"BEFORE pending: $(length(a.pending))")
        for msgt in a.pending
            # log_info("[$(model.ticks)]($(a.id)) pending_msgt: $msgt")
            if msgt[3]
                put!(a.queue,msgt[2]) #msgt[2]: msg
            else
                push!(new_pending,msgt)
            end
         end
         a.pending = new_pending
        #  log_info(model.ticks,a.id,25,"AFTER pending: $(length(a.pending))")
    end
end

# """
#     Handle control actions when a control agent is dropped
# """
# function do_drop!(a::Agent,model)
    # TODO Check if this is useful. For time being, assuming
    # Control agent remains up but just forward messages.
#     lg = a.params[:ctl_graph]
#     lv = to_local_vertex(lg,a.id)
#     nbs = [ lg[nb,:aid] for nb in neighbors(lg,lv) ]

#     #Move connections to neighbors
#     for nb in nbs
#         nbs_nb = setdiff(nbs,[nb])
#         body = Dict(new_nbs=>nbs_nb,dp_aid=>a.id)
#         nb_msg = AGMessage(next_amid!(model),model.ticks,a.id,nb,NEW_NB,body)
#         send_msg!(nb,nb_msg_model)
#     end
    
    
#     #remove edges from "actual" control graph
#     soft_remove_vertex!(model.ctl_graph,a.id)
    
#     #TODO it can't set agent down, needs to check if any controlled asset is up.
#     set_down!(a) 
# end

"""
Set controller agent down
"""
function set_down!(a::Agent)
    state = get_state(a)
    state.up = false
    set_state!(a,state)
end
"""
    It processes OF msg sent by controlled NE  to
    remove a given port from its graph
    This is done by the agent controlling the neighbour of a dropped node
"""
function port_delete_handler(a::Agent,msg::OFMessage,model)
    # init_agent!(a,model)
    remove_drop_sne!(a,msg.data,model.ticks)        
    # if model.ctrl_model != GraphModel(1)

    #     for ctl_p in a.ctl_paths
    #         log_info(model.ticks,a.id," ctl_p: $ctl_p")
    #         propagate_drop_sne!(a,msg.data,ctl_p,model)
    #     end
        
    # # else
    #     # lv = to_local_vertex(a.params[:ntw_graph],msg.data)
    #     # a.params[:ntw_graph] = soft_remove_vertex!(a.params[:ntw_graph],lv)

    # end
#flows involving this NE should have been deleted at NE 
end

"""
Check confindence of a path
@Deprecated (for time being)
"""
function do_confidence_check!(a,model)
#TODO
end

function calculate_metrics_step!(a::Agent,model::ABM)
end