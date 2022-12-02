-module(node).
-export([start/0, stop/0, init/0, nodem/3, showtable/0]).

start() ->
    register(node, spawn(node, init, [])).

init() ->
    nodem([],[],[]).

stop() ->
    node ! stop,
    unregister(node).

showtable() ->
    node ! showtable.

nodem(Name, Table, Ages) ->
    Ages = [X+1||{_,X} <- Ages],
    receive
        {request, From, Entries} ->
            io:format("received ~w ", [Entries]),
            NewTable = Table ++ From,
            NewAges = Ages ++ [0],
            nodem(Name, NewTable, NewAges);
        showtable ->
            io:format("table ~w~n", [Table]),
            io:format("Age ~w~n", [Ages]),
            nodem(Name, Table, Ages);
        stop ->
            io:format("closing down~n", []),
            ok
    end.