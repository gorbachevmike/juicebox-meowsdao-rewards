// eslint-disable-next-line no-unused-vars
import { BigNumber, utils } from 'ethers';

// eslint-disable-next-line node/no-missing-import
import BalanceTree from './BalanceTree';

// This is the blob that gets distributed and pinned to IPFS.
// It is completely sufficient for recreating the entire merkle tree.
// Anyone can verify that all air drops are included in the tree,
// and the tree has no additional distributions.
interface MerkleDistributorInfo {
  merkleRoot: string;
  claims: {
    [account: string]: {
      index: number;
      data: number;
      proof: string[];
    };
  };
}

export function makeSampleSnapshot(addresses: string[], count: number = 0): { [key: string]: number } {
  const snapshot: { [key: string]: number } = {};

  const verified = addresses.filter((a) => utils.isAddress(a));

  for (let i = 0; i < verified.length; i++) {
    let c = count;
    if (count === 0) {
        c = Math.random() * 3;
    }

    snapshot[verified[i]] = Math.ceil(c);
  }

  return snapshot;
}

export function buildMerkleTree(snapshot: { [key: string]: number }): MerkleDistributorInfo {
  const sortedAddresses = Object.keys(snapshot).sort();

  // construct a tree
  const tree = new BalanceTree(
    sortedAddresses.map((address) => ({ account: address, data: snapshot[address] })),
  );

  // generate claims
  const claims = sortedAddresses.reduce<{
    [address: string]: { data: number; index: number; proof: string[] };
  }>((memo, address, index) => {
    memo[address] = {
      index,
      data: snapshot[address],
      proof: tree.getProof(index, address, snapshot[address]),
    };
    return memo;
  }, {});

  return {
    merkleRoot: tree.getHexRoot(),
    claims,
  };
}
