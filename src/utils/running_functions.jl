function single_run_with_logging(config)
    run_label = get_run_label(config)
    io = stdout
    logger = MessageOnlyLogger(io,Logging.Info)
    with_logger(logger) do
        start_time = now()
        log_info("$start_time: start $run_label")
        single_run(config)
        end_time = now()
        log_info("$end_time: end $run_label. Elapsed: $((end_time - start_time))")
    end
end

function single_run_with_file_logging(config)
    
    run_label = get_run_label(config)

    io = open( data_dir * run_label * "_log.log", "w+")
    # logger = SimpleLogger(io,Logging.Debug)

    # logger = FormatLogger() do io, args
    #     log_info(io, args._module, " | ", "[", args.level, "] ", args.message)
    # end;
    # logger = MinLevelLogger(FileLogger(run_label* "_testing.log"), Logging.Info) |> simplified_logger
    
    # logger = OneLineTransformerLogger(MinLevelLogger(FileLogger( data_dir * run_label* ".log"), Logging.Info)#|> OneLineTransformerLogger
    # logger = SimpleLogger(stdout, Logging.Debug) |> OneLineTransformerLogger
    logger = MessageOnlyLogger(io,Logging.Info)
    with_logger(logger) do
        start_time = now()
        log_info("$start_time: start $run_label")
        single_run(config)
        end_time = now()
        log_info("$end_time: end $run_label. Elapsed: $((end_time - start_time))")
    end
    flush(io)
    close(io)
end
