module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy } = deployments
  
    const { deployer } = await getNamedAccounts()
  
    await deploy("VJinToken", {
      from: deployer,
      log: true,
      deterministicDeployment: false
    })

  }
  
  module.exports.tags = ["VJinToken"]