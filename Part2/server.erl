-module(server).
-import(node, [initformeasure/1]).
-import(biznode, [initbiz/1]).
-export([getTimeSleep/0, startmetrics/6, flemme/0, start/3, startmany/1, enteringchurn/1, enteringchurn/3, startexitchurn/1, churnhelper/2, exitchurn/3, discovery/2, startwithbyzantine/4]).

getTimeSleep() -> 1000.

flemme() ->
    startwithbyzantine(10, 2, 2, 2).

startmetrics(TotalNumberOfNodes, L, V, ByzNodes, Inc, MaxByzNodes) ->
    if  ByzNodes =< MaxByzNodes ->
        io:fwrite("Running with ~w Byz ~n", [ByzNodes]),
        startwithbyzantine(TotalNumberOfNodes-ByzNodes, L, V, ByzNodes),
        startmetrics(TotalNumberOfNodes, L, V, ByzNodes+Inc, Inc, MaxByzNodes);
        true ->
            io:fwrite("Finished ~w ~w ~n", [ByzNodes, MaxByzNodes]),
            ok
    end.

start(N, L, V) ->
    ets:new(x, [set,public,named_table]),
    ets:insert(x, {n, N}),
    ets:insert(x, {l, L}),
    ets:insert(x, {v, V}),
    {ok, FileDiscovery} = file:open("discoveryrate.csv", [write]),
    {ok, FileChurn} = file:open("Churn.csv", [write]),
    {ok, FileChurn2} = file:open("Churn2.csv", [write]),
    io:fwrite(FileDiscovery, "~p,~p~n", ["ID", "Table"]),
    io:fwrite(FileChurn, "~p,~p~n", ["ID", "Count"]),
    io:fwrite(FileChurn2, "~p,~p~n", ["ID", "Count"]),
    ets:insert(x, {filed, FileDiscovery}),
    ets:insert(x, {filec, FileChurn}),
    ets:insert(x, {filec2, FileChurn2}),
    ets:insert(x, {existingn, []}),
    startmany(N).

startwithbyzantine(N, L, V, B) -> % B = Number of byzantine nodes
    ets:new(x, [set,public,named_table]),
    ets:insert(x, {n, N}),
    ets:insert(x, {l, L}),
    ets:insert(x, {v, V}),
    ets:new(b, [set,public,named_table]),
    ets:insert(b, {b, B}),
    OutputFile = string:concat("data/discoveryrate_", 
        string:concat(integer_to_list(N),
        string:concat("_",
        string:concat(integer_to_list(L),
        string:concat("_",
        string:concat(integer_to_list(V),
        string:concat("_", 
        string:concat(integer_to_list(B), ".csv")))
    ))))),
    {ok, FileDiscovery} = file:open(OutputFile, [write]),
    {ok, FileChurn} = file:open("Churn.csv", [write]),
    {ok, FileChurn2} = file:open("Churn2.csv", [write]),
    io:fwrite(FileDiscovery, "~p,~p~n", ["ID", "Table"]),
    io:fwrite(FileChurn, "~p,~p~n", ["ID", "Count"]),
    io:fwrite(FileChurn2, "~p,~p~n", ["ID", "Count"]),
    ets:insert(x, {filed, FileDiscovery}),
    ets:insert(x, {filec, FileChurn}),
    ets:insert(x, {filec2, FileChurn2}),
    ets:insert(x, {existingn, []}),
    ets:insert(b, {biznodes, []}),
    startmany(N),
    startmanybiz(B, N),
    show_round(0).

show_round(C) ->
    MAX_ROUNDS=80,
    if C > MAX_ROUNDS ->
        [{_, N}] = ets:lookup(x, n),
        [{_, B}] = ets:lookup(b, b),
        stopall(N+B);
        true ->
            io:fwrite("Round : ~w~n", [C]),
            timer:sleep(getTimeSleep()),
            show_round(C + 1)
    end.

stopall(T) ->
    C = 0,
    if
        C == T ->
            timer:sleep(1000),
            ets:delete(x),
            ets:delete(b),
            io:fwrite("All node shutted down~n");
        true ->
            list_to_atom(integer_to_list(T)) ! stop,
            stopall(T-1)
    end.

startmanybiz(B, N) ->
    if 
        0 == B  ->
            io:fwrite("All biz node created~n");
        true ->
            createbiznode(list_to_atom(integer_to_list(B + N))),
            startmanybiz(B - 1, N)
    end.

createbiznode(ID) -> 
    [{_,BizNodes}] = ets:lookup(b,biznodes),
    AllNodes = [ID] ++ BizNodes,
    ets:insert(b,{biznodes, AllNodes}),
    PID = spawn(biznode, initbiz, [ID]),
    io:fwrite("Created biz node ~w~n", [ID]),
    register(ID, PID),
    io:fwrite("Created OK ~w~n", [ID]).

startmany(N) ->
    C = 0,
    if
        C == N ->
            io:fwrite("All node created~n");
        true ->
            createnode(list_to_atom(integer_to_list(N))),
            startmany(N-1)
    end.

createnode(ID) ->
    [{_,ENodes}] = ets:lookup(x,existingn),
    ExistingNodes = [ID] ++ ENodes,
    ets:insert(x,{existingn, ExistingNodes}),
    register(ID, spawn(node, initformeasure, [ID])),
    io:fwrite("Created node ~w~n", [ID]).

discovery(ID, Table) ->
    [{_,FileD}] = ets:lookup(x, filed),
    T = [Y||{_,Y} <- Table],
    io:fwrite(FileD, "~p,\"~p\"~n", [atom_to_list(ID), T]).

startexitchurn(N) ->
    if
        N < 1 ->
            ok;
        true ->
            [{_,ExistingNodes}] = ets:lookup(x, existingn),
            Nodes = [list_to_integer(atom_to_list(X))||X <- ExistingNodes],
            Tostop = lists:max(Nodes),
            io:format("Start measure exit churn of Node ~p~n",[integer_to_list(Tostop)]),
            list_to_atom(integer_to_list(Tostop)) ! exitchurn,
            timer:sleep(2000),
            startexitchurn(N-1)
    end.


exitchurn(ID, C, List) ->
    [{_,FileC}] = ets:lookup(x, filec),
    T = [churnhelper(ID, Node)||Node <- List],
    T2 = [Bool||Bool <- T , Bool==false],
    if 
        length(List) == 0 ->
            io:format("~p,~p~n", [atom_to_list(ID), integer_to_list(0)]),
            io:fwrite(FileC, "~p,~p~n", [atom_to_list(ID), integer_to_list(0)]);
        length(T2)/length(T) > 0.75 ->
            io:format("~p,~p~n", [atom_to_list(ID), C]),
            io:fwrite(FileC, "~p,~p~n", [atom_to_list(ID), C]);
        true ->
            io:format("More turn for exit churn of Node ~p~n",[atom_to_list(ID)]),
            receive
                stop ->
                    [{_,ExistingNodes}] = ets:lookup(x, existingn),
                    ets:insert(x, {existingn,ExistingNodes--[ID]}),
                    io:format("closing down Node ~p~n", [ID]),
                    ok
                after getTimeSleep() ->
                    io:format("~p,~p,~p~n", [atom_to_list(ID), length(List),length(T2)]),
                    exitchurn(ID,C+1,List)
            end
    end.

enteringchurn(N) ->
    if
        N > 0 ->
            [{_,ExistingNodes}] = ets:lookup(x, existingn),
            Nodes = [list_to_integer(atom_to_list(X))||X <- ExistingNodes],
            Tostart = lists:max(Nodes)+1,
            createnode(list_to_atom(integer_to_list(Tostart))),
            io:format("Start measure enter churn of Node ~p~n",[integer_to_list(Tostart)]),
            ets:insert(x, {n, Tostart}),
            Atom = list_to_atom(integer_to_list(100000+Tostart)),
            register(Atom, spawn(server, enteringchurn, [list_to_atom(integer_to_list(Tostart)), 0, []])),
            timer:sleep(2000),
            enteringchurn(N-1);
        true ->
            ok
    end.

enteringchurn(ID, C, HistoryT) ->
    [{_,FileC}] = ets:lookup(x, filec2),
    [{_,ExistingNodes}] = ets:lookup(x, existingn),
    T = [Node||Node <- ExistingNodes, churnhelper(ID, Node)==true],
    T2 = lists:usort(HistoryT ++ T),
    if 
        length(T2)/length(ExistingNodes) > 0.75 ->
            io:format("Enter Churn measure finished for ~p - ~p~n",[atom_to_list(ID), C]),
            io:fwrite(FileC, "~p,~p~n", [atom_to_list(ID), C]);
        true ->
            io:format("More turn for enter churn of Node ~p - ~p~n",[atom_to_list(ID),T2]),
            timer:sleep(5000),
            enteringchurn(ID,C+1,T2)
    end.

churnhelper(ID, I) ->
    [{_,Table}] = ets:lookup(x, I),
    Table2 = [X || {_,X} <- Table],
    lists:member(ID, Table2).