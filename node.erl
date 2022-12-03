-module(node).
-import(lists,[max/1]).
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

    Table = [{0,list_to_atom(integer_to_list(rand:uniform(N)))} || _ <- lists:seq(1, V)],
    rps(ID,Table).

rps(ID, Table) ->
    %Increase Age by one
    TableInc = [{Age+1,Node}||{Age,Node} <- Table],
    %Select older node (Q)
    {AgeQ,Q} = max(TableInc),
    %Select l-1 other random entries of the table
    [{_,L}] = ets:lookup(x, l),
    ShuffledT = [Y||{_,Y} <- lists:sort([ {rand:uniform(), N} || N <- TableInc])],
    io:format("Table ~w~n", [ShuffledT]),
    REntries = lists:sublist(ShuffledT, L-1),
    io:format("Table ~w~n", [REntries]),
    %Reset to zero the age of Q
    Table2 = lists:delete({AgeQ,Q}, TableInc),
    TableOK = Table2 ++ [{0,Q}],
    receive
        {avdertise, From, Entries} ->
            io:format("received ~w~n ", [Entries]),
            NewTable = TableOK ++ [{From,0}],
            rps(ID, NewTable);
        showtable ->
            io:format("Table ~w~n", [TableOK]),
            rps(ID, TableOK);
        stop ->
            io:format("closing down~n", []),
            ok
    end.