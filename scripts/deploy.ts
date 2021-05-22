import fs from 'fs-extra';
import { JsonRpcProvider } from '@ethersproject/providers';
import { Wallet } from '@ethersproject/wallet';
import { MediaFactory } from '../typechain/MediaFactory';
import { MarketFactory } from '../typechain/MarketFactory';
import { ethers } from "ethers";

let cryptoLovelockPrice = 0.04e+18

let developer = "0xfb1Cad7cF15c11E2827095b4aAD513d9Bc160Df8"

let STONIZE_PUBLIC_ADDRESS = "0xDE89fb5bd8f420301fAB3930fAaEf185776c4b07"

async function start() {
  const args = require('minimist')(process.argv.slice(2));

  if (!args.chainId) {
    throw new Error('--chainId chain ID is required');
  }
  const path = `${process.cwd()}/.env${
    args.chainId === 1 ? '.prod' : args.chainId === 4 ? '.dev' : '.local'
  }`;
  await require('dotenv').config({ path });

  let wallet
  let provider

  if (process.env.RPC_ENDPOINT) {
    provider = new JsonRpcProvider(process.env.RPC_ENDPOINT);
    wallet = new Wallet(`0x${process.env.PRIVATE_KEY}`, provider);
  }
  else {
    const network = process.env.NETWORK;
    console.log(process.env.PRIVATE_KEY)
    wallet = new Wallet(process.env.PRIVATE_KEY) // Wallet.fromMnemonic(process.env.MNEMONIC)
    const provider = ethers.getDefaultProvider(network, {
      alchemy: process.env.ALCHEMY_KEY,
    });
    wallet = wallet.connect(provider)
  }
  // var contractData = contractObject.new.getData(someparam, another, {data: contractBytecode});
  // var estimate = web3.eth.estimateGas({data: contractData})

  const sharedAddressPath = `${process.cwd()}/addresses/${args.chainId}.json`;
  // @ts-ignore
  const addressBook = JSON.parse(await fs.readFileSync(sharedAddressPath));
  if (addressBook.market) {
    throw new Error(
      `market already exists in address book at ${sharedAddressPath}. Please move it first so it is not overwritten`
    );
  }
  if (addressBook.media) {
    throw new Error(
      `media already exists in address book at ${sharedAddressPath}. Please move it first so it is not overwritten`
    );
  }

  console.log('Deploying Market...');
  const deployTx = await new MarketFactory(wallet).deploy();
  console.log('Deploy TX: ', deployTx.deployTransaction.hash);
  await deployTx.deployed();
  console.log('Market deployed at ', deployTx.address);
  addressBook.market = deployTx.address;

  console.log('Deploying Media...');
  const mediaDeployTx = await new MediaFactory(wallet).deploy(
    addressBook.market,
    cryptoLovelockPrice,
    developer,
  );
  console.log(`Deploy TX: ${mediaDeployTx.deployTransaction.hash}`);
  await mediaDeployTx.deployed();
  console.log(`Media deployed at ${mediaDeployTx.address}`);
  addressBook.media = mediaDeployTx.address;

  console.log('Configuring Market...');
  const market = MarketFactory.connect(addressBook.market, wallet);
  const tx = await market.configure(addressBook.media);
  console.log(`Market configuration tx: ${tx.hash}`);
  await tx.wait();
  console.log(`Market configured.`);

  await fs.writeFile(sharedAddressPath, JSON.stringify(addressBook, null, 2));
  console.log(`Contracts deployed and configured. ☼☽`);
}

start().catch((e: Error) => {
  console.error(e);
  process.exit(1);
});
