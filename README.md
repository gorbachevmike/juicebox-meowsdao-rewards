# DataSourceDelegate Generative MeowsDAO

## Contracts

A collection of NFTs with various features that interface with Juicebox treasury contracts.

### Token

A "regular" NFT which allows minting of a limited set of NFTs with ipfs-bound assets and metadata.

### JBTierRewardToken

A Juicebox contribution reward NFT modeled on the [JBX Contribution NFT Reward Mechanism](https://github.com/jbx-protocol/juice-nft-rewards).

## Commands

- `npx hardhat compile`
- `npx hardhat test`
- `npx hardhat coverage`
- `npx hardhat docgen`
- `npx hardhat run scripts/deployAssets.ts` renames and uploads assets to IPFS using the [nft.storage](https://nft.storage/) service.

## Testing

This contract relies on a significant amount of chain state, only some of the interactions are mocked. More practically, consider running a local for like this `npx hardhat node --fork https://eth-mainnet.alchemyapi.io/v2/<ALCHEMY_KEY> --fork-block-number <BLOCK_NUMBER>` and switching to `'localhost'` default network in `hardhat.config.ts`.

## Environment Configuration

- PRIVATE_KEY
- RINKEBY_URL
- ALCHEMY_RINKEBY_KEY
- ETHERSCAN_KEY
- COINMARKETCAP_KEY
- NFT_STORAGE_API_KEY
- REPORT_GAS
