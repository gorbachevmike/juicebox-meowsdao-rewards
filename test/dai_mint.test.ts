import { expect } from 'chai';
import { ethers } from 'hardhat';
import fetch from 'node-fetch';

import { deployMockContract } from '@ethereum-waffle/mock-contract';
import { getContractAddress } from '@ethersproject/address';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { smock } from '@defi-wonderland/smock';

import jbDirectory from '../node_modules/@jbx-protocol/contracts-v2/deployments/mainnet/jbDirectory.json';
import jbETHPaymentTerminal from '../node_modules/@jbx-protocol/contracts-v2/deployments/mainnet/jbETHPaymentTerminal.json';

async function deployMockContractFromAddress(contractAddress: string, etherscanKey: string, account: any) {
    const abi = await fetch(`https://api.etherscan.io/api?module=contract&action=getabi&address=${contractAddress}&apikey=${etherscanKey}`)
        .then(response => response.json())
        .then(data => JSON.parse(data['result']));

    return deployMockContract(account, abi);
}

async function deploySmockContractFromAddress(contractAddress: string, etherscanKey: string) {
    const abi = await fetch(`https://api.etherscan.io/api?module=contract&action=getabi&address=${contractAddress}&apikey=${etherscanKey}`)
        .then(response => response.json())
        .then(data => JSON.parse(data['result']));

    return smock.fake(abi, {address: contractAddress});
}

async function getNextContractAddress(deployer: SignerWithAddress) {
   return getContractAddress({ from: deployer.address, nonce: await deployer.getTransactionCount() });
}

describe('MEOWs DAO Token Mint Tests: DAI', () => {
    const tokenUnitPrice = ethers.utils.parseEther('0.0125');

    let deployer: SignerWithAddress;
    let accounts: SignerWithAddress[];
    let token: any;
    let smockDai: any;
    let smockWeth: any;

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
        await mockUniswapQuoter.mock.quoteExactOutputSingle.returns('1211000000000000000000');

        const mockUniswapRouter = await deployMockContractFromAddress('0xE592427A0AEce92De3Edee1F18E0157C05861564', process.env.ETHERSCAN_KEY || '', deployer);

        smockDai = await deploySmockContractFromAddress('0x6B175474E89094C44Da98b954EedeAC495271d0F', process.env.ETHERSCAN_KEY || '');
        smockDai.transferFrom.returns(true);
        smockDai.approve.returns(true);

        smockWeth = await deploySmockContractFromAddress('0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2', process.env.ETHERSCAN_KEY || '');
        smockWeth.withdraw.returns();

        const jbxJbTokensEth = '0x000000000000000000000000000000000000EEEe';
        const ethTerminal = await deployMockContract(deployer, jbETHPaymentTerminal.abi);
        await ethTerminal.mock.pay.returns(0);

        const daiTerminal = await deployMockContract(deployer, jbETHPaymentTerminal.abi);
        await daiTerminal.mock.pay.returns(0);

        const mockDirectory = await deployMockContract(deployer, jbDirectory.abi);
        await mockDirectory.mock.isTerminalOf.withArgs(jbxProjectId, ethTerminal.address).returns(true);
        await mockDirectory.mock.primaryTerminalOf.withArgs(jbxProjectId, jbxJbTokensEth).returns(ethTerminal.address);
        await mockDirectory.mock.isTerminalOf.withArgs(jbxProjectId, daiTerminal.address).returns(true);
        await mockDirectory.mock.primaryTerminalOf.withArgs(jbxProjectId, smockDai.address).returns(daiTerminal.address);

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

    it('User mints second: fail due to unapproved token', async () => {
        await expect(token.connect(accounts[0])['mint()']({value: 0})).to.emit(token, 'Transfer');

        await expect(token.connect(accounts[0])['mint(address)'](smockDai.address, {value: tokenUnitPrice}))
            .to.be.revertedWith('UNAPPROVED_TOKEN()');
    });

    it('User mints second', async () => {
        await token.connect(deployer).updatePaymentTokenList(smockDai.address, true);

        await expect(token.connect(accounts[0])['mint(address)'](smockDai.address, {value: tokenUnitPrice}))
            .to.emit(token, 'Transfer');
    });
});
