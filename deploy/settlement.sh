#!/usr/bin/env bash

# Read the RPC URL
echo "Enter Your RPC URL(press RETURN for anvil deployment):"
echo Example: https://eth-mainnet.alchemyapi.io/v2/XXXXXXXXXX 
read -s rpc

echo "Enter Your Etherscan API key(press RETURN for anvil deployment):"
read -s etherscanKey

if [ -z "$rpc" ]
then
  forge create Settlement -i --rpc-url http://localhost:8545 --constructor-args "1" --verify
else
  ETHERSCAN_API_KEY=etherscanKey forge create Settlement -i --rpc-url $rpc --constructor-args "1" --verify
fi
