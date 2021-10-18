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
  /*
  const path = `${process.cwd()}/.env${
    args.chainId === 1 ? '.prod' : args.chainId === 4 ? '.dev' : '.local'
  }`;
  await require('dotenv').config({ path });
  */

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

  const sharedAddressPath = `${process.cwd()}/addresses/${args.chainId}.json`;
  // @ts-ignore
  const addressBook = JSON.parse(await fs.readFileSync(sharedAddressPath));

  if (addressBook.media) {

    console.log('Begin Discount campain...');
    const media = MediaFactory.connect(addressBook.media, wallet);
    const tx = await media.setCurrentPrice(ethers.utils.parseEther("0.04"), {
      gasLimit: 1000000,
    })
    console.log(`Discount configuration tx: ${tx.hash}`);
    await tx.wait();
    console.log(`Discount configured.`);
  
  }

}

start().catch((e: Error) => {
  console.error(e);
  process.exit(1);
});
