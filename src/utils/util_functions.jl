function get_random(seed,sequence,distribution)
    Random.seed!(seed)
    return last(rand(distribution,sequence))
end
# function get_random(seed,sequence,list)
#     Random.seed!(seed)
#     return last(rand(list,sequence))
# end
function get_random(seed,sequence)
    return get_random(seed,sequence,Uniform())
end

"""
Helper function that checks if x value is in vector V
"""
is_in(x::Int64,V) = x in V

"""
    Checks if a directory exists, otherwise create it.
"""
function check_create_dir!(dir_name)
    tdir = split(dir_name,"/")
    dirc = ""

    for tk=1:length(tdir)
        dirc *= tdir[tk] * "/"
        if !isdir(dirc)
            mkdir(dirc) 
        end
    end
end

"""
Helper function to create a csv file template out of a given config object passed
"""
function create_csv_template(file_name,config)
    open(file_name * ".csv","w") do io
        writedlm(io,vcat(reshape(collect(keys(config)),1,length(config)),reshape(collect(values(config)),1,length(config))),";")
    end
end

"""
Find paths such as the network is covered according to passed coverage.
"""
function find_paths_by_seed(seed,g::SimpleGraph,coverage::Float64)
    Random.seed!(seed)
    cc = closeness_centrality(g)
    cci = sort([ (i,cc[i]) for i=1:length(cc) ],by=last,rev=true)

    pending = cci 
    cp =[]

        while length(pending) >= (1- coverage) * nv(g)
            pending_i = [ first(p) for p in pending]
            
            #node with the most closeness_centrality
            s = first(first(pending))

            #max distance to any other pending node
            ds = gdistances(g,s)
            sds = sort([(i,ds[i]) for i=1:length(ds) if i in pending_i ],by=last,rev=true)
            d = first(first(sds))
            
            #shortest path between these two nodes
            sp = first(yen_k_shortest_paths(g,s,d).paths)
            push!(cp, sp)

            #remove nodes in the shortest path from pending list
            pending_i = collect(setdiff([ first(p) for p in pending ],Set(sp)))
            # println(pending_i)
            pending = [ p for p in pending  if first(p) in pending_i ]
        end
    return cp
end