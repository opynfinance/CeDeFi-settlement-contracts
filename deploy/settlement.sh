#!/usr/bin/env bash

# Read the RPC URL
echo "Enter Your RPC URL(press RETURN for anvil deployment):"
echo Example: https://eth-mainnet.alchemyapi.io/v2/XXXXXXXXXX 
read -s rpc

if [ -z "$rpc" ]
then
  forge create Settlement -i --rpc-url http://localhost:8545/ --constructor-args "1"
else
  forge create Settlement -i --rpc-url $rpc --constructor-args "1"
fi
