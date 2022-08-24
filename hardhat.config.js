require("dotenv").config();
require("@nomicfoundation/hardhat-chai-matchers");
require("hardhat-deploy");

module.exports = {
    networks: {
        harmony: {
            url: process.env.DFKEarn_rpcUrl || "https://rpc.ankr.com/harmony",
            accounts: [ process.env.DFKEarn_privateKey ],
            gasPrice: 110e9
        }
    },
    namedAccounts: {
        deployer: 0,
    },
    solidity: {
        version: "0.8.7",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200,
            },
            evmVersion: "london"
        }
    },
    etherscan: {
        apiKey: {
          harmony: "your_apiKey"
        }
    }
};
