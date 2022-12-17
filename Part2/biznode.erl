-module(biznode).
-import(server,[getTimeSleep/0, discovery/2, exitchurn/3, churnhelper/2]).
-export([byzrps/1, rcv/1, initbiz/1]).

initbiz(ID) ->
    io:fwrite("On est là ~w~n", [ID]),
    % N1 = ets:lookup(x, n),
    % V1 = ets:lookup(x, v),
    % [{_, N}] = N1,
    % [{_, V}] = V1,

    % T = lists:delete({0,ID},[{0,list_to_atom(integer_to_list(rand:uniform(N)))} || _ <- lists:seq(1, V)]),
    % ShuffledT = [Y||{_,Y} <- lists:sort([{rand:uniform(), X} || X <- T])],
    % Table = lists:sublist(ShuffledT, V),
    % ets:insert(x, {ID, Table}),
    timer:apply_interval(getTimeSleep(), biznode, byzrps, [ID]),
    rcv(ID).

byzrps(ID) ->
    % Select a random valid node
    [{_,ValidNodes}] = ets:lookup(x, existingn),
    Q = lists:nth(rand:uniform(length(ValidNodes)), ValidNodes),
    %Select l-1 other random entries of the table
    [{_,L}] = ets:lookup(x, l),
    [{_, BizNodes}] = ets:lookup(b, biznodes),
    % ShuffledT = [Y||{_,Y} <- lists:sort([{rand:uniform(), N} || N <- TableInc])],
    ShuffledT = [Y||{_,Y} <- lists:sort([{rand:uniform(), N} || N <- BizNodes])],
    REntries = lists:sublist(ShuffledT, L-1) ++ [ID],
    %Send the l-1 entries to Q
    Q ! {advertise, ID, [{0, Node} || Node <-REntries]}.

rcv(ID) ->
    receive
        {advertise, From, Entries} ->
            %Remove entries pointing to Q from the subset send by P
            EntriesWoAge = [Y||{_,Y} <- Entries],
            EntriesQ = lists:delete(ID, EntriesWoAge),
            %Remove already present entries in Q's view from the subset send by P
            [{_,L}] = ets:lookup(x, l),
            %Q sends back a subset of the l-1 entry of its table
            ShuffledT2 = [Y||{_,Y} <- lists:sort([ {rand:uniform(), N} || {_,N} <- EntriesQ])],
            REntries2 = lists:sublist(ShuffledT2, L),
            From ! {response, Entries, REntries2},
            rcv(ID);
        {response, _, _} ->
            % OK
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