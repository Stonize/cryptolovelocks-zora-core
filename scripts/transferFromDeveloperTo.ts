import fs from 'fs-extra';
import { JsonRpcProvider } from '@ethersproject/providers';
import { Wallet } from '@ethersproject/wallet';
import { MediaFactory } from '../typechain/MediaFactory';
import { BigNumber, ethers } from "ethers";

const developer = "0xDE89fb5bd8f420301fAB3930fAaEf185776c4b07"

async function start() {

  const args = require('minimist')(process.argv.slice(2), { string: [ "to" ] });

  console

  if (!args.chainId) {
    throw new Error('--chainId chain ID is required');
  }

  if (!args.to) {
    throw new Error('--to Address where send token is required');
  }

  if (!args.gwei) {
    throw new Error('--gwei is required');
  }

  if (!args.tokenId) {
    throw new Error('--tokenId is required');
  }

  let wallet
  let provider

  if (process.env.RPC_ENDPOINT) {
    provider = new JsonRpcProvider(process.env.RPC_ENDPOINT);
    wallet = new Wallet(`0x${process.env.PRIVATE_KEY}`, provider);
  }
  else {
    const network = process.env.NETWORK;
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

    console.log('Begin To send Token...');

    const media = MediaFactory.connect(addressBook.media, wallet);

    // If it doesn't work, remove args.to and insert static string in its place.
    const tx = await media.transferFrom(developer, args.to, BigNumber.from(args.tokenId), {
      gasLimit: 1000000,
      gasPrice: BigNumber.from(args.gwei).mul(BigNumber.from("1000000000"))
    })
    console.log(`Send Token Transaction Hash: ${tx.hash}`);

    // await tx.wait();
    // console.log(`Discount configured.`);
  
  }

}

start().catch((e: Error) => {
  console.error(e);
  process.exit(1);
});
