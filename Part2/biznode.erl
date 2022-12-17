-module(biznode).
-import(server,[getTimeSleep/0, discovery/2]).
-export([byzrps/1, rcv/1, initbiz/1]).

initbiz(ID) ->
    timer:apply_interval(getTimeSleep(), biznode, byzrps, [ID]),
    rcv(ID).

byzrps(ID) ->
    % Select a random valid node
    [{_,ValidNodes}] = ets:lookup(x, existingn),
    Q = lists:nth(rand:uniform(length(ValidNodes)), ValidNodes),
    %Select l-1 other random entries of the table
    [{_,L}] = ets:lookup(x, l),
    [{_, BizNodes}] = ets:lookup(b, biznodes),
    ShuffledT = [Y||{_,Y} <- lists:sort([{rand:uniform(), N} || N <- BizNodes])],
    REntries = lists:sublist(ShuffledT, L-1) ++ [ID],
    %Send the l entries to Q
    Q ! {advertise, ID, [{0, Node} || Node <-REntries]}.

rcv(ID) ->
    receive
        {advertise, From, Entries} ->
            %Remove own ID
            EntriesWoAge = [Y||{_,Y} <- Entries],
            EntriesQ = lists:delete(ID, EntriesWoAge),
            From ! {response, Entries, EntriesQ},
            rcv(ID);
        {response, _, _} ->
            % OK
            rcv(ID);
        showtable ->
            [{_,TableOK}] = ets:lookup(x, ID),
            io:format("Table ~w~n", [TableOK]),
            rcv(ID);
        stop ->
            [{_,ExistingNodes}] = ets:lookup(x, existingn),
            ets:insert(x, {existingn,ExistingNodes--[ID]}),
            io:format("closing down Node ~p~n", [ID]),
            ok
    end.
