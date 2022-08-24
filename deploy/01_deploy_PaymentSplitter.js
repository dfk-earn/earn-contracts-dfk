const config = require("../config/PaymentSplitter.json");

module.exports = async function({
    getNamedAccounts,
    deployments,
}) {
    const { deployer } = await getNamedAccounts();
    const { deploy } = deployments;
    const { payees, shares } = config;

    await deploy("PaymentSplitter", {
        from: deployer,
        args: [ payees, shares ],
        log: true,
    })
}

module.exports.tags = [ "PaymentSplitter" ];
