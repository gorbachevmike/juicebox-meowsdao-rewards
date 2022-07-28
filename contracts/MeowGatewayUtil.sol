// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@openzeppelin/contracts/utils/Base64.sol';
import '@openzeppelin/contracts/utils/Strings.sol';

// stack[0] = uint64(uint8(_traits)); // Background 165
// stack[1] = uint64(uint8(_traits >> 8) & 63); // Fur 25
// stack[2] = uint64(uint8(_traits >> 14) & 15); // Ears 2
// stack[3] = uint64(uint8(_traits >> 18) & 15); // Brows 2
// stack[4] = uint64(uint8(_traits >> 22) & 63); // Eyes 36
// stack[5] = uint64(uint8(_traits >> 30) & 15); // Nose 19

// stack[6] = uint64(uint8(_traits >> 34) & 15); // Nipples 2 // naked
// stack[6] = uint64(uint8(_traits >> 38) & 15); // Shirt 11 // shirt
// stack[7] = uint64(uint8(_traits >> 42) & 15); // Tie 10 // shirt
// stack[8] = uint64(uint8(_traits >> 46) & 15); // Blazer 7 // shirt
// stack[6] = uint64(uint8(_traits >> 50) & 15); // T-shirt 13 // tshirt
// stack[7] = uint64(uint8(_traits >> 54) & 63); // Pattern 34 // tshirt

// stack[7] = uint64(uint8(_traits >> 60) & 63); // Headwear 31
// stack[8] = uint64(uint8(_traits >> 66) & 63); // Glasses 37
// stack[9] = uint64(uint8(_traits >> 72) & 15); // Collar 14 // naked
// stack[10] = uint64(uint8(_traits >> 76) & 1); // Signature 1
// stack[11] = uint64(uint8(_traits >> 77) & 1); // Juicebox 1

/**
  @notice MEOWs DAO NFT helper functions for managing IPFS image assets.
 */
contract MeowGatewayUtil {
  uint8[12] private nakedOffsets = [0, 8, 14, 18, 22, 30, 34, 60, 66, 72, 76, 77];
  uint8[12] private nakedCardinality = [165, 25, 2, 2, 36, 19, 2, 31, 37, 14, 1, 1];
  uint8[12] private nakedMask = [255, 63, 15, 15, 63, 15, 15, 63, 63, 15, 1, 1];
  uint8[12] private tShirtOffsets = [0, 8, 14, 18, 22, 30, 50, 54, 60, 66, 76, 77];
  uint8[12] private tShirtCardinality = [165, 25, 2, 2, 37, 19, 13, 34, 31, 37, 1, 1];
  uint8[12] private tShirtMask = [255, 63, 15, 15, 63, 15, 15, 63, 63, 63, 1, 1];
  uint8[13] private shirtOffsets = [0, 8, 14, 18, 22, 30, 38, 42, 46, 60, 66, 76, 77];
  uint8[13] private shirtCardinality = [165, 25, 2, 2, 36, 19, 11, 10, 7, 31, 37, 1, 1];
  uint8[13] private shirtMask = [255, 63, 15, 15, 63, 15, 15, 15, 15, 63, 63, 1, 1];

  function validateTraits(uint256 _traits) public view returns (bool) {
    uint8 population = uint8(_traits >> 252) & 15;

    if (population == 0) {
      return validateNakedTraits(_traits);
    } else if (population == 1) {
      return validateTShirtTraits(_traits);
    } else {
      return validateShirtTraits(_traits);
    }
  }

  function validateNakedTraits(uint256 _traits) private view returns (bool) {
    for (uint8 i = 0; i != 12; ) {
      if (uint8(_traits >> nakedOffsets[i]) & nakedMask[i] > nakedCardinality[i]) {
        return false;
      }
      ++i;
    }

    return true;
  }

  function validateTShirtTraits(uint256 _traits) private view returns (bool) {
    for (uint8 i = 0; i != 12; ) {
      if (uint8(_traits >> tShirtOffsets[i]) & tShirtMask[i] > tShirtCardinality[i]) {
        return false;
      }
      ++i;
    }

    return true;
  }

  function validateShirtTraits(uint256 _traits) private view returns (bool) {
    for (uint8 i = 0; i != 13; ) {
      if (uint8(_traits >> shirtOffsets[i]) & shirtMask[i] > shirtCardinality[i]) {
        return false;
      }
      ++i;
    }

    return true;
  }

  function generateTraits(uint256 _seed) public view returns (uint256 traits) {
    uint8 population = uint8(_seed >> 252) & 15;

    if (population == 0) {
      return generateNakedTraits(_seed);
    } else if (population == 1) {
      return generateTShirtTraits(_seed);
    } else {
      return generateShirtTraits(_seed);
    }
  }

  function generateNakedTraits(uint256 _seed) private view returns (uint256 traits) {
    traits = uint256(uint8(_seed) % nakedCardinality[0]);
    for (uint8 i = 1; i != 12; ) {
      traits |= uint256((uint8(_seed >> nakedOffsets[i]) % nakedCardinality[i])) << nakedOffsets[i];
      ++i;
    }
  }

  function generateTShirtTraits(uint256 _seed) private view returns (uint256 traits) {
    traits = uint256(uint8(_seed) % tShirtCardinality[0]);
    for (uint8 i = 1; i != 12; ) {
      traits |= uint256((uint8(_seed >> tShirtOffsets[i]) % tShirtCardinality[i])) << tShirtOffsets[i];
      ++i;
    }
  }

  function generateShirtTraits(uint256 _seed) private view returns (uint256 traits) {
    traits = uint256(uint8(_seed) % shirtCardinality[0]);
    for (uint8 i = 1; i != 13; ) {
      traits |= uint256((uint8(_seed >> shirtOffsets[i]) % shirtCardinality[i])) << shirtOffsets[i];
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
    string memory _ipfsGateway,
    string memory _ipfsRoot,
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
    string memory _ipfsGateway,
    string memory _ipfsRoot,
    uint256 _traits
  ) internal view returns (string memory image) {
    image = __imageTag(_ipfsGateway, _ipfsRoot, uint64(uint8(_traits >> nakedOffsets[0]) & nakedMask[0]));
    for (uint8 i = 1; i < 12; ) {
      image = string(abi.encodePacked(image, __imageTag(_ipfsGateway, _ipfsRoot, uint64(uint8(_traits >> nakedOffsets[i]) & nakedMask[i]))));
      ++i;
    }
  }

  function getTShirtStack(
    string memory _ipfsGateway,
    string memory _ipfsRoot,
    uint256 _traits
  ) internal view returns (string memory image) {
    image = __imageTag(_ipfsGateway, _ipfsRoot, uint64(uint8(_traits >> tShirtOffsets[0]) & tShirtMask[0]));
    for (uint8 i = 1; i < 12; ) {
      image = string(abi.encodePacked(image, __imageTag(_ipfsGateway, _ipfsRoot, uint64(uint8(_traits >> tShirtOffsets[i]) & tShirtMask[i]))));
      ++i;
    }
  }

  function getShirtStack(
    string memory _ipfsGateway,
    string memory _ipfsRoot,
    uint256 _traits
  ) internal view returns (string memory image) {
    image = __imageTag(_ipfsGateway, _ipfsRoot, uint64(uint8(_traits >> shirtOffsets[0]) & shirtMask[0]));
    for (uint8 i = 1; i < 13; ) {
      image = string(abi.encodePacked(image, __imageTag(_ipfsGateway, _ipfsRoot, uint64(uint8(_traits >> shirtOffsets[i]) & shirtMask[i]))));
      ++i;
    }
  }

  function generateSeed(
    address _account,
    uint256 _blockNumber,
    uint256 _other
  ) internal pure returns (uint256 seed) {
    seed = uint256(keccak256(abi.encodePacked(_account, _blockNumber, _other)));
  }

  function dataUri(
    string memory _ipfsGateway,
    string memory _ipfsRoot,
    uint256 _traits,
    string memory _name,
    uint256 _tokenId
  ) internal view returns (string memory) {
      string memory image = string(
        abi.encodePacked(
          '<svg id="token" width="300" height="300" viewBox="0 0 1080 1080" fill="none" xmlns="http://www.w3.org/2000/svg"><g id="bannyPlaceholder">',
          getImageStack(_ipfsGateway, _ipfsRoot, _traits),
          '</g></svg>'
        )
      );

      string memory json = Base64.encode(
      abi.encodePacked(
        '{"name": "',
        _name,
        ' No.',
        Strings.toString(_tokenId),
        '", "description": "Fully on-chain NFT", "image": "data:image/svg+xml;base64,',
        image,
        '", "attributes":',
        '{}' // TODO: metadata
        '}'
      )
    );

    return string(abi.encodePacked('data:application/json;base64,', json));
  }

  /**
    @notice Constructs and svg image tag by appending the parameters.

    @param _ipfsGateway HTTP IPFS gateway. The url must contain the trailing slash.
    @param _ipfsRoot IPFS path, must contain tailing slash.
    @param _imageIndex Image index that will be converted to string and used as a filename.
    */
  function __imageTag(
    string memory _ipfsGateway,
    string memory _ipfsRoot,
    uint256 _imageIndex
  ) private pure returns (string memory tag) {
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
