#!/bin/bash

set -e

FILE=addresses/rinkeby.json

MARKETADDR=$(cat $FILE | jq .market --raw-output)

MEDIAADDR=$(cat $FILE | jq .media --raw-output)

npx hardhat verify --network rinkeby $MARKETADDR

npx hardhat verify --network rinkeby $MEDIAADDR $MARKETADDR

