const { program } = require("commander");
const { ethers } = require("ethers");
const { artifacts } = require("hardhat");

async function generateHumanReadableABI(contract) {
    const artifact = await artifacts.readArtifact(contract);
    const iface = new ethers.utils.Interface(artifact.abi);
    const humanReadableABI = iface.format(ethers.utils.FormatTypes.full);
    console.log(JSON.stringify(humanReadableABI, undefined, 2));
}

async function main() {
    program
        .argument("<contract>")
        .action(generateHumanReadableABI);
    await program.parseAsync();
}

main()
    .then(() => process.exit(0))
    .catch((e) => {
        console.error(e);
        process.exit(1);
    });
