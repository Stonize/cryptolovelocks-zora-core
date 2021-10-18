import fs from 'fs-extra';
import { JsonRpcProvider } from '@ethersproject/providers';
import { Wallet } from '@ethersproject/wallet';
import { MediaFactory } from '../typechain/MediaFactory';
import { BigNumber, ethers } from "ethers";
import { MarketFactory } from '../typechain/MarketFactory';

const NETWORK = "ganache";
const TOKEN_ID = "1";
const GWEI = 1;

const DEVELOPER = {
    key: "04f708ad8e8f22c5e0846c7abeb22fe914f58345b7b5e79493231c2ba93da3c8",
    address: "0x5ED91220c79FcCD0ddc3bed8Fe9B2dAec401f540",
}

const OTHER = {
    key: "a1c001e3da5c56fc5894ff43971077de83f456132e73ad8a0081269d5023eca6",
    address: "0xb432358B99402FFb05d356188389e084DaCa9765",
}

function getMedia(actor) {
    const provider = new JsonRpcProvider(process.env.RPC_ENDPOINT);
    const wallet = new Wallet(actor.key, provider);
    const sharedAddressPath = `${process.cwd()}/addresses/${NETWORK}.json`;
    const addressBook = JSON.parse(fs.readFileSync(sharedAddressPath));
    const media = MediaFactory.connect(addressBook.media, wallet);
    return media;
}

async function deploy(actor) {

    let provider = new JsonRpcProvider(process.env.RPC_ENDPOINT);

    let wallet = new Wallet(actor.key, provider);

    const sharedAddressPath = `${process.cwd()}/addresses/${NETWORK}.json`;

    let addressBook = {
        media: "",
        market: ""
    }

    console.log('Deploying Market...');
    const deployTx = await new MarketFactory(wallet).deploy();
    console.log('Deploy TX: ', deployTx.deployTransaction.hash);
    await deployTx.deployed();
    console.log('Market deployed at ', deployTx.address);
    addressBook.market = deployTx.address;
      
    console.log('Deploying Media...');
    const mediaDeployTx = await new MediaFactory(wallet).deploy(addressBook.market);
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

async function mint(actor) {

    const media = getMedia(actor); 

    const metadata = JSON.parse(await fs.readFileSync(`/home/michele/Projects/lovelock/cryptolovelocks-uploader/assets/${TOKEN_ID}.media.json`));

    const tx = await media.mint(TOKEN_ID, {
      tokenURI: metadata.tokenURI,
      metadataURI: metadata.metadataURI,
      contentHash: metadata.contentHash,
      metadataHash: metadata.metadataHash,
    }, {
      gasLimit: 1000000,
      gasPrice: GWEI * 1000000000
    })

    console.log(`☼☽ Minting tx: ${tx.hash} for tokenId: ${TOKEN_ID}`);

    await tx.wait();

    console.log("Done")

}

async function setPriceFree(actor) {

    const media = getMedia(actor); 

    const tx = await media.setCurrentPrice(ethers.utils.parseEther("0.0"), {
        gasLimit: 1000000,
        gasPrice: GWEI * 1000000000
    })
    
    console.log(`Making free minting tx: ${tx.hash}`);
    
    await tx.wait();

    console.log("Done")

}

function getMessage(len) {
    let c = ["l", "𝓒"]   // 1 byte, 4 bytes
    let s = "";
    for (let i = 0; i < len; i ++) {
        s += c[i % c.length];
    }
    return s;
}

async function setLoveNote(actor, len) {

    const media = getMedia(actor); 

    const tx = await media.setLoveMessage(TOKEN_ID, getMessage(len), {
        gasLimit: 1000000,
        gasPrice: GWEI * 1000000000
    })

    console.log(`☼☽ Writing tx: ${tx.hash} for tokenId: ${TOKEN_ID}`);

    await tx.wait();

    console.log("Done")

    return tx;

}

async function transfer(from, to) {

    const media = getMedia(from); 

    const tx = await media.transferFrom(from.address, to.address, TOKEN_ID, {
        gasLimit: 1000000,
        gasPrice: GWEI * 1000000000
    })

    console.log(`☼☽ Transferring tx: ${tx.hash} for tokenId: ${TOKEN_ID}`);

    await tx.wait();

    console.log("Done")

}

async function dumpGasUsed(tx, len) {

    let provider = new JsonRpcProvider(process.env.RPC_ENDPOINT);
    
    let transaction = await provider.getTransaction(tx.hash);

    // console.log("Transaction for", tx.hash, ":", transaction)

    let block = await provider.getBlock(transaction.blockNumber)

    console.log(`Love Note,${len},${block.gasUsed.toString()}`)

}

async function start() {

    await deploy(DEVELOPER);

    await setPriceFree(DEVELOPER);

    await mint(DEVELOPER);

    let len = 2;

    for (let i = 0; i < 100; i ++ ) {
        
        dumpGasUsed(await setLoveNote(DEVELOPER, len), len)
        await transfer(DEVELOPER, OTHER)

        len += 2;

        dumpGasUsed(await setLoveNote(OTHER, len), len)
        await transfer(OTHER, DEVELOPER)

        len += 2;

    }

}

start();
