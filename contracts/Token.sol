// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBDirectory.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBPaymentTerminal.sol';
import '@jbx-protocol/contracts-v2/contracts/libraries/JBTokens.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol';
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';

import './libraries/ERC721Enumerable.sol';

interface IWETH9 is IERC20 {
  function deposit() external payable;

  function withdraw(uint256) external;
}

contract Token is ERC721Enumerable, Ownable, ReentrancyGuard {
  using Strings for uint256;

  error PROVENACE_REASSIGNMENT();
  error ALREADY_REVEALED();
  error ALLOWANCE_EXHAUSTED();
  error INCORRECT_PAYMENT(uint256);
  error SUPPLY_EXHAUSTED();
  error PAYMENT_FAILURE();
  error UNAPPROVED_TOKEN();
  error INVALID_MARGIN();

  address public constant WETH9 = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address public constant DAI = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
  IQuoter public constant uniswapQuoter = IQuoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);
  ISwapRouter public constant uniswapRouter =
    ISwapRouter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);

  IJBDirectory jbxDirectory;
  uint256 jbxProjectId;

  string public baseUri;
  string public contractUri;
  uint256 public maxSupply;
  uint256 public unitPrice;
  uint256 public mintAllowance;
  string public provenanceHash;
  mapping(address => bool) public acceptableTokens;
  bool immediateTokenLiquidation;
  uint256 tokenPriceMargin; // in bps

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
    uint256 _mintAllowance
  ) ERC721Enumerable(_name, _symbol) {
    baseUri = _baseUri;
    contractUri = _contractUri;
    jbxDirectory = _jbxDirectory;
    jbxProjectId = _jbxProjectId;
    maxSupply = _maxSupply;
    unitPrice = _unitPrice;
    mintAllowance = _mintAllowance;
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
    if (accountBalance == mintAllowance) {
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

  /**
    @dev Moves funds to jbx project terminal w/o issuing tokens via addToBalanceOf
     */
  function mint(IERC20 _token) public payable nonReentrant {
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

    if (expectedPrice != 0) {
      if (!acceptableTokens[address(_token)]) {
        revert UNAPPROVED_TOKEN();
      }

      if (immediateTokenLiquidation) {
        IJBPaymentTerminal terminal = jbxDirectory.primaryTerminalOf(jbxProjectId, JBTokens.ETH);
        if (address(terminal) == address(0)) {
          revert PAYMENT_FAILURE();
        }

        uint256 requiredTokenAmount = uniswapQuoter.quoteExactOutputSingle(
          address(_token),
          WETH9,
          3000, // fee
          expectedPrice,
          0 // sqrtPriceLimitX96
        );

        if (!_token.transferFrom(msg.sender, address(this), requiredTokenAmount)) {
          revert PAYMENT_FAILURE();
        }

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams(
          address(_token),
          WETH9,
          3000, // fee
          address(this),
          block.timestamp + 15, // deadline
          requiredTokenAmount,
          expectedPrice,
          0 // sqrtPriceLimitX96
        );

        if (!_token.approve(address(uniswapRouter), requiredTokenAmount)) {
          revert PAYMENT_FAILURE();
        }

        uint256 ethProceeds = uniswapRouter.exactInputSingle(params);
        if (ethProceeds < expectedPrice) {
          revert PAYMENT_FAILURE();
        }

        IWETH9(WETH9).withdraw(ethProceeds);

        terminal.addToBalanceOf(
          jbxProjectId,
          ethProceeds,
          JBTokens.ETH,
          'MEOWs DAO Token Mint',
          ''
        );
      } else {
        IJBPaymentTerminal terminal = jbxDirectory.primaryTerminalOf(jbxProjectId, address(_token));
        if (address(terminal) == address(0)) {
          revert PAYMENT_FAILURE();
        }

        uint256 requiredTokenAmount = uniswapQuoter.quoteExactOutputSingle(
          address(_token),
          WETH9,
          3000, // fee
          (expectedPrice * tokenPriceMargin) / 10_000,
          0 // sqrtPriceLimitX96
        );

        if (!_token.transferFrom(msg.sender, address(this), requiredTokenAmount)) {
          revert PAYMENT_FAILURE();
        }

        if (!_token.approve(address(terminal), requiredTokenAmount)) {
          revert PAYMENT_FAILURE();
        }

        terminal.addToBalanceOf(
          jbxProjectId,
          requiredTokenAmount,
          address(_token),
          'MEOWs DAO Token Mint',
          ''
        );
      }
    }

    uint256 tokenId = generateTokenId(msg.sender, msg.value, block.number);
    _beforeTokenTransfer(address(0), msg.sender, tokenId);
    _mint(msg.sender, tokenId);
  }

  //*********************************************************************//
  // -------------------- priviledged transactions --------------------- //
  //*********************************************************************//

  function mintFor(address _account) public onlyOwner {
    uint256 tokenId = generateTokenId(_account, unitPrice, block.number);
    _beforeTokenTransfer(address(0), _account, tokenId);
    _mint(_account, tokenId);
  }

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

  function updatePaymentTokenList(address _token, bool _accept) public onlyOwner {
    acceptableTokens[_token] = _accept;
  }

  function updatePaymentTokenParams(bool _immediateTokenLiquidation, uint256 _tokenPriceMargin)
    public
    onlyOwner
  {
    if (tokenPriceMargin > 10_000) {
      revert INVALID_MARGIN();
    }
    tokenPriceMargin = _tokenPriceMargin;
    immediateTokenLiquidation = _immediateTokenLiquidation;
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
      WETH9,
      DAI,
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
