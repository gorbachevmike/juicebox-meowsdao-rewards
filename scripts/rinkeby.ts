import * as hre from 'hardhat';
import { ethers } from 'hardhat';

async function main() {
  const projectId = 4471;
  const jbDirectoryAddress = '0x1A9b04A9617ba5C9b7EBfF9668C30F41db6fC21a';
  const tokenName = 'MEOWsDAO Membership Token';
  const tokenSymbol = 'MMT';
  const tiers = [
    {
      contributionFloor: ethers.utils.parseEther('0.01'),
      lockedUntil: 0,
      remainingQuantity: 1000,
      initialQuantity: 1000,
      votingUnits: 1,
      reservedRate: 10000,
      tokenUri: '0x0000000000000000000000000000000000000000000000000000000000000000',
    },
    {
      contributionFloor: ethers.utils.parseEther('0.025'),
      lockedUntil: 0,
      remainingQuantity: 1000,
      initialQuantity: 1000,
      votingUnits: 10,
      reservedRate: 10000,
      tokenUri: '0x0000000000000000000000000000000000000000000000000000000000000000',
    },
    {
      contributionFloor: ethers.utils.parseEther('0.03'),
      lockedUntil: 0,
      remainingQuantity: 1000,
      initialQuantity: 1000,
      votingUnits: 100,
      reservedRate: 10000,
      tokenUri: '0x0000000000000000000000000000000000000000000000000000000000000000',
    },
    {
      contributionFloor: ethers.utils.parseEther('0.04'),
      lockedUntil: 0,
      remainingQuantity: 1000,
      initialQuantity: 1000,
      votingUnits: 1000,
      reservedRate: 10000,
      tokenUri: '0x0000000000000000000000000000000000000000000000000000000000000000',
    },
    {
      contributionFloor: ethers.utils.parseEther('5'),
      lockedUntil: 0,
      remainingQuantity: 1000,
      initialQuantity: 1000,
      votingUnits: 10000,
      reservedRate: 10000,
      tokenUri: '0x0000000000000000000000000000000000000000000000000000000000000000',
    },
  ];

  const [deployer] = await ethers.getSigners();

  const meowGatewayUtilFactory = await ethers.getContractFactory('MeowGatewayUtil', deployer);
  const meowGatewayUtilLibrary = await meowGatewayUtilFactory.connect(deployer).deploy();

  const jbTierRewardTokenFactory = await ethers.getContractFactory('JBTierRewardToken', {
    libraries: { MeowGatewayUtil: meowGatewayUtilLibrary.address },
    signer: deployer,
  });
  const token = await jbTierRewardTokenFactory
    .connect(deployer)
    .deploy(
      projectId,
      jbDirectoryAddress,
      tokenName,
      tokenSymbol,
      'ipfs://',
      'https://ipfs.io/ipfs/',
      'bafybeifthvccjjxaqlzwvjgvlsgqfygqugww4jdegrltrfrn72mvlrjobu/',
      deployer.address,
      tiers,
      true,
      deployer.address,
    );

  await token.deployed(); // 0x3646743730d2B4cbcA43d1E5877050DBd919C6EE

  try {
    await hre.run('verify:verify', {
      address: token.address,
      constructorArguments: [
        projectId,
        jbDirectoryAddress,
        tokenName,
        tokenSymbol,
        'ipfs://',
        'https://ipfs.io/ipfs/',
        'bafybeifthvccjjxaqlzwvjgvlsgqfygqugww4jdegrltrfrn72mvlrjobu/',
        deployer.address,
        tiers,
        true,
        deployer.address,
      ],
    });
  } catch {}

  console.log(`token: ${token.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run scripts/rinkeby.ts --network rinkeby
