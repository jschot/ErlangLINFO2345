N = Number of nodes in the network
L = Size of the subset
V = Size of view

------------------------------------
compile :
c(node).
c(server).

Launch N node with L and V fixed - This will also launch discovery rate measures:
server:start(N,L,V).
	---> discoveryrate data will be placed in discoveryrate.csv

When it has run enough time for you :
node:stop(N).    --> This will shut down N first node, to avoid crash N must be the number of remaining nodes.

You can launch exiting churn resilience measure after launching N node with :
server:startexitchurn(P)     ---> This will shut down P last nodes and measure exiting churn resilience.
			     			---> This process stop by its own after getting data.
			     			---> To stop the network you will have to use : node:stop(N) - N used in server:start(N,L,V).
							---> Result will be placed in Churn.csv

You can launch entering churn resilience measure after launching N node with :
server:enteringchurn(P)      ---> This will start P nodes and measure entering churn resilience.
			     			---> This process stop by its own after getting data.
                             ---> To stop the network you will have to use : node:stop(N+P) - N used in server:start(N,L,V); P used in server:enteringchurn(P).
							 ---> Result will be placed in Churn2.csv

----------------------
Get graph :
preprocess data : 
	preprocess.py
	Line 1 : change filename by name of the file to preprocess
	Line 2 : change filename by name of the output file

discoveryrate :
	discoveryrate.py
	Line 6 : change filename by name of the file to analyze
	
exiting churn resilience :
	exitingchurn.py
	Line 6 : change filename by name of the file to analyze

entering churn resilience :
	enteringchurn.py
	Line 6 : change filename by name of the file to analyze