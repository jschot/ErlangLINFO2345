-module(node).
-import(lists,[max/1]).
-export([start/3, startmany/1, start/1, createnode/1, init/1, rps/1, rcv/1, stop/1, enteringchurn/1, enteringchurn/3, startexitchurn/1]).

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
            [{_,FileD}] = ets:lookup(x, filed),
            file:close(FileD),
            [{_,FileC}] = ets:lookup(x, filec),
            file:close(FileC),
            [{_,FileC2}] = ets:lookup(x, filec2),
            file:close(FileC2),
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
    timer:apply_interval(5000, node, rps, [ID]),
    rcv(ID).

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
            Tostop = max(Nodes),
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
                after 5000 ->
                    io:format("~p,~p,~p~n", [atom_to_list(ID), length(List),length(T2)]),
                    exitchurn(ID,C+1,List)
            end
    end.

enteringchurn(N) ->
    if
        N > 0 ->
            [{_,ExistingNodes}] = ets:lookup(x, existingn),
            Nodes = [list_to_integer(atom_to_list(X))||X <- ExistingNodes],
            Tostart = max(Nodes)+1,
            createnode(list_to_atom(integer_to_list(Tostart))),
            io:format("Start measure enter churn of Node ~p~n",[integer_to_list(Tostart)]),
            ets:insert(x, {n, Tostart}),
            Atom = list_to_atom(integer_to_list(100000+Tostart)),
            register(Atom, spawn(node, enteringchurn, [list_to_atom(integer_to_list(Tostart)), 0, []])),
            timer:sleep(2000),
            enteringchurn(N-1);
        true ->
            ok
    end.

enteringchurn(ID, C, HistoryT) ->
    [{_,FileC}] = ets:lookup(x, filec2),
    [{_,ExistingNodes}] = ets:lookup(x, existingn),
    T = [Node||Node <- ExistingNodes, churnhelper(ID, Node)==true],
    T2 = HistoryT ++ T,
    if 
        length(T2)/length(ExistingNodes) > 0.75 ->
            io:fwrite(FileC, "~p,~p~n", [atom_to_list(ID), C]);
        true ->
            io:format("More turn for enter churn of Node ~p - ~p%~n",[atom_to_list(ID),T2]),
            timer:sleep(5000),
            enteringchurn(ID,C+1,T2)
    end.

churnhelper(ID, I) ->
    [{_,Table}] = ets:lookup(x, I),
    Table2 = [X || {_,X} <- Table],
    lists:member(ID, Table2).


rps(ID) ->
    [{_,Table}] = ets:lookup(x, ID),
    %Increase Age by one
    TableInc = [{Age+1,Node}||{Age,Node} <- Table],
    %Select older node (Q)
    {AgeQ,Q} = max(TableInc),
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
                    TodeleteinNT = lists:usort([{Age,Y}||{Age,Y}<-NewTable, {_,X}<-REntries2 , X==Y]),
                    NewTable2 = NewTable -- TodeleteinNT,
                    if
                        V-length(NewTable2) > 0 ->
                            NewTable3 = NewTable2 ++ lists:sublist(REntries2, V-length(NewTable2)),
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