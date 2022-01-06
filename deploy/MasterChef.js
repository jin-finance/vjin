module.exports = async ({ ethers, deployments, getNamedAccounts }) => {
    const { deploy } = deployments
  
    const { deployer, dev } = await getNamedAccounts()
  
    const vjin = await ethers.getContract("VJinToken")
    
    const { address } = await deploy("MasterChef", {
      from: deployer,
      args: [vjin.address, dev, "237823440000000000", "14891530", "15135900"],
      log: true,
      deterministicDeployment: false
    })
  
    if (await vjin.owner() !== address) {
      // Transfer vJin Ownership to Chef
      console.log("Transfer vJin Ownership to Chef")
      await (await vjin.transferOwnership(address)).wait()
    }
  
    const masterChef = await ethers.getContract("MasterChef")
    if (await masterChef.owner() !== dev) {
      // Transfer ownership of MasterChef to dev
      console.log("Transfer ownership of MasterChef to dev")
      await (await masterChef.transferOwnership(dev)).wait()
    }


  }
  
  module.exports.tags = ["MasterChef"]
  module.exports.dependencies = ["VJinToken"]