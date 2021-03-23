


function push_msg!(a::Agent,msg::OFMessage)
    put!(a.state.queue,msg)
end

function push_pending!(a::AbstractAgent,msg::OFMessage)
    push!(a.pending,msg)
end



function send_msg!(receiver::Int64,msg::OFMessage,model)
    ag = getindex(model,receiver)
    #TODO implement links and get delay of link in ticks
    queue = typeof(ag) == SimNE ? ag.queue : ag.state.queue
    println("Sent to $receiver msg: $msg")
    put!(queue,msg)
end 



function install_flows!(in_dpid,in_port_start,path,model)
    println("install flow: $(in_dpid) - $(in_port_start) - $(path)")
    if !isempty(path)
        pairs = diag([j == i + 1 ? (path[3][i],path[3][j]) : nothing for i=1:size(path[3],1)-1, j=2:size(path[3],1)])
        
        prev_eid = path[1]
        for p in pairs
            sne = getindex(model,p[1])
            prev_sne = getindex(model,prev_eid)
            port_dst = filter(x->x[2]=="s$(p[2])",get_port_edge_list(sne))[1]
            out_port = port_dst[1]
            in_port = p[1] == path[1] ? in_port_start : filter(x->x[2]=="s$(prev_eid)",get_port_edge_list(sne))[1][1]
            r_src = path[1]
            r_dst = path[2]
            
            fw = Flow(sne.id,MRule(string(in_port),string(r_src),string(r_dst)),[out_port],OFS_Output)
            #(ticks,pkt,sne_src,sne_dst)->forward(ticks,pkt,sne_src,sne_dst)
            println("[$(model.ticks)] {A} Installing flow: $(p[1]) - $(fw.match_rule)")
            push_flow!(sne,fw)
            prev_eid = sne.id
        end
    else
        sne = getindex(model,in_dpid)
        #TODO how to make the rule to be regardless of port in
        fw =Flow(in_dpid,MRule("*","*",string(in_dpid)),[0],OFS_Output)
        #(ticks,pkt,src_sne)->forward(ticks,pkt,src_sne)
        println("[$(model.ticks)]  {B} Installing flow to $(in_dpid): $(fw.match_rule)")
        push_flow!(sne,fw)
    end
end

function install_flow!(a::Agent,path::Array{Int64,1},model::ABM,msg::OFMessage=nothing)
    # find which ones of path I am controlling
    es = get_controlled_assets(a.id,model)
    lpath = isempty(path) ? es : path 
    eois = intersect(es,lpath)
    lpath = [ v for v in lpath]
    println("($(a.id)) +install_flow! => path: $path -- es: $es -- eois: $eois")
    for e in eois
         i = length(lpath) > 1 ? first(indexin(e,lpath)) : 1
         sne = getindex(model,e)
         i_prev = i > 1 ? i - 1 : i
         
         ports = get_port_edge_list(sne)
 
         println("[$(model.ticks)]{$(a.id)}($(sne.id)) - ports: $(ports) - i: $i - i_prev: $i_prev - e: $e -- lpath : $lpath")
         #Regardless of where the traffic comes
         r_src = "*" #string("h",first(lpath)) 
         r_dst = last(lpath)
         in_port = 0
         if i == 1
             #of_msg₀ = first(filter(ofm -> ofm.id == of_mid,a.pending))
             in_port = msg.in_port
             #TODO of_msg remove from pending
         else
             #in_port = first(filter(p->parse(Int,p[2][2:end]) == lpath[i_prev],ports))
             in_port = first([ first(p) for p in ports if parse(Int,p[2][2:end]) == lpath[i_prev]])
             println("FIltered equal to: prev: $(lpath[i_prev]) in: $in_port")
         end
         out_port = 0
         
         if i < length(lpath)
             out_port = first(first(filter(p->parse(Int,p[2][2:end]) == lpath[i+1],ports)))
         end
 
         flow = Flow(  sne.id
                 ,MRule(string(in_port)
                 ,string(r_src)
                 ,string(r_dst))
                 ,[out_port]
                 ,OFS_Output)
         msg = OFMessage(next_ofmid!(model), model.ticks,e,1,OFPR_ADD_FLOW,flow)
         send_msg!(e,msg,model)
         
    end
end

function process_msg!(a::Agent,msg::OFMessage,model)
    println("[$(model.ticks)]($(a.id)) -> processing $(msg.reason) ==> $msg")
    
    @match msg.reason begin
        Ofp_Protocol(1) =>  
                        begin
                            #println("[$(model.ticks)]($(a.id)) -> match one")
                            #previous = filter(x->x[1]==msg.id,a.of_started)
                            #if isempty(previous) || (model.ticks - last(first(previous))) < model.ofmsg_reattempt
                            in_packet_handler(a,msg,model)
                            #elseif  (model.ticks - last(first(previous))) < model.ofmsg_reattempt
                                #return package to queue as it does not know what to do with it
                            #    push!(a.pending,msg)
                           # end
                        
                        end
        Ofp_Protocol(2) => 
                            begin
                                #println("[$(model.ticks)]($(a.id)) -> match two")
                                port_delete_handler(a,msg,model)
                            end
                            
        _ => begin
            println("[$(model.ticks)]($(a.id)) -> match default")
            end
    end
end

"""
msg: SimNE.id, in_port, DPacket
"""
function in_packet_handler(a::Agent,msg::OFMessage,model)

    println("[$(model.ticks)]($(a.id)) Processing msg: $msg")
    
    path::Array{Int64,1} = []
    found = false
   
    if msg.dpid != dst
        path = do_query!(msg,a,model)
        found = isempty(path) ? false : true
    else
        found = true
    end
   
    println("[$(model.ticks)]($(a.id)) msg-> $(msg), path ==> $(path)")
   
    if found 
        #install_flows!(msg.dpid,msg.in_port,path,model) 
        println("[$(model.ticks)]($(a.id)) in pkt handler: path $path")
        install_flow!(a,path,model,msg)
    else
        #add to pending list only if has not been
        #started already (no reprocessing)
        started = filter(m->first(m) == msg.id,a.of_started)
        if isempty(started)
            push!(a.pending,(model.ofmsg_reattempt,msg))
        end
    end
    
    push!(a.of_started,(msg.id,model.ticks))
    
    # TODO
    # Need to implement asynchronous msgs
    # Need to control when msgs come and come because of being pushed to pending
    # If path is not found, it has to keep track of pending OFMessage if Any
    # and once any path is received it should install the flows for the path
    
end


# function do_query!(a::Agent,model,of_mid::Int64,query::Tuple{Int64,Int64})
#     lg = a.params[:ntw_graph]
#     found = query_path(lg,query)
#     path = []
    
#     previous = filter(x->x[1]==of_mid,a.of_started)
#     println("[$(model.ticks)]($(a.id)) do_query! => $(found) -- previous $previous")
#     if isempty(found.paths) &&  isempty(previous)# forward to neighbor controllers
       
#        ntw_edgel = [ e for e in edges(lg) if src(e) <  dst(e) ]
#        ntw_equiv = [(v,lg[v,:eid]) for v in vertices(lg)]
#        nbody = Dict(:query=>query,:trace=>[a.id],:ntw_edgel => ntw_edgel, :ntw_equiv=>ntw_equiv, :of_mid=>of_mid)
#        msg_template = AGMessage(-1,model.ticks,a.id,-1,QUERY_PATH,nbody)
#        send_to_nbs!(msg_template,a,model)
#     else
#         path = isempty(found.paths) ? [] : [a.params[:ntw_graph][v,:eid] for v in first(found.paths)]
#     end
#     return path#found.paths
# end

"""
    Initial query by controller receiving OF message
"""
function do_query!(msg::OFMessage,a::Agent,model)
   
    query = (msg.dpid,msg.data.dst)

    path = do_query(query,a)

    if isempty(path)
        lg = a.params[:ntw_graph]
        ntw_edgel = [ e for e in edges(lg) if src(e) <  dst(e) ]
        ntw_equiv = [(v,lg[v,:eid]) for v in vertices(lg)]
        trace = [a.id]
        of_mid = msg.id 
        body = Dict(:query=>query,:trace=>trace,:ntw_edgel => ntw_edgel, :ntw_equiv=>ntw_equiv, :of_mid=>of_mid)
        msg_template = AGMessage(-1,model.ticks,a.id,-1,QUERY_PATH,body)
        send_to_nbs!(msg_template,a,model)
    end
    
    return path
end

"""
    Query local calculated paths and local graph
"""
function do_query(query::Tuple{Int64,Int64},a::Agent)
    lntw_g = a.params[:ntw_graph]
    #query pre-calculated paths
    paths = filter(p-> p[1] == first(query) && p[2] == last(query) ,a.state.paths)    
    
    #println("Paths found: $paths")

    path = !isempty(paths) ? last(first(paths)) : query_path(lntw_g,query)

    #println("Path found: $path")
    
    
    return path
end

function pending_pkt_handler(a::Agent,model)
    # if model.ticks in 80:1:90 && a.id == 10
    # end
    new_pending = []
    if !isempty(a.pending)
        println("[$(model.ticks)]($(a.id)) pending: $(length(a.pending))")
        for msgt in a.pending
            println("[$(model.ticks)]($(a.id)) pending_msgt: $msgt")
            remaining = first(msgt) - 1  #msgt[1]: timeout
            if remaining <= 0 
                put!(a.state.queue,last(msgt)) #msgt[2]: msg
            else
                push!(new_pending,msgt)
            end
         end
         a.pending = new_pending
         
    end
end
