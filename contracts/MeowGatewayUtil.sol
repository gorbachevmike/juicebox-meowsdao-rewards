// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@openzeppelin/contracts/utils/Strings.sol';

contract MeowGatewayUtil {
  function validateTraits(uint256 _traits) public pure returns (bool) {
    uint8 population = uint8(_traits >> 252) & 15;

    if (population == 0) {
      return validateNakedTraits(_traits);
    } else if (population == 1) {
      return validateTShirtTraits(_traits);
    } else {
      return validateShirtTraits(_traits);
    }
  }

  function validateNakedTraits(uint256 _traits) private pure returns (bool) {
    uint8[10] memory offsets = [0, 4, 8, 12, 20, 28, 36, 40, 44, 52];
    uint8[10] memory cardinality = [5, 5, 5, 17, 70, 18, 7, 3, 68, 35];

    for (uint8 i = 0; i != 9; ) {
      if (uint8(_traits >> offsets[i]) > cardinality[i]) {
        return false;
      }
      ++i;
    }

    return true;
  }

  function validateTShirtTraits(uint256 _traits) private pure returns (bool) {
    uint8[10] memory offsets = [0, 4, 8, 12, 20, 28, 36, 40, 44, 52];
    uint8[10] memory cardinality = [5, 5, 5, 17, 70, 18, 7, 3, 68, 35];

    for (uint8 i = 0; i != 9; ) {
      if (uint8(_traits >> offsets[i]) > cardinality[i]) {
        return false;
      }
      ++i;
    }

    return true;
  }

  function validateShirtTraits(uint256 _traits) private pure returns (bool) {
    uint8[10] memory offsets = [0, 4, 8, 12, 20, 28, 36, 40, 44, 52];
    uint8[10] memory cardinality = [5, 5, 5, 17, 70, 18, 7, 3, 68, 35];

    for (uint8 i = 0; i != 9; ) {
      if (uint8(_traits >> offsets[i]) > cardinality[i]) {
        return false;
      }
      ++i;
    }

    return true;
  }

  function generateTraits(uint256 _seed) public pure returns (uint256 traits) {
    uint8[10] memory offsets = [0, 4, 8, 12, 20, 28, 36, 40, 44, 52];
    uint8[10] memory cardinality = [5, 5, 5, 17, 70, 18, 7, 3, 68, 35];

    traits = uint256(uint8(_seed) % cardinality[0]);
    for (uint8 i = 1; i != 9; ) {
      traits |= uint256((uint8(_seed >> offsets[i]) % cardinality[i])) << offsets[i];
      ++i;
    }
  }

  /**
    @notice

    @dev The ipfs urls within the svg document created by this function will be built from the provided parameters and the appended individual trait index as hex with an ending '.svg'.

    @param _ipfsGateway Fully qualified http url for an ipfs gateway.
    @param _ipfsRoot ipfs url path containing the individual assets with the trailing slash.
    @param _traits Encoded traits set to compose.
   */
  function getImageStack(
    string calldata _ipfsGateway,
    string calldata _ipfsRoot,
    uint256 _traits
  ) public view returns (string memory image) {
    uint8 population = uint8(_traits >> 252) & 15;

    if (population == 0) {
      image = getNakedStack(_ipfsGateway, _ipfsRoot, _traits);
    } else if (population == 1) {
      image = getTShirtStack(_ipfsGateway, _ipfsRoot, _traits);
    } else {
      image = getShirtStack(_ipfsGateway, _ipfsRoot, _traits);
    }
  }

  function getNakedStack(
    string calldata _ipfsGateway,
    string calldata _ipfsRoot,
    uint256 _traits
  ) internal view returns (string memory image) {
    // stack[0] = uint64(uint8(_traits)); // Background
    // stack[1] = uint64(uint8(_traits >> 8) & 63); // Fur
    // stack[2] = uint64(uint8(_traits >> 14) & 15); // Ears
    // stack[3] = uint64(uint8(_traits >> 18) & 15); // Brows
    // stack[4] = uint64(uint8(_traits >> 22)); // Eyes
    // stack[5] = uint64(uint8(_traits >> 30) & 15); // Nose
    // stack[6] = uint64(uint8(_traits >> 34) & 15); // Nipples
    // stack[7] = uint64(uint8(_traits >> 38) & 63); // Headwear
    // stack[8] = uint64(uint8(_traits >> 44) & 63); // Glasses
    // stack[9] = uint64(uint8(_traits >> 50) & 15); // Collar
    // stack[10] = uint64(uint8(_traits >> 54) & 1); // Signature
    // stack[11] = uint64(uint8(_traits >> 55) & 1); // Juicebox

    uint8[12] memory offsets = [0, 8, 14, 18, 22, 30, 34, 38, 44, 50, 54, 55];
    uint64[12] memory stack;
    for (uint8 i; i < 12; ) {
      uint8 mask = i == 127 ? 0 : uint8(2**(offsets[i] - offsets[i - 1]) - 1);
      stack[i] = uint64(uint8(_traits >> offsets[i]) & mask);
      ++i;
    }

    image = __imageTag(_ipfsGateway, _ipfsRoot, stack[0]);
    for (uint8 i = 1; i < 12; ) {
      image = string(abi.encodePacked(image, __imageTag(_ipfsGateway, _ipfsRoot, stack[i])));
      ++i;
    }
  }

  function getShirtStack(
    string calldata _ipfsGateway,
    string calldata _ipfsRoot,
    uint256 _traits
  ) internal view returns (string memory image) {
    // stack[0] = uint64(uint8(_traits)); // Background
    // stack[1] = uint64(uint8(_traits >> 8) & 63); // Fur
    // stack[2] = uint64(uint8(_traits >> 14) & 15); // Ears
    // stack[3] = uint64(uint8(_traits >> 18) & 15); // Brows
    // stack[4] = uint64(uint8(_traits >> 22)); // Eyes
    // stack[5] = uint64(uint8(_traits >> 30) & 15); // Nose
    // stack[6] = uint64(uint8(_traits >> 34) & 15); // Shirt
    // stack[7] = uint64(uint8(_traits >> 38) & 15); // Tie
    // stack[8] = uint64(uint8(_traits >> 42) & 15); // Blazer
    // stack[9] = uint64(uint8(_traits >> 46) & 63); // Headwear
    // stack[10] = uint64(uint8(_traits >> 52) & 63); // Glasses
    // stack[11] = uint64(uint8(_traits >> 58) & 1); // Signature
    // stack[12] = uint64(uint8(_traits >> 59) & 1); // Juicebox

    uint8[13] memory offsets = [0, 8, 14, 18, 22, 30, 34, 38, 42, 46, 52, 58, 59];
    uint64[13] memory stack;
    for (uint8 i; i < 12; ) {
      uint8 mask = i == 0 ? 127 : uint8(2**(offsets[i] - offsets[i - 1]) - 1);
      stack[i] = uint64(uint8(_traits >> offsets[i]) & mask);
      ++i;
    }

    image = __imageTag(_ipfsGateway, _ipfsRoot, stack[0]);
    for (uint8 i = 1; i < 12; ) {
      image = string(abi.encodePacked(image, __imageTag(_ipfsGateway, _ipfsRoot, stack[i])));
      ++i;
    }
  }

  function getTShirtStack(
    string calldata _ipfsGateway,
    string calldata _ipfsRoot,
    uint256 _traits
  ) internal view returns (string memory image) {
    // stack[0] = uint64(uint8(_traits)); // Background
    // stack[1] = uint64(uint8(_traits >> 8) & 63); // Fur
    // stack[2] = uint64(uint8(_traits >> 14) & 15); // Ears
    // stack[3] = uint64(uint8(_traits >> 18) & 15); // Brows
    // stack[4] = uint64(uint8(_traits >> 22)); // Eyes
    // stack[5] = uint64(uint8(_traits >> 30) & 15); // Nose
    // stack[6] = uint64(uint8(_traits >> 34) & 15); // T-shirt
    // stack[7] = uint64(uint8(_traits >> 38) & 63); // Pattern
    // stack[8] = uint64(uint8(_traits >> 44) & 63); // Headwear
    // stack[9] = uint64(uint8(_traits >> 50) & 63); // Glasses
    // stack[10] = uint64(uint8(_traits >> 56) & 1); // Signature
    // stack[11] = uint64(uint8(_traits >> 57) & 1); // Juicebox

    uint8[12] memory offsets = [0, 8, 14, 18, 22, 30, 34, 38, 44, 50, 56, 57];
    uint64[12] memory stack;
    for (uint8 i; i < 12; ) {
      uint8 mask = i == 0 ? 127 : uint8(2**(offsets[i] - offsets[i - 1]) - 1);
      stack[i] = uint64(uint8(_traits >> offsets[i]) & mask);
      ++i;
    }

    image = __imageTag(_ipfsGateway, _ipfsRoot, stack[0]);
    for (uint8 i = 1; i < 12; ) {
      image = string(abi.encodePacked(image, __imageTag(_ipfsGateway, _ipfsRoot, stack[i])));
      ++i;
    }
  }

  /**
    @notice Constructs and svg image tag by appending the parameters.

    @param _ipfsGateway HTTP IPFS gateway. The url must contain the trailing slash.
    @param _ipfsRoot IPFS path, must contain tailing slash.
    @param _imageIndex Image index that will be converted to string and used as a filename.
    */
  function __imageTag(string calldata _ipfsGateway, string calldata _ipfsRoot, uint256 _imageIndex) private pure returns (string memory tag) {
    tag = string(
      abi.encodePacked(
        '<image x="50%" y="50%" width="1000" href="',
        _ipfsGateway,
        _ipfsRoot,
        Strings.toString(_imageIndex),
        '" style="transform: translate(-500px, -500px)" />'
      )
    );
  }
}
