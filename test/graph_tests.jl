#test data
using NAssets: has_prop_vertex, isless_paths, join_subgraphs, query_paths, score_path, to_local_vertex, create_subgraph, soft_remove_vertex,  add_edges_gids!, get_subgraph, load_network_graph, find_paths_by_seed, get_end_points
using LightGraphs, MetaGraphs
@testset "Graph functions" begin 

        amg =  [0  1  1  0  0  0  0  0  0;
                1  0  0  1  0  1  0  0  0;
                1  0  0  1  1  0  0  0  0;
                0  1  1  0  0  0  1  1  0;
                0  0  1  0  0  0  0  1  0;
                0  1  0  0  0  0  1  0  0;
                0  0  0  1  0  1  0  0  1;
                0  0  0  1  1  0  0  0  1;
                0  0  0  0  0  0  1  1  0]


        mgg = MetaGraph(amg)

        [ set_prop!(mgg,v,:ptest,10-v) for v in vertices(mgg) ]

        am1 =  [0  1  1  0  0 ;
                1  0  0  1  0 ;
                1  0  0  1  1 ;
                0  1  1  0  0 ;
                0  0  1  0  0 ]


        am2 =   [0  1  1  0  0  0  0 ;
                1  0  0  1  0  0  0 ;
                1  0  0  1  0  1  0 ;
                0  1  1  0  0  0  1 ;
                0  0  0  0  0  1  0 ;
                0  0  1  0  1  0  1 ;
                0  0  0  1  0  1  0 ]

        mg1 = MetaGraph(am1)

        set_indexing_prop!(mg1,:eid)
        set_prop!(mg1,1,:eid,1)
        set_prop!(mg1,2,:eid,2)
        set_prop!(mg1,3,:eid,4)
        set_prop!(mg1,4,:eid,5)
        set_prop!(mg1,5,:eid,7)

        mg2 = MetaGraph(am2)

        set_indexing_prop!(mg2,:eid)
        set_prop!(mg2,1,:eid,2)
        set_prop!(mg2,2,:eid,3)
        set_prop!(mg2,3,:eid,5)
        set_prop!(mg2,4,:eid,6)
        set_prop!(mg2,5,:eid,7)
        set_prop!(mg2,6,:eid,8)
        set_prop!(mg2,7,:eid,9)

        # get_prop(mg1,1,:eid)

        # (tick, score)
        paths = [(10,5),(10,4),(5,5),(15,5)]
        sorted_paths = [(10, 4), (15, 5), (10, 5), (5, 5)]


        @test has_prop_vertex(9,mgg,:ptest) == true

        #is less paths
        sort(paths,lt=isless_paths) == sorted_paths


        #join graphs

        jg = join_subgraphs(mg1,mg2)

        @test collect(adjacency_matrix(jg)) == amg


        ##query paths

        pref = [2,5,8,7]

        @test first(query_paths(mg2,(2,7)).paths) == pref

        @test score_path(pref) ==  4


        @test to_local_vertex(mg1,7) == 5

        # graphplot(mg1, names = [ i for i = 1:nv(mg1)])

        eqvs = [(1,7),(2,4),(3,6),(4,3),(5,5)]

        sg1 = create_subgraph(am1,eqvs)

        @test [ last(eqv) for eqv in eqvs ] == [ get_prop(sg1,i,:eid) for i = 1:nv(sg1)]
        # graphplot(sg1, names = [ get_prop(sg1,i,:eid) for i = 1:nv(sg1)])


        sg2 = create_subgraph(edges(mg1),eqvs,:eid)

        # graphplot(sg2, names = [ get_prop(sg2,i,:eid) for i = 1:nv(sg2)])

        @test [ last(eqv) for eqv in eqvs ] == [ get_prop(sg2,i,:eid) for i = 1:nv(sg2)]

        # mg2 = MetaGraph(am2)

        #mg1 vertices
        mg1_vs = [(1,1), (2,2), (3,4), (4,5), (5,7)]
        #mg1 edges
        mg1_es = [(1,2),(1,3),(2,4),(3,4),(3,5)]

        dpn_id = 4
        grv1 = soft_remove_vertex(mg1,dpn_id)
        # oe = [(src(e),dst(e)) for e in edges(mg1)]
        grv1_es = [(1,2),(1,3),(3,5)]

        @test [(src(e),dst(e)) for e in edges(grv1)] == grv1_es
        @test [ (i,get_prop(grv1,i,:eid)) for i = 1:nv(grv1) ] == mg1_vs


        # graphplot(grv1, names = [ get_prop(grv1,i,:eid) for i = 1:nv(grv1)])

        # graphplot(mg1, names = [ get_prop(mg1,i,:eid) for i = 1:nv(mg1)])
        # graphplot(mg2, names = [ get_prop(mg2,i,:eid) for i = 1:nv(mg2)])

        #add egdes gids

        #list of vertex (lv,gv)
        # [(v,get_prop(mg1,v,:eid)) for v in vertices(mg1)] 
        # [(src(e),dst(e)) for e in edges(mg1)] 
        new_gvs = [1,5]
        mg1_ne = add_edges_gids!(mg1,5,new_gvs,:eid)

        ne_lst = [(src(e),dst(e)) for e in edges(mg1_ne)] 
        @test length(ne_lst) == 7
        @test ne_lst == sort(vcat(mg1_es,[(1,5),(4,5)]))


        # get_graph
        # minimal test as this is helper function calling library functions from elsewhere.
        @show pwd()
        mg1_csv = get_graph(123,5,GraphModel(0);adj_m_csv="data/test/in/am1_csv.csv",sep=';')

        @test [ v for v in vertices(mg1_csv) ] == [ v[1] for v in mg1_vs ]
        @test [ (src(e),dst(e)) for e in edges(mg1_csv) ] == mg1_es

        nodes = [8,9]
        sg_vs = 5:9
        sg_es = [(5,6),(5,8),(6,9),(7,8),(8,9)]
        id_prop = :eid
        mg1_sg = get_subgraph(mg2,nodes,id_prop)

        @test sort([ get_prop(mg1_sg,v,:eid) for v in vertices(mg1_sg) ]) == [ v for v in sg_vs ]
        #sorted edges
        @test sort([ (t[1],t[2]) for t in [sort([get_prop(mg1_sg,src(e),:eid),get_prop(mg1_sg,dst(e),:eid)]) for e in edges(mg1_sg) ]]) == sg_es


        mg1_lng = load_network_graph(mg1_csv)
        @test get_prop(mg1_lng,5,:eid) == "eid5"

        sg2 = SimpleGraph(am2)


        ### find paths

        paths042_e = [[3, 1, 2]]
        paths100_e = [paths042_e[1],[4, 7, 6, 5]]
        paths042 = find_paths_by_seed(123,sg2,0.42)

        paths100 = find_paths_by_seed(123,sg2,1.)


        @test paths042_e == paths042
        @test paths100_e == paths100

        paths100_eeps = [(3,2),(4,5)]
        paths100_eps = get_end_points(123,sg2,1.)
        @test paths100_eps == paths100_eeps

        # graphplot(mg1_sg, names = [ get_prop(mg1_sg,i,:eid) for i = 1:nv(mg1_sg)])
        # graphplot(mg1, names = [ get_prop(mg1,i,:eid) for i = 1:nv(mg1)])
end


