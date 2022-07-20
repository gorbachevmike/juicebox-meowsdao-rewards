// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import '@jbx-protocol/contracts-v2/contracts/JBETHERC20ProjectPayer.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/Strings.sol';

import './interfaces/INftUriResolver.sol';
import './interfaces/IPriceResolver.sol';
import './libraries/ERC721Enumerable.sol';

contract Token is ERC721Enumerable, JBETHERC20ProjectPayer, ReentrancyGuard {
  using Strings for uint256;

  error ALLOWANCE_EXHAUSTED();
  error INCORRECT_PAYMENT(uint256);
  error SUPPLY_EXHAUSTED();

  IPriceResolver private priceResolver;
  INftUriResolver private tokenUriResolver;
  string private baseUri;

  bool public saleIsActive = false;
  string public PROVENANCE = '';

  /**
    @notice URI containing Opensea-style metadata.
  */
  string public OPENSEA_STORE_METADATA = '';

  uint256 public constant PER_KITTY_PRICE = 50000000000000000;
  uint256 public constant MAX_KITTY_ALLOWANCE = 25;

  uint256 public MAX_TOTAL_KITTIES;
  uint256 public REVEAL_TIMESTAMP;
  uint256 public startingIndexBlock;
  uint256 public startingIndex;

  //*********************************************************************//
  // -------------------------- constructor ---------------------------- //
  //*********************************************************************//
  constructor(
    string memory name,
    string memory symbol,
    uint256 maxNftSupply,
    uint256 saleStart,
    IPriceResolver _priceResolver,
    INftUriResolver _tokenUriResolver
  )
    ERC721Enumerable(name, symbol)
    JBETHERC20ProjectPayer(
      1,
      payable(msg.sender),
      false,
      '',
      '',
      false,
      IJBDirectory(address(0)),
      msg.sender
    )
  {
    // uint256 _defaultProjectId,
    // address payable _defaultBeneficiary,
    // bool _defaultPreferClaimedTokens,
    // string memory _defaultMemo,
    // bytes memory _defaultMetadata,
    // bool _defaultPreferAddToBalance,
    // IJBDirectory _directory,
    // address _owner

    MAX_TOTAL_KITTIES = maxNftSupply;
    REVEAL_TIMESTAMP = saleStart + (86400 * 5);

    priceResolver = _priceResolver;
    tokenUriResolver = _tokenUriResolver;
  }

  //*********************************************************************//
  // ------------------------- external views -------------------------- //
  //*********************************************************************//

  /**
    @notice Get contract metadata to make OpenSea happy.
    */
  function contractURI() public view returns (string memory) {
    return OPENSEA_STORE_METADATA;
  }

  function tokenURI(uint256 _tokenId) public view override returns (string memory) {
    if (address(tokenUriResolver) != address(0)) {
      return tokenUriResolver.tokenURI(_tokenId);
    } else {
      return string(abi.encodePacked(baseUri, _tokenId.toString())); // TODO: this could be the reveal mechanic
    }
  }

  //*********************************************************************//
  // ---------------------- external transactions ---------------------- //
  //*********************************************************************//

  function mint() public payable {
    uint256 accountBalance = balanceOf(msg.sender);
    if (accountBalance < 10) {
      // TODO: const
      revert ALLOWANCE_EXHAUSTED();
    }

    uint256 expectedPrice;
    if (accountBalance != 0 && accountBalance != 2 && accountBalance != 4) {
      expectedPrice = accountBalance * 0.0125 ether; // TODO: const
    }
    if (msg.value != expectedPrice) {
      revert INCORRECT_PAYMENT(expectedPrice);
    }

    if (msg.value > 0) {
        // NOTE: move funds to jbx project w/o issuing tokens
        _addToBalanceOf(defaultProjectId, JBTokens.ETH, msg.value, 18, defaultMemo, defaultMetadata);
    }

    uint256 tokenId = totalSupply() + 1; // TODO: consider randomizing id, but the assets already have randomized content

    if (tokenId > 6969) { // TODO: const
        revert SUPPLY_EXHAUSTED();
    }

    _beforeTokenTransfer(address(0), msg.sender, tokenId);
    _mint(msg.sender, tokenId);
  }

  function mintFor(address _account) public payable onlyOwner {
    if (msg.value > 0) {
        // NOTE: move funds to jbx project w/o issuing tokens
        _addToBalanceOf(defaultProjectId, JBTokens.ETH, msg.value, 18, defaultMemo, defaultMetadata);
    }

    uint256 tokenId = totalSupply() + 1; // TODO: consider randomizing id, but the assets already have randomized content
    _beforeTokenTransfer(address(0), _account, tokenId);
    _mint(_account, tokenId);
  }

  /**
    @notice Mint.
    */
  function mint(uint256 numberOfTokens) public payable {
    require(saleIsActive, 'Sale must be active to mint Mr. Whiskers');
    require(numberOfTokens <= MAX_KITTY_ALLOWANCE, 'Can only mint 25 tokens at a time');
    require(
      totalSupply() + numberOfTokens <= MAX_TOTAL_KITTIES,
      'Purchase would exceed max supply of Mr. Whiskers'
    );

    // TODO: price resolver

    // require(
    //     PER_KITTY_PRICE.mul(numberOfTokens) <= msg.value,
    //     'Ether value sent is not correct'
    // );

    // TODO: JBETHERC20ProjectPayer

    for (uint256 i = 0; i < numberOfTokens; i++) {
      uint256 mintIndex = totalSupply();
      if (totalSupply() < MAX_TOTAL_KITTIES) {
        _safeMint(msg.sender, mintIndex);
      }
    }

    /*
        If we haven't set the starting index and this is either 
            1) the last saleable token or 
            2) the first token to be sold after
        the end of pre-sale, set the starting index block
    */
    if (
      startingIndexBlock == 0 &&
      (totalSupply() == MAX_TOTAL_KITTIES || block.timestamp >= REVEAL_TIMESTAMP)
    ) {
      startingIndexBlock = block.number;
    }
  }

  //*********************************************************************//
  // -------------------- priviledged transactions --------------------- //
  //*********************************************************************//

  /**
    @notice Pay the electricity bill
    */
  function withdraw() public onlyOwner {
    payable(msg.sender).transfer(address(this).balance);
  }

  /**
    @notice Set aside a portion of the total supply for the team
    */
  function reserveKittyCats() public onlyOwner {
    uint256 supply = totalSupply();
    uint256 i;
    for (i = 0; i < 25; i++) {
      _safeMint(msg.sender, supply + i);
    }
  }

  function setRevealTimestamp(uint256 revealTimeStamp) public onlyOwner {
    REVEAL_TIMESTAMP = revealTimeStamp;
  }

  /**
   *  @dev Set provenance once it's calculated
   */
  function setProvenanceHash(string memory provenanceHash) public onlyOwner {
    require(bytes(PROVENANCE).length == 0, 'Provenance has already been set, no do-overs!');
    PROVENANCE = provenanceHash;
  }

  /**
   *  @dev Set metadata to make OpenSea happy
   */
  function setContractURI(string memory _contractMetadataURI) public onlyOwner {
    OPENSEA_STORE_METADATA = _contractMetadataURI;
  }

  /**
    @notice Set NFT metadata base URI.

    @dev URI must include the trailing slash.
    */
  function setBaseURI(string memory _baseUri) public onlyOwner {
    baseUri = _baseUri;
  }

  /**
    @notice Set token URI resolver.

    @dev Token URI resolver will be used instead of the base URI if it is set.
    */
  function setTokenUriResolver(INftUriResolver _resolver) public onlyOwner {
    tokenUriResolver = _resolver;
  }

  /**
   *  @dev Pause sale if active, make active if paused
   */
  function flipSaleState() public onlyOwner {
    saleIsActive = !saleIsActive;
  }

  /**
   * @dev Set the starting index for the collection
   */
  function setStartingIndex() public onlyOwner {
    require(startingIndex == 0, 'Starting index is already set');
    require(startingIndexBlock != 0, 'Starting index block must be set');
    startingIndex = uint256(blockhash(startingIndexBlock)) % MAX_TOTAL_KITTIES;
    // Just a sanity case in the worst case if this function is called late (EVM only stores last 256 block hashes)
    if (block.number - startingIndexBlock > 255) {
      startingIndex = uint256(blockhash(block.number - 1)) % MAX_TOTAL_KITTIES;
    }
    // Prevent default sequence
    if (startingIndex == 0) {
      ++startingIndex;
    }
  }

  /**
   * @dev Set the starting index block for the collection, essentially unblocking
   * setting starting index
   */
  function emergencySetStartingIndexBlock() public onlyOwner {
    require(startingIndex == 0, 'Starting index is already set');
    startingIndexBlock = block.number;
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721Enumerable, JBETHERC20ProjectPayer)
    returns (bool)
  {
    return
      JBETHERC20ProjectPayer.supportsInterface(interfaceId) ||
      ERC721Enumerable.supportsInterface(interfaceId);
  }
}
