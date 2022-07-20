import { expect } from 'chai';
import { ethers } from 'hardhat';
import { deployMockContract } from '@ethereum-waffle/mock-contract';

import jbDirectory from '../node_modules/@jbx-protocol/contracts-v2/deployments/mainnet/jbDirectory.json';
import jbETHPaymentTerminal from '../node_modules/@jbx-protocol/contracts-v2/deployments/mainnet/jbETHPaymentTerminal.json';

describe('MEOWs DAO Token Mint Tests', () => {
    const tokenUnitPrice = ethers.utils.parseEther('0.0125');

    let deployer: any;
    let accounts: any[];
    let token: any;

    before(async () => {
        const tokenName = 'Token';
        const tokenSymbol = 'TKN';
        const tokenBaseUri = 'ipfs://hidden';
        const tokenContractUri = 'ipfs://metadata';
        const jbxProjectId = 99;
        const tokenMaxSupply = 1000;
        const tokenMintAllowance = 10;

        [deployer, ...accounts] = await ethers.getSigners();

        const jbxJbTokensEth = '0x000000000000000000000000000000000000EEEe';
        const ethTerminal = await deployMockContract(deployer, jbETHPaymentTerminal.abi);
        // TODO: mock token terminal

        const mockDirectory = await deployMockContract(deployer, jbDirectory.abi);
        await mockDirectory.mock.isTerminalOf.withArgs(jbxProjectId, ethTerminal.address).returns(true);
        await mockDirectory.mock.primaryTerminalOf.withArgs(jbxProjectId, jbxJbTokensEth).returns(ethTerminal.address);

        const tokenFactory = await ethers.getContractFactory('Token', deployer);
        token = await tokenFactory.connect(deployer).deploy(
            tokenName,
            tokenSymbol,
            tokenBaseUri,
            tokenContractUri,
            jbxProjectId,
            mockDirectory.address,
            tokenMaxSupply,
            tokenUnitPrice,
            tokenMintAllowance
        );
    });

    it('User mints first', async () => {
        await expect(token.connect(accounts[0])['mint()']({value: 0})).to.emit(token, 'Transfer');
    });
});
