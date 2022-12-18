# PART3 - Byantine nodes

## How to launch

```erlang
c(node).
c(biznode).
c(server).

% N -> number of valid nodes
% L -> number of nodes advertised
% V -> size of the view
% B -> number of byzanine nodes
% R -> Proportion of L that will be random
server:startwithbyzantineandrandom(N, L, V, B, R).
% To run more automatic tests :
% This will vary the number of byzantine nodes
% from ByzNodes to MaxByzNodes by incremanting of Inc

server:startmetrics(TotalNumberOfNodes, L, V, ByzNodes, Inc, MaxByzNodes, R)
```

## Make graph

Just run : (you must have the matplotblib librairie)

```bash
python3 percentage_byz_in_nodes.py
```
