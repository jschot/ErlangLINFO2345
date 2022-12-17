-module(node).
-import(server,[getTimeSleep/0, discovery/2, exitchurn/3, churnhelper/2]).
-export([start/1, start/3, init/1, rps/1, rpswithdiscovery/1, rcv/1, stop/1, initformeasure/1]).

start(N, L, V) ->
    ets:new(x, [set,public,named_table]),
    ets:insert(x, {n, N}),
    ets:insert(x, {l, L}),
    ets:insert(x, {v, V}),
    ets:insert(x, {existingn, []}),
    startmany(N).

startmany(N) ->
    C = 0,
    if
        C == N ->
            io:fwrite("All node created~n");
        true ->
            createnode(list_to_atom(integer_to_list(N))),
            startmany(N-1)
    end.

start(N) ->
    createnode(list_to_atom(integer_to_list(N))),
    io:fwrite("Node created~n").

stop(N) ->
    C = 0,
    if
        C == N ->
            timer:sleep(1000),
            ets:delete(x),
            io:fwrite("All node shutted down~n");
        true ->
            list_to_atom(integer_to_list(N)) ! stop,
            stop(N-1)
    end.

createnode(ID) ->
    [{_,ENodes}] = ets:lookup(x,existingn),
    ExistingNodes = [ID] ++ ENodes,
    ets:insert(x,{existingn, ExistingNodes}),
    register(ID, spawn(node, init, [ID])).

init(ID) ->
    N1 = ets:lookup(x, n),
    V1 = ets:lookup(x, v),
    [{_, N}] = N1,
    [{_, V}] = V1,

    T = lists:delete({0,ID},[{0,list_to_atom(integer_to_list(rand:uniform(N)))} || _ <- lists:seq(1, V)]),
    ShuffledT = [Y||{_,Y} <- lists:sort([{rand:uniform(), X} || X <- T])],
    Table = lists:sublist(ShuffledT, V),
    ets:insert(x, {ID, Table}),
    timer:apply_interval(getTimeSleep(), node, rps, [ID]),
    rcv(ID).

initformeasure(ID) ->
    N1 = ets:lookup(x, n),
    V1 = ets:lookup(x, v),
    [{_, N}] = N1,
    [{_, V}] = V1,

    T = lists:delete({0,ID},[{0,list_to_atom(integer_to_list(rand:uniform(N)))} || _ <- lists:seq(1, V)]),
    ShuffledT = [Y||{_,Y} <- lists:sort([{rand:uniform(), X} || X <- T])],
    Table = lists:sublist(ShuffledT, V),
    ets:insert(x, {ID, Table}),
    timer:apply_interval(getTimeSleep(), node, rpswithdiscovery, [ID]),
    rcv(ID).

rps(ID) ->
    [{_,Table}] = ets:lookup(x, ID),
    %Increase Age by one
    TableInc = [{Age+1,Node}||{Age,Node} <- Table],
    %Select older node (Q)
    {AgeQ,Q} = lists:max(TableInc),
    %Select l-1 other random entries of the table
    [{_,L}] = ets:lookup(x, l),
    ShuffledT = [Y||{_,Y} <- lists:sort([{rand:uniform(), N} || N <- TableInc])],
    REntries = lists:sublist(ShuffledT, L-1) ++ [{0,ID}],
    %Reset to zero the age of Q
    Table2 = lists:delete({AgeQ,Q}, TableInc),
    TableOK = Table2 ++ [{0,Q}],
    ets:insert(x, {ID, TableOK}),
    %Send the l-1 entries to Q
    Q ! {advertise, ID, REntries}.

rpswithdiscovery(ID) ->
    [{_,Table}] = ets:lookup(x, ID),
    %Increase Age by one
    TableInc = [{Age+1,Node}||{Age,Node} <- Table],
    io:fwrite("TABLE : ~w~n", [TableInc]),
    %Select older node (Q)
    {AgeQ,Q} = lists:max(TableInc),
    %Select l-1 other random entries of the table
    [{_,L}] = ets:lookup(x, l),
    ShuffledT = [Y||{_,Y} <- lists:sort([{rand:uniform(), N} || N <- TableInc])],
    REntries = lists:sublist(ShuffledT, L-1) ++ [{0,ID}],
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
            %Remove entries pointing to Q from the subset send by P
            EntriesWoAge = [Y||{_,Y} <- Entries],
            EntriesWoP = lists:delete(ID, EntriesWoAge),
            [{_,TableOK}] = ets:lookup(x, ID),
            %Remove already present entries in Q's view from the subset send by P
            TableEntriesP = [Y||{_,Y} <- TableOK],
            EntriesQ = EntriesWoP -- TableEntriesP,
            [{_,L}] = ets:lookup(x, l),
            %Q sends back a subset of the l-1 entry of its table
            ShuffledT2 = [Y||{_,Y} <- lists:sort([ {rand:uniform(), N} || {_,N} <- TableOK])],
            REntries2 = lists:sublist(ShuffledT2, L),
            From ! {response, Entries, REntries2},
            %Update Q's view with the remaining entries commencing by empty entries of P and after by replacing entries sent to Q.
            %Each new entry is set with an age of zero.
            EntriesToAdd = [{0,Y}||Y <- EntriesQ],
            NewTable = TableOK ++ EntriesToAdd,
            [{_,V}] = ets:lookup(x, v),
            if 
                length(NewTable)-V > 0 ->
                    TodeleteinNT = lists:usort([{Age,Y}||{Age,Y}<-NewTable, X<-REntries2 , X==Y]),
                    NewTable2 = NewTable -- TodeleteinNT,
                    if
                        V-length(NewTable2) > 0 ->
                            NewTable3 = NewTable2 ++ lists:sublist(REntries2, V-length(NewTable2)),
                            ets:insert(x, {ID, NewTable3});
                        length(NewTable2) > V ->
                            NewTable3 = lists:sublist(NewTable2, V),
                            ets:insert(x, {ID, NewTable3});
                        true ->
                            ets:insert(x, {ID, NewTable2})
                    end;
                true ->
                    ets:insert(x, {ID, NewTable})
            end,
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
                    TodeleteinNT = lists:usort([{Age,Y}||{Age,Y}<-NewTable, {_,X}<-SendedPrvsly, X==Y]),
                    NewTable2 = NewTable -- TodeleteinNT,
                    if
                        V-length(NewTable2) > 0 ->
                            NewTable3 = NewTable2 ++ lists:sublist(SendedPrvsly, V-length(NewTable2)),
                            ets:insert(x, {ID, NewTable3});
                        length(NewTable2) > V ->
                            NewTable3 = lists:sublist(NewTable2, V),
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
        exitchurn ->
            [{_,ExistingNodes}] = ets:lookup(x, existingn),
            ets:insert(x, {existingn,ExistingNodes--[ID]}),
            T = [Node||Node <- ExistingNodes, churnhelper(ID, Node)==true],
            exitchurn(ID, 0, T),
            rcvonlystop(ID);
        stop ->
            [{_,ExistingNodes}] = ets:lookup(x, existingn),
            ets:insert(x, {existingn,ExistingNodes--[ID]}),
            io:format("closing down Node ~p~n", [ID]),
            ok
    end.

rcvonlystop(ID) ->
    receive
        stop ->
            io:format("closing down Node ~p~n", [ID]),
            ok
    end.