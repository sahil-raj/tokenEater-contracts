const { ethers } = require("hardhat");

async function main() {
  // Get the deployer account
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);
  console.log(
    "Account balance:",
    (await deployer.provider.getBalance(deployer.address)).toString()
  );

  // Deploy TokenPool
  const TokenPool = await ethers.getContractFactory(
    "contracts/TokenPool.sol:TokenPool"
  );

  const lockTimestamp = Math.floor(Date.now() / 1000) + 60 * 60;

  // Deploy with constructor arguments
  const tokenPool = await TokenPool.deploy(
    "pool-1", // poolId
    deployer.address, // owner
    lockTimestamp // lockTimestamp
  );

  await tokenPool.waitForDeployment();

  const address = await tokenPool.getAddress();
  console.log("TokenPool deployed to:", address);

  // Verify deployment
  console.log("Verifying contract...");
  console.log("Owner:", await tokenPool.owner());
  console.log("Pool ID:", await tokenPool.poolId());
  console.log("Lock Timestamp:", await tokenPool.lockTimestamp());

  return {
    tokenPool: address,
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
