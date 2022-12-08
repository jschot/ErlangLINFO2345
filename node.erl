-module(node).
-import(lists,[max/1]).
-export([start/3, start/1, createnode/1, init/1, rps/1, rcv/1, stop/1]).

start(N, L, V) ->
    ets:new(x, [set,public,named_table]),
    ets:insert(x, {n, N}),
    ets:insert(x, {l, L}),
    ets:insert(x, {v, V}),
    {ok, File} = file:open("discoveryrate.csv", [write]),
    io:fwrite(File, "~p,~p~n", ["ID", "Table"]),
    ets:insert(x, {file, File}),
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

stop(N) ->
    C = 0,
    if
        C == N ->
            [{_,File}] = ets:lookup(x, file),
            file:close(File),
            io:fwrite("All node shutted down~n");
        true ->
            list_to_atom(integer_to_list(N)) ! stop,
            stop(N-1)
    end.

createnode(ID) ->
    register(ID, spawn(node, init, [ID])).

init(ID) ->
    N1 = ets:lookup(x, n),
    V1 = ets:lookup(x, v),
    [{_, N}] = N1,
    [{_, V}] = V1,

    Table = lists:usort(lists:delete({0,ID},[{0,list_to_atom(integer_to_list(rand:uniform(N)))} || _ <- lists:seq(1, V)])),
    ets:insert(x, {ID, Table}),
    timer:apply_interval(5000, node, rps, [ID]),
    rcv(ID).

discovery(ID, Table) ->
    [{_,File}] = ets:lookup(x, file),
    T = [Y||{_,Y} <- Table],
    io:fwrite(File, "~p,\"~p\"~n", [atom_to_list(ID), T]).


rps(ID) ->
    [{_,Table}] = ets:lookup(x, ID),
    %Increase Age by one
    TableInc = [{Age+1,Node}||{Age,Node} <- Table],
    %Select older node (Q)
    {AgeQ,Q} = max(TableInc),
    %Select l-1 other random entries of the table
    [{_,L}] = ets:lookup(x, l),
    ShuffledT = [Y||{_,Y} <- lists:sort([{rand:uniform(), N} || N <- TableInc])],
    REntries = lists:sublist(ShuffledT, L-1),
    %Reset to zero the age of Q
    Table2 = lists:delete({AgeQ,Q}, TableInc),
    TableOK = Table2 ++ [{0,Q}],
    ets:insert(x, {ID, TableOK}),
    discovery(ID, TableOK),
    %Send the l-1 entries to Q
    Q ! {advertise, ID, REntries}.

rcv(ID) ->
    receive
        {advertise, From, Entries} ->
            [{_,TableOK}] = ets:lookup(x, ID),
            [{_,L}] = ets:lookup(x, l),
            %Q sends back a subset of the l-1 entry of its table
            ShuffledT2 = [Y||{_,Y} <- lists:sort([ {rand:uniform(), N} || {_,N} <- TableOK])],
            REntries2 = lists:sublist(ShuffledT2, L-1),
            From ! {response, Entries, REntries2},
            rcv(ID);
        {response, SendedPrvsly, Entries} ->
            %Remove entries pointing to P from the subset send by Q
            EntriesWoP = lists:delete(ID, Entries),
            %Remove already present entries in P's view from the subset send by Q
            [{_,TableOK}] = ets:lookup(x, ID),
            TableEntriesP = [Y||{_,Y} <- TableOK],
            EntriesQ = EntriesWoP -- TableEntriesP,
            %Update P's view with the remaining entries commencing by empty entries of P and after by replacing entries sent to Q.
            %Each new entry is set with an age of zero.
            EntriesToAdd = [{0,Y}||Y <- EntriesQ],
            NewTable = TableOK ++ EntriesToAdd,
            [{_,V}] = ets:lookup(x, v),
            if 
                length(NewTable)-V > 0 ->
                    TodeleteinNT = lists:usort([{Age,Y}||{Age,Y}<-NewTable, {_,X}<-SendedPrvsly , X==Y]),
                    NewTable2 = NewTable -- TodeleteinNT,
                    if
                        V-length(NewTable2) > 0 ->
                            NewTable3 = NewTable2 ++ lists:sublist(SendedPrvsly, V-length(NewTable2)),
                            ets:insert(x, {ID, NewTable3});
                        true ->
                            ets:insert(x, {ID, NewTable2})
                    end;
                true ->
                    ets:insert(x, {ID, NewTable})
            end,
            rcv(ID);
        showtable ->
            [{_,TableOK}] = ets:lookup(x, ID),
            io:format("Table ~w~n", [TableOK]),
            rcv(ID);
        stop ->
            io:format("closing down~n", []),
            ok
    end.