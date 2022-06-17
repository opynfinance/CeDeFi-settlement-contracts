#!/usr/bin/env bash

# Read the RPC URL
echo "Enter Your RPC URL(press RETURN for anvil deployment):"
echo Example: https://eth-mainnet.alchemyapi.io/v2/XXXXXXXXXX 
read -s rpc

if [ -z "$rpc" ]
then
  ETHERSCAN_API_KEY=PSW8C433Q667DVEX5BCRMGNAH9FSGFZ7Q8 forge create Settlement -i --rpc-url https://ropsten.infura.io/v3/9a1eacc6b18f436dab839c1713616fd1 --constructor-args "1" --verify
else
  forge create Settlement -i --rpc-url $rpc --constructor-args "1" --verify
fi
