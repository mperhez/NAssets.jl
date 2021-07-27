function get_map_shape_local()
    
    zipfile = data_dir*"Regions_(December_2017)_Boundaries.zip"
    r = ZipFile.Reader(zipfile)
    for f in r.files
        println("Filename: $(f.name)")
        open(f.name, "w") do io
            write(io,read(f))
        end
    end
    close(r)
end

function load_map(fname::String)
    return Shapefile.shapes(Shapefile.Table(fname))
end