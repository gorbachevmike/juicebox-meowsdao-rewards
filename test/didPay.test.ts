import { expect } from 'chai';
import { ethers } from 'hardhat';

import { deployMockContract } from '@ethereum-waffle/mock-contract';

import jbDirectory from '../node_modules/@jbx-protocol/contracts-v2/deployments/mainnet/jbDirectory.json';

describe('MEOWs DAO Token Mint Tests: JBX Delegate', function () {
  const PROJECT_ID = 2;
  const CURRENCY_ETH = 1;
  const ethToken = '0x000000000000000000000000000000000000EEEe'; // JBTokens.ETH

  let projectTerminal: any;
  let beneficiary: any;
  let jbTierRewardToken: any;

  before(async () => {
    let deployer;
    let accounts;

    [deployer, projectTerminal, beneficiary, ...accounts] = await ethers.getSigners();

    const mockJbDirectory = await deployMockContract(deployer, jbDirectory.abi)

    await mockJbDirectory.mock.isTerminalOf.withArgs(PROJECT_ID, projectTerminal.address).returns(true);
    await mockJbDirectory.mock.isTerminalOf.withArgs(PROJECT_ID, beneficiary.address).returns(false);

    const meowGatewayUtilFactory = await ethers.getContractFactory('MeowGatewayUtil', deployer);
    const meowGatewayUtilLibrary = await meowGatewayUtilFactory.connect(deployer).deploy();

    const jbTierRewardTokenFactory = await ethers.getContractFactory('JBTierRewardToken', {
        libraries: { MeowGatewayUtil: meowGatewayUtilLibrary.address },
        signer: deployer
    });
    jbTierRewardToken = await jbTierRewardTokenFactory
      .connect(deployer)
      .deploy(
        PROJECT_ID,
        mockJbDirectory.address,
        'JBX Delegate Banana',
        'BAJAJA',
        'ipfs://',
        'https://ipfs.io/ipfs/',
        'bafybeid25r5s6326gihtro262piql4z7ooei6vajy3c6x6kz33755lz6qi/',
        deployer.address,
        [{
            contributionFloor: ethers.utils.parseEther('1'),
            lockedUntil: 0,
            remainingQuantity: 20,
            initialQuantity: 20,
            votingUnits: 10000,
            reservedRate: 10000,
            tokenUri: '0x0000000000000000000000000000000000000000000000000000000000000000',
        }, {
            contributionFloor: ethers.utils.parseEther('2'),
            lockedUntil: 0,
            remainingQuantity: 10,
            initialQuantity: 10,
            votingUnits: 10000,
            reservedRate: 10000,
            tokenUri: '0x0000000000000000000000000000000000000000000000000000000000000000',
        }, {
            contributionFloor: ethers.utils.parseEther('3'),
            lockedUntil: 0,
            remainingQuantity: 5,
            initialQuantity: 5,
            votingUnits: 10000,
            reservedRate: 10000,
            tokenUri: '0x0000000000000000000000000000000000000000000000000000000000000000',
        }],
        true,
        deployer.address
      );
  });

  it(`Should mint token if meeting contribution parameters`, async () => {
    await expect(jbTierRewardToken.connect(projectTerminal).didPay({
      payer: beneficiary.address,
      projectId: PROJECT_ID,
      currentFundingCycleConfiguration: 0,
      amount: { token: ethToken, value: ethers.utils.parseEther('1'), decimals: 18, currency: CURRENCY_ETH },
      projectTokenCount: 0,
      beneficiary: beneficiary.address,
      preferClaimedTokens: true,
      memo: '',
      metadata: '0x42'
    })).to.emit(jbTierRewardToken, 'Transfer').withArgs(ethers.constants.AddressZero, beneficiary.address, 257);

    expect(await jbTierRewardToken.balanceOf(beneficiary.address)).to.equal(1);

    console.log(await jbTierRewardToken.tokenURI(257));
  });
});
