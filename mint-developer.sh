#!/bin/bash

pushd () {
    command pushd "$@" > /dev/null
}

popd () {
    command popd "$@" > /dev/null
}

pushd /home/michele/Projects/lovelock/cryptolovelocks-zora-core

    echo "Start to mint token: $1 with gwei $2"  

    . .env.mainnet

    /home/michele/.nvm/versions/node/v14.16.1/bin/ts-node scripts/mintDeveloper.ts --chainId mainnet --tokenId $1 --gwei $2

popd
