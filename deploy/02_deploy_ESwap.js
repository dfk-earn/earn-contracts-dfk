module.exports = async function({
    getNamedAccounts,
    deployments,
    ethers
}) {
    const { deployer } = await getNamedAccounts();
    const fee = ethers.utils.parseUnits("10", "ether");
    await deployments.deploy("ESwap", {
        from: deployer,
        args: [ fee, 0],
        log: true
    });
}

module.exports.tags = [ "ESwap" ];
