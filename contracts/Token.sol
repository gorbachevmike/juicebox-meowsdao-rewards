// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBDirectory.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBPaymentTerminal.sol';
import '@jbx-protocol/contracts-v2/contracts/libraries/JBTokens.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol';

import './interfaces/INftUriResolver.sol';
import './interfaces/IPriceResolver.sol';
import './libraries/ERC721Enumerable.sol';

contract Token is ERC721Enumerable, Ownable, ReentrancyGuard {
  using Strings for uint256;

  error PROVENACE_REASSIGNMENT();
  error ALREADY_REVEALED();
  error ALLOWANCE_EXHAUSTED();
  error INCORRECT_PAYMENT(uint256);
  error SUPPLY_EXHAUSTED();
  error PAYMENT_FAILURE();

  IQuoter public constant uniswapQuoter = IQuoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);

  IJBDirectory jbxDirectory;
  uint256 jbxProjectId;

  string public baseUri;
  string public contractUri;
  uint256 public maxSupply;
  uint256 public unitPrice;
  uint256 public mintAllowance;
  string public provenanceHash;

  bool isRevealed;

  //*********************************************************************//
  // -------------------------- constructor ---------------------------- //
  //*********************************************************************//
  constructor(
    string memory _name,
    string memory _symbol,
    string memory _baseUri,
    string memory _contractUri,
    uint256 _jbxProjectId,
    IJBDirectory _jbxDirectory,
    uint256 _maxSupply,
    uint256 _unitPrice,
    uint256 _mintAllowance,
    string memory _provenanceHash
  ) ERC721Enumerable(_name, _symbol) {
    baseUri = _baseUri;
    contractUri = _contractUri;
    jbxDirectory = _jbxDirectory;
    jbxProjectId = _jbxProjectId;
    maxSupply = _maxSupply;
    unitPrice = _unitPrice;
    mintAllowance = _mintAllowance;
    provenanceHash = _provenanceHash;
  }

  //*********************************************************************//
  // ------------------------- external views -------------------------- //
  //*********************************************************************//

  /**
    @notice Get contract metadata to make OpenSea happy.
    */
  function contractURI() public view returns (string memory) {
    return contractUri;
  }

  /**
    @dev If the token has been set as "revealed", returned uri will append the token id
    */
  function tokenURI(uint256 _tokenId) public view override returns (string memory uri) {
    uri = isRevealed ? baseUri : string(abi.encodePacked(baseUri, _tokenId.toString()));
  }

  //*********************************************************************//
  // ---------------------- external transactions ---------------------- //
  //*********************************************************************//

  function mint() public payable nonReentrant {
    if (totalSupply() == maxSupply) {
      revert SUPPLY_EXHAUSTED();
    }

    uint256 accountBalance = balanceOf(msg.sender);
    if (accountBalance < mintAllowance) {
      revert ALLOWANCE_EXHAUSTED();
    }

    // TODO: consider beaking this out
    uint256 expectedPrice;
    if (accountBalance != 0 && accountBalance != 2 && accountBalance != 4) {
      expectedPrice = accountBalance * unitPrice;
    }
    if (msg.value != expectedPrice) {
      revert INCORRECT_PAYMENT(expectedPrice);
    }

    if (msg.value > 0) {
      // NOTE: move funds to jbx project w/o issuing tokens
      IJBPaymentTerminal terminal = jbxDirectory.primaryTerminalOf(jbxProjectId, JBTokens.ETH);
      if (address(terminal) == address(0)) {
        revert PAYMENT_FAILURE();
      }
      terminal.addToBalanceOf(jbxProjectId, msg.value, JBTokens.ETH, 'MEOWs DAO Token Mint', '');
    }

    uint256 tokenId = generateTokenId(msg.sender, msg.value, block.number);
    _beforeTokenTransfer(address(0), msg.sender, tokenId);
    _mint(msg.sender, tokenId);
  }

  function mintFor(address _account) public onlyOwner {
    uint256 tokenId = generateTokenId(_account, unitPrice, block.number);
    _beforeTokenTransfer(address(0), _account, tokenId);
    _mint(_account, tokenId);
  }

  //*********************************************************************//
  // -------------------- priviledged transactions --------------------- //
  //*********************************************************************//

  /**
    @notice Set provenance hash.

    @dev This operation can only be executed once.
   */
  function setProvenanceHash(string memory _provenanceHash) public onlyOwner {
    if (bytes(provenanceHash).length == 0) {
        revert PROVENACE_REASSIGNMENT();
    }
    provenanceHash = _provenanceHash;
  }

  /**
    @notice Metadata URI for token details in OpenSea format.
   */
  function setContractURI(string memory _contractUri) public onlyOwner {
    contractUri = _contractUri;
  }

  /**
    @notice Set NFT metadata base URI.

    @dev URI must include the trailing slash.
    */
  function setBaseURI(string memory _baseUri, bool _reveal) public onlyOwner {
    if (isRevealed && !_reveal) {
        revert ALREADY_REVEALED();
    }

    baseUri = _baseUri;
    isRevealed = _reveal;
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721Enumerable)
    returns (bool)
  {
    return ERC721Enumerable.supportsInterface(interfaceId);
  }

  // TODO: consider beaking this out
  function generateTokenId(
    address _account,
    uint256 _amount,
    uint256 _blockNumber
  ) private returns (uint256 tokenId) {
    if (totalSupply() == maxSupply) {
      revert SUPPLY_EXHAUSTED();
    }

    // TODO: probably cheaper to go to the specific pair and divide balances
    uint256 ethPrice = uniswapQuoter.quoteExactInputSingle(
      address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2), // weth
      address(0x6B175474E89094C44Da98b954EedeAC495271d0F), // dai
      3000, // fee
      _amount,
      0 // sqrtPriceLimitX96
    );

    tokenId = uint256(keccak256(abi.encodePacked(_account, _blockNumber, ethPrice))) % maxSupply;
    while (_ownerOf[tokenId] != address(0)) {
      tokenId = ++tokenId % maxSupply;
    }
  }
}
