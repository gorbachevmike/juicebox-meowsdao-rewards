// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@openzeppelin/contracts/utils/Base64.sol';
import '@openzeppelin/contracts/utils/Strings.sol';

// stack[0] = uint64(uint8(_traits)); // Background 165
// stack[1] = uint64(uint8(_traits >> 8) & 63); // Fur 25
// stack[2] = uint64(uint8(_traits >> 14) & 15); // Ears 2
// stack[3] = uint64(uint8(_traits >> 18) & 15); // Brows 3
// stack[4] = uint64(uint8(_traits >> 22) & 63); // Eyes 36
// stack[5] = uint64(uint8(_traits >> 28) & 15); // Nose 18

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
  uint8[12] private nakedOffsets = [0, 8, 14, 18, 22, 28, 34, 60, 66, 72, 76, 77];
  uint8[12] private nakedCardinality = [165, 25, 2, 3, 36, 18, 2, 31, 37, 14, 1, 1];
  uint8[12] private nakedMask = [255, 63, 15, 15, 63, 63, 15, 63, 63, 15, 1, 1];

  uint8[12] private tShirtOffsets = [0, 8, 14, 18, 22, 28, 50, 54, 60, 66, 76, 77];
  uint8[12] private tShirtCardinality = [165, 25, 2, 3, 36, 18, 13, 34, 31, 37, 1, 1];
  uint8[12] private tShirtMask = [255, 63, 15, 15, 63, 63, 15, 63, 63, 63, 1, 1];

  uint8[13] private shirtOffsets = [0, 8, 14, 18, 22, 28, 38, 42, 46, 60, 66, 76, 77];
  uint8[13] private shirtCardinality = [165, 25, 2, 3, 36, 18, 11, 10, 7, 31, 37, 1, 1];
  uint8[13] private shirtMask = [255, 63, 15, 15, 63, 63, 15, 15, 15, 63, 63, 1, 1];

  function validateTraits(uint256 _traits) public view returns (bool) {
    uint8 population = uint8(_traits >> 252) & 15;

    if (population == 0) {
      for (uint8 i = 0; i != 12; ) {
        if (uint8(_traits >> nakedOffsets[i]) & nakedMask[i] > nakedCardinality[i]) {
          return false;
        }
        ++i;
      }

      return true;
    } else if (population == 1) {
      for (uint8 i = 0; i != 12; ) {
        if (uint8(_traits >> tShirtOffsets[i]) & tShirtMask[i] > tShirtCardinality[i]) {
          return false;
        }
        ++i;
      }
      return true;
    } else {
      for (uint8 i = 0; i != 13; ) {
        if (uint8(_traits >> shirtOffsets[i]) & shirtMask[i] > shirtCardinality[i]) {
          return false;
        }
        ++i;
      }

      return true;
    }
  }

  function generateTraits(uint256 _seed) public view returns (uint256 traits) {
    uint8 population = uint8(_seed >> 252) & 15;

    if (population == 0) {
      traits = uint256(uint8(_seed) % nakedCardinality[0]);
      for (uint8 i = 1; i != 12; ) {
        traits |=
          uint256((uint8(_seed >> nakedOffsets[i]) % nakedCardinality[i]) + 1) <<
          nakedOffsets[i];
        ++i;
      }
    } else if (population == 1) {
      traits = uint256(uint8(_seed) % tShirtCardinality[0]);
      for (uint8 i = 1; i != 12; ) {
        traits |=
          uint256((uint8(_seed >> tShirtOffsets[i]) % tShirtCardinality[i]) + 1) <<
          tShirtOffsets[i];
        ++i;
      }
    } else {
      traits = uint256(uint8(_seed) % shirtCardinality[0]);
      for (uint8 i = 1; i != 13; ) {
        traits |=
          uint256((uint8(_seed >> shirtOffsets[i]) % shirtCardinality[i]) + 1) <<
          shirtOffsets[i];
        ++i;
      }
    }
  }

  function listTraits(uint256 _traits) public view returns (string memory names) {
    uint8 population = uint8(_traits >> 252) & 15;

    string memory group;
    string memory name;
    if (population == 0) {
      (group, name) = nameForTraits(0, (uint8(_traits >> nakedOffsets[0]) & nakedMask[0]) - 1);
      names = string(abi.encodePacked('"', group, '":"', name, '"'));

      for (uint8 i = 1; i != 12; ) {
        (group, name) = nameForTraits(
          nakedOffsets[i],
          (uint8(_traits >> nakedOffsets[i]) & nakedMask[i]) - 1 // NOTE trait ids are not 0-based
        );
        names = string(abi.encodePacked(names, ',"', group, '":"', name, '"'));
        ++i;
      }
    } else if (population == 1) {
      (group, name) = nameForTraits(0, (uint8(_traits >> tShirtOffsets[0]) & tShirtMask[0]) - 1);
      names = string(abi.encodePacked('"', group, '":"', name, '"'));
      for (uint8 i = 1; i != 12; ) {
        (group, name) = nameForTraits(
          tShirtOffsets[i],
          (uint8(_traits >> tShirtOffsets[i]) & tShirtMask[i]) - 1 // NOTE trait ids are not 0-based
        );
        names = string(abi.encodePacked(names, ',"', group, '":"', name, '"'));
        ++i;
      }
    } else {
      (group, name) = nameForTraits(0, (uint8(_traits >> shirtOffsets[0]) & shirtMask[0]) - 1);
      names = string(abi.encodePacked('"', group, '":"', name, '"'));
      for (uint8 i = 1; i != 13; ) {
        (group, name) = nameForTraits(
          shirtOffsets[i],
          (uint8(_traits >> shirtOffsets[i]) & shirtMask[i]) - 1 // NOTE trait ids are not 0-based
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
    image = __imageTag(
      _ipfsGateway,
      _ipfsRoot,
      uint256(uint8(_traits >> nakedOffsets[0]) & nakedMask[0])
    );
    for (uint8 i = 1; i < 12; ) {
      image = string(
        abi.encodePacked(
          image,
          __imageTag(
            _ipfsGateway,
            _ipfsRoot,
            uint256(uint8(_traits >> nakedOffsets[i]) & nakedMask[i]) << nakedOffsets[i]
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
  ) internal view returns (string memory image) {
    image = __imageTag(
      _ipfsGateway,
      _ipfsRoot,
      uint64(uint8(_traits >> tShirtOffsets[0]) & tShirtMask[0])
    );
    for (uint8 i = 1; i < 12; ) {
      image = string(
        abi.encodePacked(
          image,
          __imageTag(
            _ipfsGateway,
            _ipfsRoot,
            uint64(uint8(_traits >> tShirtOffsets[i]) & tShirtMask[i])
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
  ) internal view returns (string memory image) {
    image = __imageTag(
      _ipfsGateway,
      _ipfsRoot,
      uint64(uint8(_traits >> shirtOffsets[0]) & shirtMask[0])
    );
    for (uint8 i = 1; i < 13; ) {
      image = string(
        abi.encodePacked(
          image,
          __imageTag(
            _ipfsGateway,
            _ipfsRoot,
            uint64(uint8(_traits >> shirtOffsets[i]) & shirtMask[i])
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
    string memory image = Base64.encode(
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

  function nameForTraits(uint8 _offset, uint8 _index)
    private
    pure
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
      group = 'Nipples';
      trait = nameForNipplesTrait(_index);
    } else if (_offset == 38) {
      group = 'Shirt';
      trait = nameForShirtTrait(_index);
    } else if (_offset == 42) {
      group = 'Tie';
      trait = nameForTieTrait(_index);
    } else if (_offset == 46) {
      group = 'Blazer';
      trait = nameForBlazerTrait(_index);
    } else if (_offset == 50) {
      group = 'T-shirt';
      trait = nameForTshirtTrait(_index);
    } else if (_offset == 54) {
      group = 'Pattern';
      trait = nameForPatternTrait(_index);
    } else if (_offset == 60) {
      group = 'Headwear';
      trait = nameForHeadwearTrait(_index);
    } else if (_offset == 66) {
      group = 'Glasses';
      trait = nameForGlassesTrait(_index);
    } else if (_offset == 72) {
      group = 'Collar';
      trait = nameForCollarTrait(_index);
    } else if (_offset == 76) {
      group = 'Signature';
      trait = 'Natasha';
    } else if (_offset == 77) {
      group = 'Juicebox';
      trait = 'Yes';
    } else {
      group = '';
      trait = '';
    }
  }

  function nameForBackgroundTrait(uint8 _index) private pure returns (string memory name) {
    string[165] memory traits = [
      'Balloons blue violet',
      'Balloons grey',
      'Balloons grey blue',
      'Balloons orange',
      'Balloons pink',
      'Balloons white',
      'Blue green',
      'Blue violet',
      'Clouds blue green',
      'Clouds blue violet',
      'Clouds green',
      'Clouds green yellow',
      'Clouds grey',
      'Clouds orange',
      'Clouds pink',
      'Clouds pink green',
      'Clouds white',
      'Diamonds blue green',
      'Diamonds blue violet',
      'Diamonds grey',
      'Diamonds pink',
      'Diamonds white',
      'Ethereum blue green',
      'Ethereum blue violet',
      'Ethereum green yellow',
      'Ethereum grey blue',
      'Ethereum on blue',
      'Ethereum on blue green',
      'Ethereum on green',
      'Ethereum on grey',
      'Ethereum on orange',
      'Ethereum on pink',
      'Ethereum on pink green',
      'Ethereum on white',
      'Ethereum orange',
      'Ethereum pink',
      'Ethereum pink green',
      'Ethereum white',
      'Fastfood blue green',
      'Fastfood blue violet',
      'Fastfood green yellow',
      'Fastfood grey blue',
      'Fastfood orange',
      'Fastfood pink',
      'Fastfood pink green',
      'Fastfood white',
      'Fireworks blue green',
      'Fireworks blue violet',
      'Fireworks pink',
      'Fireworks pink green',
      'Fireworks white',
      'Fish blue green',
      'Fish blue violet',
      'Fish green yellow',
      'Fish grey',
      'Fish orange',
      'Fish pink',
      'Fish pink green',
      'Fish white',
      'Fishtank blue green',
      'Fishtank blue violet',
      'Fishtank green yellow',
      'Fishtank grey blue',
      'Fishtank orange',
      'Fishtank pink',
      'Fishtank pink green',
      'Fishtank white',
      'Foodbowl blue green',
      'Foodbowl blue violet',
      'Foodbowl green yellow',
      'Foodbowl grey',
      'Foodbowl grey blue',
      'Foodbowl orange',
      'Foodbowl pink',
      'Foodbowl pink green',
      'Foodbowl white',
      'Green',
      'Green yellow',
      'Grey',
      'Grey blue',
      'Grey eth on blue',
      'Grey eth on blue green',
      'Grey eth on green',
      'Grey eth on grey',
      'Grey eth on orange',
      'Grey eth on pink',
      'Grey eth on pink green',
      'Grey eth on white',
      'JuiceBox black pink',
      'JuiceBox pink',
      'Juicebox black blue',
      'Juicebox black blue green',
      'Juicebox black green yellow',
      'Juicebox black orange',
      'Juicebox black white',
      'Juicebox blue',
      'Juicebox blue green',
      'Juicebox green yellow',
      'Juicebox orange',
      'Juicebox white',
      'Milk blue green',
      'Milk blue violet',
      'Milk green yellow',
      'Milk grey',
      'Milk grey blue',
      'Milk orange',
      'Milk pink',
      'Milk pink green',
      'Milk white',
      'Milkbox blue green',
      'Milkbox blue violet',
      'Milkbox green yellow',
      'Milkbox grey blue',
      'Milkbox orange',
      'Milkbox pink',
      'Milkbox pink green',
      'Milkbox white',
      'Orange',
      'Pastel eth on blue',
      'Pastel eth on blue green',
      'Pastel eth on green yellow',
      'Pastel eth on grey',
      'Pastel eth on orange',
      'Pastel eth on pink',
      'Pastel eth on pink green',
      'Pastel eth on white',
      'Paws blue green',
      'Paws blue violet',
      'Paws dark grey',
      'Paws green yellow',
      'Paws grey',
      'Paws orange',
      'Paws pink',
      'Paws pink green',
      'Paws white',
      'Pink',
      'Pink green',
      'Pizza blue green',
      'Pizza blue violet',
      'Pizza green yellow',
      'Pizza grey',
      'Pizza grey blue',
      'Pizza orange',
      'Pizza pink',
      'Pizza pink green',
      'Pizza white',
      'Planets',
      'Rainbow blue green',
      'Rainbow blue violet',
      'Rainbow green yellow',
      'Rainbow grey',
      'Rainbow grey blue',
      'Rainbow orange',
      'Rainbow pink',
      'Rainbow pink green',
      'Rainbow white',
      'Sushi blue green',
      'Sushi blue violet',
      'Sushi green yellow',
      'Sushi grey blue',
      'Sushi orange',
      'Sushi pink',
      'Sushi pink green',
      'Sushi white',
      'White'
    ];

    name = traits[_index];
  }

  function nameForFurTrait(uint8 _index) private pure returns (string memory name) {
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

  function nameForEarsTrait(uint8 _index) private pure returns (string memory name) {
    string[2] memory traits = ['Grey', 'Pink'];
    name = traits[_index];
  }

  function nameForBrowsTrait(uint8 _index) private pure returns (string memory name) {
    string[3] memory traits = ['Pensive', 'Raised', 'Usual'];
    name = traits[_index];
  }

  function nameForEyesTrait(uint8 _index) private pure returns (string memory name) {
    string[36] memory traits = [
      'Black',
      'Black eyelids',
      'Black left',
      'Black right up',
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

  function nameForNoseTrait(uint8 _index) private pure returns (string memory name) {
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

  function nameForNipplesTrait(uint8 _index) private pure returns (string memory name) {
    string[2] memory traits = ['Natural', 'Prude'];
    name = traits[_index];
  }

  function nameForShirtTrait(uint8 _index) private pure returns (string memory name) {
    string[11] memory traits = [
      'Blue',
      'Fish',
      'Food',
      'Math',
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

  function nameForTieTrait(uint8 _index) private pure returns (string memory name) {
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

  function nameForBlazerTrait(uint8 _index) private pure returns (string memory name) {
    string[7] memory traits = ['Black', 'Blue', 'Denim', 'Ethereum', 'Grey', 'Nothing', 'Whte'];
    name = traits[_index];
  }

  function nameForTshirtTrait(uint8 _index) private pure returns (string memory name) {
    string[13] memory traits = [
      'Beige',
      'Black',
      'Blue',
      'Bright blue',
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

  function nameForPatternTrait(uint8 _index) private pure returns (string memory name) {
    string[34] memory traits = [
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
      'Developers-eth-blocks William Tempest',
      'Dog',
      'Donut',
      'Eth',
      'Eth Viktor Hachmang',
      'Finance William Tempest',
      'Football',
      'Grey eth',
      'Hemp leave',
      'Juicebox logo',
      'Meat',
      'Nyan cat',
      'One diamond',
      'One rainbow',
      'Pastel eth',
      'Patternless',
      'Preppy bear',
      'Quint',
      'Rene Magritte This is not a pipe',
      'Sealion',
      'Sushi',
      'This is not a pipe Mario'
    ];
    name = traits[_index];
  }

  function nameForHeadwearTrait(uint8 _index) private pure returns (string memory name) {
    string[31] memory traits = [
      'Antlers',
      'Batman',
      'Bear',
      'Black hat',
      'Bowler hat',
      'Bunny',
      'Burger',
      'Candy stripe propellerhat',
      'Dino',
      'Flyagaric',
      'Grey headphones',
      'Horns',
      'Nothing',
      'Panda',
      'Paperbag',
      'Paperbag not famous',
      'Party hat blue',
      'Party hat green',
      'Party hat pink dotted',
      'Party hat teal',
      'Pineapple',
      'Pink headphones',
      'Propellerhat colorful',
      'Sea lion',
      'Sombrero',
      'Spaceman',
      'Striped pink party hat',
      'Swimcap blue',
      'Swimcap white',
      'Tiger',
      'Unicorn'
    ];
    name = traits[_index];
  }

  function nameForGlassesTrait(uint8 _index) private pure returns (string memory name) {
    string[37] memory traits = [
      '3D',
      '3D',
      'Black 3D',
      'Black amethyst',
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
      'Nothing',
      'Orange cateye',
      'Orange',
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

  function nameForCollarTrait(uint8 _index) private pure returns (string memory name) {
    string[14] memory traits = [
      'Bell',
      'Bow black',
      'Cape black',
      'Cape blue',
      'Cape red',
      'Golden',
      'No collar',
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
}
