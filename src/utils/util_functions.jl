function get_random(seed,sequence,distribution)
    if seed >= 0
        Random.seed!(seed)
    end
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