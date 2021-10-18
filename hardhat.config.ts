import { HardhatUserConfig } from 'hardhat/config';
import '@nomiclabs/hardhat-waffle';
import '@nomiclabs/hardhat-ethers';
import 'hardhat-typechain';
import 'hardhat-deploy';
import '@nomiclabs/hardhat-etherscan';

// You have to export an object to set up your config
// This object can have the following optional entries:
// defaultNetwork, networks, solc, and paths.
// Go to https://buidler.dev/config/ to learn more
const config: HardhatUserConfig = {
  defaultNetwork: "rinkeby",
  networks: {
    hardhat: {
    },
    rinkeby: {
      url: "https://eth-rinkeby.alchemyapi.io/v2/W90PBa-JLHQCM6hOZ8uH-iled9dih91o",
      accounts: ["87f89339c9b36bcae4a6cbd9e2216e79f58a3caa98a70e883a7948e94e1fc3ae"]
    },
    mainnet: {
      url: "https://eth-mainnet.alchemyapi.io/v2/26mGzBe1IpfGkLCa2srl5JDd-Jz8023h",
      accounts: ["fa5ecf2187618b5900117d41bddcb091251169a1daa28204dd6d83cbdddf00ef"]
    }
  },
  solidity: {
    compilers: [
      {
        version: '0.6.8',
        settings: {
          optimizer: {
            enabled: true,
          },
        },
      },
    ],
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: "9DRI6HNC1F71RDD836PUEGSNHJYXEFEDRS"
  }  
};

export default config;
