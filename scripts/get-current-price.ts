import fs from 'fs-extra';
import { JsonRpcProvider } from '@ethersproject/providers';
import { Wallet } from '@ethersproject/wallet';
import { MediaFactory } from '../typechain/MediaFactory';
import { ethers } from "ethers";
const HDWalletProvider = require("truffle-hdwallet-provider");
const web3 = require("web3")

async function start() {
  const args = require('minimist')(process.argv.slice(2), {
    string: ['tokenURI', 'metadataURI', 'contentHash', 'metadataHash'],
  });

  if (!args.chainId) {
    throw new Error('--chainId chain ID is required');
  }
  const path = `${process.cwd()}/.env${
    args.chainId === 1 ? '.prod' : args.chainId === 4 ? '.dev' : '.local'
  }`;
  await require('dotenv').config({ path });

  /*
  const provider = new JsonRpcProvider(process.env.RPC_ENDPOINT);
  const wallet = new Wallet(`0x${process.env.PRIVATE_KEY}`, provider);
  */

  const network = process.env.NETWORK;
  const provider = new HDWalletProvider(
    process.env.MNEMONIC,
    "https://eth-" + network + ".alchemyapi.io/v2/" + process.env.ALCHEMY_API_KEY
  );

  /*
  const network = process.env.NETWORK;
  let wallet = Wallet.fromMnemonic(process.env.MNEMONIC)
  const provider = ethers.getDefaultProvider(network, {
    alchemy: process.env.ALCHEMY_API_KEY,
  });
  wallet = wallet.connect(provider)
  */

  const sharedAddressPath = `${process.cwd()}/addresses/${args.chainId}.json`;
  // @ts-ignore
  const addressBook = JSON.parse(await fs.readFileSync(sharedAddressPath));
  if (!addressBook.media) {
    throw new Error(`Media contract has not yet been deployed`);
  }

  let mediaToken = JSON.parse(fs.readFileSync("./artifacts/contracts/Media.sol/Media.json"))

  const web3Instance = new web3(provider);

  const nftContract = new web3Instance.eth.Contract(
    mediaToken.abi,
    addressBook.media,
    { gasLimit: "1000000" }
  );

  let result = await nftContract.methods.currentPrice().call()

  console.log(result);

  
}

start()