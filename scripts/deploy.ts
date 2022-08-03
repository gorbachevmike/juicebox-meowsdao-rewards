import * as hre from 'hardhat';
import { ethers } from 'hardhat';

async function main() {
  const [deployer] = await ethers.getSigners();

  const NftCreatorV1Factory = await ethers.getContractFactory('NftCreatorV1', deployer);
  const NftCreatorV1 = await NftCreatorV1Factory.connect(deployer).deploy();

  const nftCreatorV1 = await NftCreatorV1.connect(deployer).deploy();

  await nftCreatorV1.deployed();

  try {
    await hre.run('verify:verify', {
      address: nftCreatorV1.address,
      constructorArguments: [],
    });
  } catch {}

  console.log(`token: ${nftCreatorV1.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run scripts/deploy.ts --network rinkeby
