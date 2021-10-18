import fs from 'fs-extra';
import { JsonRpcProvider } from '@ethersproject/providers';
import { Wallet } from '@ethersproject/wallet';
import { MediaFactory } from '../typechain/MediaFactory';
import { BigNumber, ethers } from "ethers";

async function start() {

  const args = require('minimist')(process.argv.slice(2));

  if (!args.chainId) {
    throw new Error('--chainId chain ID is required');
  }

  if (!("tokenId" in args)) {
    throw new Error('--tokenId is required');
  }

  let gwei = 6

  if (args.gwei) {
    try {
      let temp = parseInt(args.gwei)
      if (temp > 0 && temp < 100) {
        gwei = temp
      }
    }
    catch (e) {
      console.log("Bad gwei: '" + args.gwei + "'")
    }

  }

  let wallet
  let provider

  if (process.env.RPC_ENDPOINT) {
    provider = new JsonRpcProvider(process.env.RPC_ENDPOINT);
    wallet = new Wallet(`0x${process.env.PRIVATE_KEY}`, provider);
  }
  else {
    const network = process.env.NETWORK;
    console.log(process.env.PRIVATE_KEY)
    wallet = new Wallet(process.env.PRIVATE_KEY)
    const provider = ethers.getDefaultProvider(network, {
      alchemy: process.env.ALCHEMY_KEY,
    });
    wallet = wallet.connect(provider)
  }

  const sharedAddressPath = `${process.cwd()}/addresses/${args.chainId}.json`;

  // @ts-ignore
  const addressBook = JSON.parse(await fs.readFileSync(sharedAddressPath));

  if (addressBook.media) {

    console.log('Begin Minting Token...');
    const media = MediaFactory.connect(addressBook.media, wallet);

    const metadata = JSON.parse(await fs.readFileSync(`/home/michele/Projects/lovelock/cryptolovelocks-uploader/assets${args.chainId === "rinkeby" ? "-fake" : ""}/${args.tokenId}.media.json`));

    const tx = await media.mint(args.tokenId, {
      tokenURI: metadata.tokenURI,
      metadataURI: metadata.metadataURI,
      contentHash: metadata.contentHash,
      metadataHash: metadata.metadataHash,
    }, {
      gasLimit: 660000,
      gasPrice: gwei * 1000000000
    })
    console.log(`Minting tx: https://etherscan.io/tx/${tx.hash} for tokenId: ${args.tokenId}`);

    // await tx.wait();
    
    // console.log(`Minted.`);
  
  }

}

start().catch((e: Error) => {
  console.error(e);
  process.exit(1);
});
