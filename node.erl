-module(node).
-export([start/3, start/1, createnode/1, init/1, rps/2]).

start(N, L, V) ->
    ets:new(x, [set,public,named_table]),
    ets:insert(x, {n, N}),
    ets:insert(x, {l, L}),
    ets:insert(x, {v, V}),
    start(N).

start(N) ->
    C = 0,
    if
        C == N ->
            io:fwrite("All node created~n");
        true ->
            createnode(list_to_atom(integer_to_list(N))),
            start(N-1)
    end.

createnode(ID) ->
    register(ID, spawn(node, init, [ID])).

init(ID) ->
    N1 = ets:lookup(x, n),
    V1 = ets:lookup(x, v),
    [{_, N}] = N1,
    [{_, V}] = V1,

    Table = [{list_to_atom(integer_to_list(rand:uniform(N))),0} || _ <- lists:seq(1, V)],
    rps(ID,Table).

rps(ID, Table) ->
    TableInc = [{Node,X+1}||{Node,X} <- Table],
    receive
        {request, From, Entries} ->
            io:format("received ~w~n ", [Entries]),
            NewTable = TableInc ++ {From,0},
            rps(ID, NewTable);
        showtable ->
            io:format("Table ~w~n", [TableInc]),
            rps(ID, TableInc);
        stop ->
            io:format("closing down~n", []),
            ok
    end.