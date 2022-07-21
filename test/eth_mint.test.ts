import { expect } from 'chai';
import { ethers } from 'hardhat';
import fetch from 'node-fetch';

import { deployMockContract } from '@ethereum-waffle/mock-contract';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import jbDirectory from '../node_modules/@jbx-protocol/contracts-v2/deployments/mainnet/jbDirectory.json';
import jbETHPaymentTerminal from '../node_modules/@jbx-protocol/contracts-v2/deployments/mainnet/jbETHPaymentTerminal.json';

async function deployMockContractFromAddress(contractAddress: string, etherscanKey: string, account: any) {
    const abi = await fetch(`https://api.etherscan.io/api?module=contract&action=getabi&address=${contractAddress}&apikey=${etherscanKey}`)
        .then(response => response.json())
        .then(data => JSON.parse(data['result']));

    return deployMockContract(account, abi);
}

describe('MEOWs DAO Token Mint Tests', () => {
    const tokenUnitPrice = ethers.utils.parseEther('0.0125');

    let deployer: SignerWithAddress;
    let accounts: SignerWithAddress[];
    let token: any;

    before(async () => {
        const tokenName = 'Token';
        const tokenSymbol = 'TKN';
        const tokenBaseUri = 'ipfs://hidden';
        const tokenContractUri = 'ipfs://metadata';
        const jbxProjectId = 99;
        const tokenMaxSupply = 8;
        const tokenMintAllowance = 6;

        [deployer, ...accounts] = await ethers.getSigners();

        const mockUniswapQuoter = await deployMockContractFromAddress('0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6', process.env.ETHERSCAN_KEY || '', deployer);
        await mockUniswapQuoter.mock.quoteExactInputSingle.returns('1211000000000000000000');

        const mockUniswapRouter = await deployMockContractFromAddress('0xE592427A0AEce92De3Edee1F18E0157C05861564', process.env.ETHERSCAN_KEY || '', deployer);

        const jbxJbTokensEth = '0x000000000000000000000000000000000000EEEe';
        const ethTerminal = await deployMockContract(deployer, jbETHPaymentTerminal.abi);
        await ethTerminal.mock.addToBalanceOf.returns();
        await ethTerminal.mock.pay.returns();

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
            tokenMintAllowance,
            mockUniswapQuoter.address,
            mockUniswapRouter.address
        );
    });

    it('User mints first: fail due to price', async () => {
        await expect(token.connect(accounts[0])['mint()']({value: tokenUnitPrice}))
            .to.be.revertedWith('INCORRECT_PAYMENT(0)');
    });

    it('User mints first', async () => {
        await expect(token.connect(accounts[0])['mint()']({value: 0}))
            .to.emit(token, 'Transfer');
    });

    it('User mints second: fail due to price', async () => {
        await expect(token.connect(accounts[0])['mint()']({value: 0}))
            .to.be.revertedWith('INCORRECT_PAYMENT(12500000000000000)');
    });

    it('User mints second', async () => {
        await expect(token.connect(accounts[0])['mint()']({value: tokenUnitPrice}))
            .to.emit(token, 'Transfer');
    });

    it('User mints third: fail due to price', async () => {
        await expect(token.connect(accounts[0])['mint()']({value: tokenUnitPrice}))
            .to.be.revertedWith('INCORRECT_PAYMENT(0)');
    });

    it('User mints third', async () => {
        await expect(token.connect(accounts[0])['mint()']({value: 0}))
            .to.emit(token, 'Transfer');
    });

    it('User mints 4-6', async () => {
        await expect(token.connect(accounts[0])['mint()']({value: tokenUnitPrice.mul(3)})).to.emit(token, 'Transfer');
        await expect(token.connect(accounts[0])['mint()']({value: 0})).to.emit(token, 'Transfer');
        await expect(token.connect(accounts[0])['mint()']({value: tokenUnitPrice.mul(5)})).to.emit(token, 'Transfer');

        expect(await token.balanceOf(accounts[0].address)).to.equal(6);
    });

    it('User mints 7: allowance failure', async () => {
        await expect(token.connect(accounts[0])['mint()']({value: 0}))
        .to.be.revertedWith('ALLOWANCE_EXHAUSTED()');
    });

    it('Admin mints', async () => {
        await expect(token.connect(deployer)['mintFor(address)'](accounts[1].address, {value: 0}))
            .to.emit(token, 'Transfer');

        expect(await token.balanceOf(accounts[1].address)).to.equal(1);
    });

    it('Another user mints the rest', async () => {
        await expect(token.connect(accounts[1])['mint()']({value: tokenUnitPrice})).to.emit(token, 'Transfer');
        await expect(token.connect(accounts[1])['mint()']({value: 0})).to.be.revertedWith('SUPPLY_EXHAUSTED()');
    });
});
