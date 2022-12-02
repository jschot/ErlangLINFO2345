-module(node).
-export([start/3, createnode/1, init/1, rps/3]).

start(N, L, V) ->
    C = 0,
    if
        C == N ->
            io:fwrite("All node created~n"),
            Globalvar = ets:new(x, []),
            ets:insert(Globalvar, {l, L}),
            ets:insert(Globalvar, {v, V});
        true ->
            createnode(list_to_atom(integer_to_list(N))),
            start(N-1,L)
    end.

createnode(ID) ->
    register(ID, spawn(node, init, [ID])).

init(ID) ->
    rps(ID,[],[]).

rps(ID, Table, Ages) ->
    Ages = [X+1||{_,X} <- Ages],
    receive
        {request, From, Entries} ->
            io:format("received ~w~n ", [Entries]),
            NewTable = Table ++ From,
            NewAges = Ages ++ [0],
            rps(ID, NewTable, NewAges);
        showtable ->
            io:format("Table ~w~n", [Table]),
            io:format("Age ~w~n", [Ages]),
            rps(ID, Table, Ages);
        stop ->
            io:format("closing down~n", []),
            ok
    end.