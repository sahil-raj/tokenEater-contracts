const { ethers } = require("hardhat");

async function main() {
  // Get the deployer account
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);
  console.log(
    "Account balance:",
    (await deployer.provider.getBalance(deployer.address)).toString()
  );

  // Deploy PoolFactory
  const PoolFactory = await ethers.getContractFactory("PoolFactory");

  // Deploy without constructor arguments
  const poolFactory = await PoolFactory.deploy();

  await poolFactory.waitForDeployment();

  const address = await poolFactory.getAddress();
  console.log("PoolFactory deployed to:", address);

  // Verify deployment
  console.log("Verifying contract...");
  console.log("Owner:", await poolFactory.owner());

  return {
    poolFactory: address,
  };
}

main()
  .then((result) => {
    console.log("Deployment successful!");
    console.log("Contract addresses:", result);
    process.exit(0);
  })
  .catch((error) => {
    console.error("Deployment failed:", error);
    process.exit(1);
  });
