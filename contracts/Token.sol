// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBDirectory.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBPaymentTerminal.sol';
import '@jbx-protocol/contracts-v2/contracts/libraries/JBTokens.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/utils/cryptography/MerkleProof.sol';
import '@rari-capital/solmate/src/tokens/ERC721.sol';
import '@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol';
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';

import 'hardhat/console.sol';

interface IWETH9 is IERC20 {
  function deposit() external payable;

  function withdraw(uint256) external;
}

contract Token is ERC721, Ownable, ReentrancyGuard {
  using Strings for uint256;

  /**
    @notice NFT provenance hash reassignment prohibited.
   */
  error PROVENANCE_REASSIGNMENT();

  /**
    @notice Base URI assignment along with the "revealed" flag can only be done once.
   */
  error ALREADY_REVEALED();

  /**
    @notice User mint allowance exhausted.
   */
  error ALLOWANCE_EXHAUSTED();

  /**
    @notice mint() function received an incorrect payment, expected payment returned as argument.
   */
  error INCORRECT_PAYMENT(uint256);

  /**
    @notice Token supply exhausted, all tokens have been minted.
   */
  error SUPPLY_EXHAUSTED();

  /**
    @notice Various payment failures caused by incorrect contract condiguration.
   */
  error PAYMENT_FAILURE();

  /**
    @notice User attempted to pay for the mint using an unapproved token.
   */
  error UNAPPROVED_TOKEN();

  /**
    @notice User attempted to pay for a mint, on a contract that retains paid token deposits rather than liquidating for Ether immediately, without providing sufficient margin on top of the NFT cost.
   */
  error INVALID_MARGIN();

  /**
    @notice Blank Merkle root.
   */
  error INVALID_ROOT();

  /**
    @notice Merkle proof does not match parameters.
   */
  error INVALID_PROOF();

  /**
    @notice Merkle claims for the user exhausted, not the same as `ALLOWANCE_EXHAUSTED()`.
   */
  error CLAIMS_EXHAUSTED();

  address public constant WETH9 = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address public constant DAI = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
  // IQuoter public constant uniswapQuoter = IQuoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);
  IQuoter public uniswapQuoter; // for testing
  // ISwapRouter public constant uniswapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
  ISwapRouter public uniswapRouter; // for testing

  IJBDirectory jbxDirectory;
  uint256 jbxProjectId;

  string public baseUri;
  string public contractUri;
  uint256 public maxSupply;
  uint256 public unitPrice;
  uint256 public immutable mintAllowance;
  string public provenanceHash;
  mapping(address => bool) public acceptableTokens;
  bool immediateTokenLiquidation;
  uint256 tokenPriceMargin = 10_000; // in bps

  mapping(address => uint256) public claimedMerkleAllowance;
  uint256 public totalSupply;

  /**
    @notice Revealed flag.

    @dev changes the way tokenUri(uint256) works.
   */
  bool isRevealed;

  /**
    @notice Pause minting flag
   */
  bool isPaused;

  /**
    @notice Merkle root data.
   */
  bytes32 public merkleRoot;

  //*********************************************************************//
  // -------------------------- constructor ---------------------------- //
  //*********************************************************************//

  /**
    @notice Creates the NFT contract.

    @param _name Token name.
    @param  _symbol Token symbol
    @param  _baseUri Base URI, initially expected to point at generic, "unrevealed" metadata json.
    @param  _contractUri OpenSea-style contract metadata URI.
    @param  _jbxProjectId Juicebox project id that will be paid the proceeds of the sale.
    @param  _jbxDirectory Juicebox directory to determine payment destination.
    @param  _maxSupply Max NFT supply.
    @param  _unitPrice Price per token expressed in Ether.
    @param  _mintAllowance Per-user mint cap.
   */
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
    IQuoter _uniswapQuoter, // TODO: remove
    ISwapRouter _uniswapRouter // TODO: remove
  ) ERC721(_name, _symbol) {
    baseUri = _baseUri;
    contractUri = _contractUri;
    jbxDirectory = _jbxDirectory;
    jbxProjectId = _jbxProjectId;
    maxSupply = _maxSupply;
    unitPrice = _unitPrice;
    mintAllowance = _mintAllowance;
    uniswapQuoter = _uniswapQuoter;
    uniswapRouter = _uniswapRouter;
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
    uri = !isRevealed ? baseUri : string(abi.encodePacked(baseUri, _tokenId.toString()));
  }

  //*********************************************************************//
  // ---------------------- external transactions ---------------------- //
  //*********************************************************************//

  /**
    @notice Mints a token to the calling account. Must be paid in Ether if price is non-zero.

    @dev Proceeds are forwarded to the default jbx terminal for the project id set in the constructor. Payment will fail if the terminal is not set in the jbx directory.
   */
  function mint() public payable nonReentrant returns (uint256 tokenId) {
    if (totalSupply == maxSupply) {
      revert SUPPLY_EXHAUSTED();
    }

    uint256 accountBalance = balanceOf(msg.sender);
    if (accountBalance == mintAllowance) {
      revert ALLOWANCE_EXHAUSTED();
    }

    // TODO: consider beaking this out
    uint256 expectedPrice;
    if (accountBalance != 0 &&  accountBalance != 2 && accountBalance != 4) {
      expectedPrice = accountBalance * unitPrice;
    }
    if (msg.value != expectedPrice) {
      revert INCORRECT_PAYMENT(expectedPrice);
    }

    if (msg.value > 0) {
      // NOTE: move funds to jbx project
      IJBPaymentTerminal terminal = jbxDirectory.primaryTerminalOf(jbxProjectId, JBTokens.ETH);
      if (address(terminal) == address(0)) {
        revert PAYMENT_FAILURE();
      }

      terminal.pay(
        jbxProjectId,
        msg.value,
        JBTokens.ETH,
        msg.sender,
        0,
        false,
        string(abi.encodePacked('at ', block.number.toString(), ' ', msg.sender, ' purchased a kitty cat for ', msg.value.toString())),
        abi.encodePacked('MEOWsDAO Progeny Noun Token Minted at ', block.timestamp.toString(), '.')
      );
    }

    tokenId = generateTokenId(msg.sender, msg.value, block.number);
    _mint(msg.sender, tokenId);
    unchecked {
        ++totalSupply;
    }
  }

  /**
    @dev Pays into the appropriate jbx terminal for the token. The terminal may also issue tokens to the calling account.
     */
  function mint(IERC20 _token) public payable nonReentrant returns (uint256 tokenId) {
    if (totalSupply == maxSupply) {
      revert SUPPLY_EXHAUSTED();
    }

    uint256 accountBalance = balanceOf(msg.sender);
    if (accountBalance > mintAllowance) {
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

        terminal.pay(
            jbxProjectId,
            ethProceeds,
            JBTokens.ETH,
            msg.sender,
            0,
            false,
            // string(abi.encodePacked('at ', block.number.toString(), ' ', msg.sender, ' purchased a kitty cat for ', requiredTokenAmount.toString(), ' of ', _token)),
            '',
            abi.encodePacked('MEOWsDAO Progeny Noun Token Minted at ', block.timestamp.toString(), '.')
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

        terminal.pay(
            jbxProjectId,
            requiredTokenAmount,
            address(_token),
            msg.sender,
            0,
            false,
            // string(abi.encodePacked('at ', block.number.toString(), ' ', msg.sender, ' purchased a kitty cat for ', requiredTokenAmount.toString(), ' of ', _token)),
            '',
            abi.encodePacked('MEOWsDAO Progeny Noun Token Minted at ', block.timestamp.toString())
        );
      }
    }

    tokenId = generateTokenId(msg.sender, msg.value, block.number);
    _mint(msg.sender, tokenId);
    unchecked {
        ++totalSupply;
      }
  }

  /**
    @notice Allows minting by anyone in the merkle root.
    */
  function merkleMint(
    uint256 _index,
    uint256 _allowance,
    bytes32[] calldata _proof
  ) external payable nonReentrant returns (uint256 tokenId) {
    if (merkleRoot == 0) {
      revert INVALID_ROOT();
    }

    bytes32 node = keccak256(abi.encodePacked(_index, msg.sender, _allowance));

    if (!MerkleProof.verify(_proof, merkleRoot, node)) {
      revert INVALID_PROOF();
    }

    if (_allowance - claimedMerkleAllowance[msg.sender] == 0) {
        revert CLAIMS_EXHAUSTED();
    } else {
        ++claimedMerkleAllowance[msg.sender];
    }

    tokenId = generateTokenId(msg.sender, msg.value, block.number);
    _mint(msg.sender, tokenId);
    unchecked {
        ++totalSupply;
      }
  }

  //*********************************************************************//
  // -------------------- priviledged transactions --------------------- //
  //*********************************************************************//

  function setPause(bool pause) external onlyOwner {
    isPaused = pause;
  }

  function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
    merkleRoot = _merkleRoot;
  }

  function mintFor(address _account) public onlyOwner {
    uint256 tokenId = generateTokenId(_account, unitPrice, block.number);
    _mint(_account, tokenId);
    unchecked {
        ++totalSupply;
      }
  }

  /**
    @notice Set provenance hash.

    @dev This operation can only be executed once.
   */
  function setProvenanceHash(string memory _provenanceHash) public onlyOwner {
    if (bytes(provenanceHash).length == 0) {
      revert PROVENANCE_REASSIGNMENT();
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

  function updatePaymentTokenParams(bool _immediateTokenLiquidation, uint256 _tokenPriceMargin) public onlyOwner {
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

  function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  // TODO: consider breaking this out
  function generateTokenId(
    address _account,
    uint256 _amount,
    uint256 _blockNumber
  ) private returns (uint256 tokenId) {
    if (totalSupply == maxSupply) {
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
