// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@openzeppelin/contracts/utils/Base64.sol';
import '@openzeppelin/contracts/utils/Strings.sol';

/**
  @notice MEOWs DAO NFT helper functions for managing IPFS image assets.
 */
library MeowGatewayUtil {
  // Trait,Cardinality,Offset,Mask

  // Background,86,0,127
  // Fur,25,8,63
  // Ears 2 14 15
  // Brows 3 18, 15
  // Eyes 32,22,63
  // Nose 18,28,31

  // Collar,14,34,15 // naked
  // Nipples 2,38,15 // naked
  // Shirt 10,42,15 // shirt
  // Tie 10,46,15 // shirt
  // Blazer 6,50,15 // shirt
  // T-shirt 12,54,15 // tshirt
  // Pattern 33,58,63 // tshirt

  // Headwear,29,64,31
  // Special Headwear,19,70,31

  // Glasses 35,76,63
  // Signature 1,82,1
  // Juicebox 1,83,1

  function specialNakedOffsets() private pure returns (uint8[12] memory) {
    return [0, 8, 14, 18, 22, 28, 34, 38, 70, 76, 82, 83];
  }

  function specialNakedCardinality() private pure returns (uint8[12] memory) {
    return [86, 25, 2, 3, 32, 18, 14, 2, 19, 35, 1, 1];
  }

  function specialNakedMask() private pure returns (uint8[12] memory) {
    return [127, 63, 15, 15, 63, 15, 15, 31, 31, 63, 1, 1];
  }

  function nakedOffsets() private pure returns (uint8[12] memory) {
    return [0, 8, 14, 18, 22, 28, 34, 38, 64, 76, 82, 83];
  }

  function nakedCardinality() private pure returns (uint8[12] memory) {
    return [86, 25, 2, 3, 32, 18, 14, 2, 29, 35, 1, 1];
  }

  function nakedMask() private pure returns (uint8[12] memory) {
    return [127, 63, 15, 15, 63, 15, 15, 31, 31, 63, 1, 1];
  }

  function tShirtOffsets() private pure returns (uint8[12] memory) {
    return [0, 8, 14, 18, 22, 28, 54, 58, 64, 76, 82, 83];
  }

  function tShirtCardinality() private pure returns (uint8[12] memory) {
    return [86, 25, 2, 3, 32, 18, 12, 33, 29, 35, 1, 1];
  }

  function tShirtMask() private pure returns (uint8[12] memory) {
    return [127, 63, 15, 15, 63, 31, 15, 31, 31, 63, 1, 1];
  }

  function shirtOffsets() private pure returns (uint8[13] memory) {
    return [0, 8, 14, 18, 22, 28, 42, 46, 50, 64, 76, 82, 83];
  }

  function shirtCardinality() private pure returns (uint8[13] memory) {
    return [86, 25, 2, 3, 32, 18, 10, 10, 6, 29, 35, 1, 1];
  }

  function shirtMask() private pure returns (uint8[13] memory) {
    return [127, 63, 15, 15, 63, 31, 15, 15, 15, 31, 63, 1, 1];
  }

  function validateTraits(uint256 _traits) public view returns (bool) {
    uint8 population = uint8(_traits >> 252);

    if (population == 1 || population == 2) {
      for (uint8 i = 0; i != 13; ) {
        if (uint8(_traits >> shirtOffsets()[i]) & shirtMask()[i] > shirtCardinality()[i]) {
          return false;
        }
        ++i;
      }

      return true;
    } else if (population == 3) {
      for (uint8 i = 0; i != 12; ) {
        if (uint8(_traits >> tShirtOffsets()[i]) & tShirtMask()[i] > tShirtCardinality()[i]) {
          return false;
        }
        ++i;
      }
      return true;
    } else if (population == 4) {
      for (uint8 i = 0; i != 12; ) {
        if (uint8(_traits >> nakedOffsets()[i]) & nakedMask()[i] > nakedCardinality()[i]) {
          return false;
        }
        ++i;
      }

      return true;
    } else if (population == 5) {
      for (uint8 i = 0; i != 12; ) {
        if (
          uint8(_traits >> specialNakedOffsets()[i]) & specialNakedMask()[i] >
          specialNakedCardinality()[i]
        ) {
          return false;
        }
        ++i;
      }

      return true;
    }
  }

  function generateTraits(uint256 _seed) public view returns (uint256 traits) {
    uint8 population = uint8(_seed >> 252);

    if (population == 1) { // tier 1 is expected to be a free mint
        traits = 9671406556917033397649408
            | 4835703278458516698824704
            | 1586715138244200791801856
            | 276701161105643274240
            | 5629499534213120
            | 351843720888320
            | 43980465111040
            | 805306368
            | 33554432
            | 786432
            | 16384
            | 4352
            | 86; // TODO: free mint
    } else if (population == 2) {
      traits = uint256(uint8(_seed) % shirtCardinality()[0]);
      for (uint8 i = 1; i != 13; ) {
        traits |=
          uint256((uint8(_seed >> shirtOffsets()[i]) % shirtCardinality()[i]) + 1) <<
          shirtOffsets()[i];
        ++i;
      }
    } else if (population == 3) {
      traits = uint256(uint8(_seed) % tShirtCardinality()[0]);
      for (uint8 i = 1; i != 12; ) {
        traits |=
          uint256((uint8(_seed >> tShirtOffsets()[i]) % tShirtCardinality()[i]) + 1) <<
          tShirtOffsets()[i];
        ++i;
      }
    } else if (population == 4) {
      traits = uint256(uint8(_seed) % nakedCardinality()[0]);
      for (uint8 i = 1; i != 12; ) {
        traits |=
          uint256((uint8(_seed >> nakedOffsets()[i]) % nakedCardinality()[i]) + 1) <<
          nakedOffsets()[i];
        ++i;
      }
    } else if (population == 5) {
      traits = uint256(uint8(_seed) % specialNakedCardinality()[0]);
      for (uint8 i = 1; i != 12; ) {
        traits |=
          uint256((uint8(_seed >> specialNakedOffsets()[i]) % specialNakedCardinality()[i]) + 1) <<
          specialNakedOffsets()[i];
        ++i;
      }
    }

    traits |= uint256(population) << 252;
  }

  function listTraits(uint256 _traits) public view returns (string memory names) {
    uint8 population = uint8(_traits >> 252);

    string memory group;
    string memory name;
    if (population == 1 || population == 2) {
      (group, name) = nameForTraits(0, (uint8(_traits >> shirtOffsets()[0]) & shirtMask()[0]) - 1);
      names = string(abi.encodePacked('"', group, '":"', name, '"'));
      for (uint8 i = 1; i != 13; ) {
        (group, name) = nameForTraits(
          shirtOffsets()[i],
          (uint8(_traits >> shirtOffsets()[i]) & shirtMask()[i]) - 1 // NOTE trait ids are not 0-based
        );
        names = string(abi.encodePacked(names, ',"', group, '":"', name, '"'));
        ++i;
      }
    } else if (population == 3) {
      (group, name) = nameForTraits(
        0,
        (uint8(_traits >> tShirtOffsets()[0]) & tShirtMask()[0]) - 1
      );
      names = string(abi.encodePacked('"', group, '":"', name, '"'));
      for (uint8 i = 1; i != 12; ) {
        (group, name) = nameForTraits(
          tShirtOffsets()[i],
          (uint8(_traits >> tShirtOffsets()[i]) & tShirtMask()[i]) - 1 // NOTE trait ids are not 0-based
        );
        names = string(abi.encodePacked(names, ',"', group, '":"', name, '"'));
        ++i;
      }
    } else if (population == 4) {
      (group, name) = nameForTraits(0, (uint8(_traits >> nakedOffsets()[0]) & nakedMask()[0]) - 1);
      names = string(abi.encodePacked('"', group, '":"', name, '"'));

      for (uint8 i = 1; i != 12; ) {
        (group, name) = nameForTraits(
          nakedOffsets()[i],
          (uint8(_traits >> nakedOffsets()[i]) & nakedMask()[i]) - 1 // NOTE trait ids are not 0-based
        );
        names = string(abi.encodePacked(names, ',"', group, '":"', name, '"'));
        ++i;
      }
    } else if (population == 5) {
      (group, name) = nameForTraits(
        0,
        (uint8(_traits >> specialNakedOffsets()[0]) & specialNakedMask()[0]) - 1
      );
      names = string(abi.encodePacked('"', group, '":"', name, '"'));

      for (uint8 i = 1; i != 12; ) {
        (group, name) = nameForTraits(
          specialNakedOffsets()[i],
          (uint8(_traits >> specialNakedOffsets()[i]) & specialNakedMask()[i]) - 1 // NOTE trait ids are not 0-based
        );
        names = string(abi.encodePacked(names, ',"', group, '":"', name, '"'));
        ++i;
      }
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
    uint8 population = uint8(_traits >> 252);

    if (population == 1 || population == 2) {
      image = getShirtStack(_ipfsGateway, _ipfsRoot, _traits);
    } else if (population == 3) {
      image = getTShirtStack(_ipfsGateway, _ipfsRoot, _traits);
    } else if (population == 4) {
      image = getNakedStack(_ipfsGateway, _ipfsRoot, _traits);
    } else if (population == 5) {
      image = getSpecialNakedStack(_ipfsGateway, _ipfsRoot, _traits);
    }
  }

  function getSpecialNakedStack(
    string memory _ipfsGateway,
    string memory _ipfsRoot,
    uint256 _traits
  ) private view returns (string memory image) {
    image = __imageTag(
      _ipfsGateway,
      _ipfsRoot,
      uint256(uint8(_traits >> specialNakedOffsets()[0]) & specialNakedMask()[0])
    );
    for (uint8 i = 1; i < 12; ) {
      image = string(
        abi.encodePacked(
          image,
          __imageTag(
            _ipfsGateway,
            _ipfsRoot,
            uint256(uint8(_traits >> specialNakedOffsets()[i]) & specialNakedMask()[i]) <<
              specialNakedOffsets()[i]
          )
        )
      );
      ++i;
    }
  }

  function getNakedStack(
    string memory _ipfsGateway,
    string memory _ipfsRoot,
    uint256 _traits
  ) private view returns (string memory image) {
    image = __imageTag(
      _ipfsGateway,
      _ipfsRoot,
      uint256(uint8(_traits >> nakedOffsets()[0]) & nakedMask()[0])
    );
    for (uint8 i = 1; i < 12; ) {
      image = string(
        abi.encodePacked(
          image,
          __imageTag(
            _ipfsGateway,
            _ipfsRoot,
            uint256(uint8(_traits >> nakedOffsets()[i]) & nakedMask()[i]) << nakedOffsets()[i]
          )
        )
      );
      ++i;
    }
  }

  function getTShirtStack(
    string memory _ipfsGateway,
    string memory _ipfsRoot,
    uint256 _traits
  ) private view returns (string memory image) {
    image = __imageTag(
      _ipfsGateway,
      _ipfsRoot,
      uint256(uint8(_traits >> tShirtOffsets()[0]) & tShirtMask()[0])
    );
    for (uint8 i = 1; i < 12; ) {
      image = string(
        abi.encodePacked(
          image,
          __imageTag(
            _ipfsGateway,
            _ipfsRoot,
            uint256(uint8(_traits >> tShirtOffsets()[i]) & tShirtMask()[i]) << tShirtOffsets()[i]
          )
        )
      );
      ++i;
    }
  }

  function getShirtStack(
    string memory _ipfsGateway,
    string memory _ipfsRoot,
    uint256 _traits
  ) private view returns (string memory image) {
    image = __imageTag(
      _ipfsGateway,
      _ipfsRoot,
      uint256(uint8(_traits >> shirtOffsets()[0]) & shirtMask()[0])
    );
    for (uint8 i = 1; i < 13; ) {
      image = string(
        abi.encodePacked(
          image,
          __imageTag(
            _ipfsGateway,
            _ipfsRoot,
            uint256(uint8(_traits >> shirtOffsets()[i]) & shirtMask()[i]) << shirtOffsets()[i]
          )
        )
      );
      ++i;
    }
  }

  function generateSeed(
    address _account,
    uint256 _blockNumber,
    uint256 _other
  ) public view returns (uint256 seed) {
    seed = uint256(keccak256(abi.encodePacked(_account, _blockNumber, _other)));
  }

  function dataUri(
    string memory _ipfsGateway,
    string memory _ipfsRoot,
    uint256 _traits,
    string memory _name,
    uint256 _tokenId
  ) public view returns (string memory) {
    string memory image = Base64.encode(
      abi.encodePacked(
        '<svg id="token" width="1000" height="1000" viewBox="0 0 1080 1080" fill="none" xmlns="http://www.w3.org/2000/svg"><g id="bannyPlaceholder">',
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
        '", "description": "An on-chain NFT", "image": "data:image/svg+xml;base64,',
        image,
        '", "attributes": {',
        listTraits(_traits),
        '} }'
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
  ) private view returns (string memory tag) {
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

  function nameForTraits(uint8 _offset, uint8 _index)
    private
    view
    returns (string memory group, string memory trait)
  {
    if (_offset == 0) {
      group = 'Background';
      trait = nameForBackgroundTrait(_index);
    } else if (_offset == 8) {
      group = 'Fur';
      trait = nameForFurTrait(_index);
    } else if (_offset == 14) {
      group = 'Ears';
      trait = nameForEarsTrait(_index);
    } else if (_offset == 18) {
      group = 'Brows';
      trait = nameForBrowsTrait(_index);
    } else if (_offset == 22) {
      group = 'Eyes';
      trait = nameForEyesTrait(_index);
    } else if (_offset == 28) {
      group = 'Nose';
      trait = nameForNoseTrait(_index);
    } else if (_offset == 34) {
      group = 'Collar';
      trait = nameForCollarTrait(_index);
    } else if (_offset == 38) {
      group = 'Nipples';
      trait = nameForNipplesTrait(_index);
    } else if (_offset == 42) {
      group = 'Shirt';
      trait = nameForShirtTrait(_index);
    } else if (_offset == 46) {
      group = 'Tie';
      trait = nameForTieTrait(_index);
    } else if (_offset == 50) {
      group = 'Blazer';
      trait = nameForBlazerTrait(_index);
    } else if (_offset == 54) {
      group = 'T-shirt';
      trait = nameForTshirtTrait(_index);
    } else if (_offset == 58) {
      group = 'Pattern';
      trait = nameForPatternTrait(_index);
    } else if (_offset == 64) {
      group = 'Headwear';
      trait = nameForHeadwearTrait(_index);
    } else if (_offset == 70) {
      group = 'Special Headwear';
      trait = nameForSpecialHeadwearTrait(_index);
    } else if (_offset == 76) {
      group = 'Glasses';
      trait = nameForGlassesTrait(_index);
    } else if (_offset == 82) {
      group = 'Signature';
      trait = 'Natasha';
    } else if (_offset == 83) {
      group = 'Juicebox';
      trait = 'Yes';
    } else {
      group = '';
      trait = '';
    }
  }

  function nameForBackgroundTrait(uint8 _index) private view returns (string memory name) {
    string[86] memory traits = [
      'Balloons orange',
      'Balloons pink',
      'Balloons white',
      'Blue green',
      'Blue violet',
      'Clouds green',
      'Clouds green yellow',
      'Clouds grey',
      'Clouds orange',
      'Clouds pink',
      'Clouds white',
      'Diamonds blue green',
      'Diamonds pink',
      'Diamonds white',
      'Ethereum on green',
      'Ethereum on grey',
      'Ethereum on orange',
      'Ethereum on pink',
      'Ethereum on white',
      'Fastfood blue green',
      'Fastfood blue violet',
      'Fastfood green yellow',
      'Fastfood orange',
      'Fastfood pink green',
      'Fastfood white',
      'Fish blue green',
      'Fish green yellow',
      'Fish grey',
      'Fish orange',
      'Fish pink',
      'Fish white',
      'Fishtank blue green',
      'Fishtank green yellow',
      'Fishtank grey blue',
      'Fishtank orange',
      'Fishtank white',
      'Foodbowl green yellow',
      'Foodbowl grey',
      'Foodbowl grey blue',
      'Foodbowl pink',
      'Foodbowl white',
      'Green',
      'Green yellow',
      'Grey',
      'Grey blue',
      'Grey eth on blue',
      'Grey eth on blue green',
      'Grey eth on orange',
      'Grey eth on white',
      'Juicebox black blue green',
      'Juicebox black orange',
      'Juicebox black white',
      'Juicebox blue green',
      'Juicebox green yellow',
      'Juicebox orange',
      'Juicebox white',
      'Milkbox blue green',
      'Milkbox green yellow',
      'Milkbox grey blue',
      'Milkbox orange',
      'Milkbox pink',
      'Milkbox white',
      'Orange',
      'Pastel eth on blue green',
      'Pastel eth on grey',
      'Pastel eth on orange',
      'Pastel eth on pink',
      'Pastel eth on white',
      'Paws blue green',
      'Paws orange',
      'Paws pink',
      'Paws white',
      'Pink',
      'Pink green',
      'Pizza blue green',
      'Pizza green yellow',
      'Pizza pink',
      'Pizza white',
      'Planets',
      'Rainbow green yellow',
      'Rainbow grey blue',
      'Rainbow orange',
      'Rainbow white',
      'Sushi green yellow',
      'Sushi white',
      'White'
    ];

    name = traits[_index];
  }

  function nameForFurTrait(uint8 _index) private view returns (string memory name) {
    string[25] memory traits = [
      'Beige',
      'Black grey mouth',
      'Black grey spotted',
      'Black tuxedo',
      'Black white spotted',
      'Black white stripes',
      'Calico black white',
      'Calico ginger',
      'Calico ginger black',
      'Calico ginger white',
      'Calico grey white',
      'Ginger black stripes',
      'Ginger grey spotted',
      'Ginger tuxedo',
      'Ginger white spotted',
      'Ginger white stripes',
      'Grey',
      'Grey tuxedo',
      'White',
      'White black spotted',
      'White black stripes',
      'White ginger spotted',
      'White ginger stripes',
      'White grey spotted',
      'White grey stripes'
    ];

    name = traits[_index];
  }

  function nameForEarsTrait(uint8 _index) private view returns (string memory name) {
    string[2] memory traits = ['Grey', 'Pink'];
    name = traits[_index];
  }

  function nameForBrowsTrait(uint8 _index) private view returns (string memory name) {
    string[3] memory traits = ['Pensive', 'Raised', 'Usual'];
    name = traits[_index];
  }

  function nameForEyesTrait(uint8 _index) private view returns (string memory name) {
    string[32] memory traits = [
      'Blue',
      'Blue eyelids',
      'Blue left',
      'Blue left eyelids',
      'Blue right',
      'Blue right eyelids',
      'Green',
      'Green eyelids',
      'Green left',
      'Green left eyelids',
      'Green right eyelids',
      'Green right up',
      'Grey',
      'Grey eyelids',
      'Grey left',
      'Grey left eyelids',
      'Grey right',
      'Grey right eyelids',
      'Hazel',
      'Hazel eyelids',
      'Hazel left',
      'Hazel left eyelids',
      'Hazel right',
      'Hazel right eyelids',
      'Heterochromia',
      'Heterochromia eyelids',
      'Heterochromia left',
      'Heterochromia left big',
      'Heterochromia right eyelids',
      'Heterochromia right up',
      'Loving',
      'Spinning'
    ];
    name = traits[_index];
  }

  function nameForNoseTrait(uint8 _index) private view returns (string memory name) {
    string[18] memory traits = [
      'Beaming',
      'Black mustache',
      'Black nose',
      'Bubblegum',
      'Cheshire smile',
      'Chili pepper mustache',
      'Facemask',
      'Ginger nose',
      'Grey mustache',
      'Grinning',
      'Laughing',
      'Licking',
      'Purple party favor',
      'Rose nose',
      'Scared',
      'Surprised',
      'Tongue',
      'Yellow party favor'
    ];
    name = traits[_index];
  }

  function nameForCollarTrait(uint8 _index) private view returns (string memory name) {
    string[14] memory traits = [
      'Bell',
      'Bow black',
      'Cape black',
      'Cape blue',
      'Cape red',
      'Golden',
      'None',
      'Pink',
      'Scarf pink',
      'Scarf rainbow',
      'Scarf striped red white',
      'Wings black',
      'Wings black pink',
      'Wings white'
    ];
    name = traits[_index];
  }

  function nameForNipplesTrait(uint8 _index) private view returns (string memory name) {
    string[2] memory traits = ['Natural', 'Prude'];
    name = traits[_index];
  }

  function nameForShirtTrait(uint8 _index) private view returns (string memory name) {
    string[10] memory traits = [
      'Blue',
      'Fish',
      'Food',
      'Milk',
      'Orange',
      'Paw',
      'Pink',
      'Poop',
      'Red',
      'White'
    ];
    name = traits[_index];
  }

  function nameForTieTrait(uint8 _index) private view returns (string memory name) {
    string[10] memory traits = [
      'Black bow',
      'Blue',
      'Blue bow',
      'Grey',
      'Nothing',
      'Orange',
      'Pink',
      'Pink blue',
      'Pink bow',
      'Red bow'
    ];
    name = traits[_index];
  }

  function nameForBlazerTrait(uint8 _index) private view returns (string memory name) {
    string[6] memory traits = ['Black', 'Blue', 'Denim', 'Grey', 'None', 'White'];
    name = traits[_index];
  }

  function nameForTshirtTrait(uint8 _index) private view returns (string memory name) {
    string[12] memory traits = [
      'Beige',
      'Black',
      'Blue',
      'Grey',
      'Magenta',
      'Neon green',
      'Orange',
      'Pink',
      'Purple',
      'Red',
      'White',
      'Yellow'
    ];
    name = traits[_index];
  }

  function nameForPatternTrait(uint8 _index) private view returns (string memory name) {
    string[33] memory traits = [
      'Banana-ol',
      'Banny blockchain',
      'Banny coder',
      'Banny dao',
      'Banny lfg',
      'Banny megafon',
      'Banny party',
      'Banny popcorn',
      'Banny stoned',
      'Banny yes',
      'Cannabis',
      'Chicken',
      'Diamond',
      'Dog',
      'Donut',
      'Eth',
      'Eth Viktor Hachmang',
      'Finance William Tempest',
      'Football',
      'Grey eth',
      'Hemp leaf',
      'Juicebox logo',
      'Mario',
      'Meat',
      'None',
      'Nyan cat',
      'Pastel eth',
      'Preppy bear',
      'Quint',
      'Rainbow',
      'Rene Magritte',
      'Sealion',
      'Sushi'
    ];
    name = traits[_index];
  }

  function nameForHeadwearTrait(uint8 _index) private view returns (string memory name) {
    string[29] memory traits = [
      'Antlers',
      'Bear',
      'Black Backwards Hat',
      'Black hat',
      'Bunny',
      'Cap Ethereum',
      'Cap Juicebox',
      'Cap Supercat',
      'Denim Backwards Hat',
      'Flyagaric',
      'Grey headphones',
      'Headphones pink',
      'Horns',
      'Ninja Headband',
      'None',
      'Paperbag',
      'Paperbag not famous',
      'Party hat blue',
      'Party hat green',
      'Party hat pink dotted',
      'Party hat pink striped',
      'Party hat teal',
      'Pineapple',
      'Pink Backwards Hat',
      'Pink headphones',
      'Red Backwards Hat',
      'Sombrero',
      'Swimcap white',
      'Tiger'
    ];
    name = traits[_index];
  }

  function nameForSpecialHeadwearTrait(uint8 _index) private view returns (string memory name) {
    string[19] memory traits = [
      'Aviator helmet',
      'Batman',
      'Bowler hat',
      'Burger',
      'Caesar',
      'Candy stripe propellerhat',
      'Chromie',
      'Cowboy Hat',
      'Dino',
      'Ducky',
      'Flame',
      'Halo',
      'Panda',
      'Propellerhat colorful',
      'Raincloud',
      'Sea lion',
      'Spaceman',
      'Thunderstorm',
      'Unicorn'
    ];
    name = traits[_index];
  }

  function nameForGlassesTrait(uint8 _index) private view returns (string memory name) {
    string[35] memory traits = [
      '3D',
      'Black_3D',
      'Black amethyst',
      'Black bubblegum',
      'Black ice',
      'Black rainbow',
      'Black red',
      'Black sunset',
      'Blue',
      'Gigolo',
      'Gold',
      'Green',
      'Hip bat',
      'Loverboy',
      'Mars',
      'Monocle',
      'Murder orange',
      'Neon green',
      'Neon pink',
      'Neon yellow',
      'None',
      'Orange',
      'Orange cateye',
      'Pink cateye',
      'Pirate patch',
      'Rainbow',
      'Red',
      'Round',
      'Slime',
      'Stereo',
      'Sunglasses',
      'Teal',
      'White ice',
      'White rainbow',
      'Yellow'
    ];
    name = traits[_index];
  }
}
