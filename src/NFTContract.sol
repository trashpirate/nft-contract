// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {ERC721A, IERC721A} from "@erc721a/contracts/ERC721A.sol";
import {ERC721ABurnable} from "@erc721a/contracts/extensions/ERC721ABurnable.sol";

/// @title NFTContract NFTs
/// @author Nadina Oates
/// @notice Contract implementing ERC721A standard using the ERC20 token and ETH for minting
/// @dev Inherits from ERC721A and ERC721ABurnable and openzeppelin Ownable
contract NFTContract is ERC721A, ERC2981, ERC721ABurnable, Ownable {
    /**
     * TYPES
     */
    struct ConstructorArguments {
        string name;
        string symbol;
        address owner;
        uint256 tokenFee;
        uint256 ethFee;
        address feeAddress;
        address tokenAddress;
        string baseURI;
        string contractURI;
        uint256 maxSupply;
        uint96 royaltyNumerator;
    }

    /**
     * Storage Variables
     */
    uint256 private i_maxSupply;
    IERC20 private immutable i_paymentToken;

    address private s_feeAddress;
    uint256 private s_tokenFee;
    uint256 private s_ethFee;
    uint256 private s_batchLimit = 50;

    string private s_baseURI;
    string private s_contractURI;

    bool private s_paused;

    /**
     * Events
     */
    event Paused(address indexed sender, bool isPaused);
    event TokenFeeSet(address indexed sender, uint256 fee);
    event EthFeeSet(address indexed sender, uint256 fee);
    event FeeAddressSet(address indexed sender, address feeAddress);
    event BatchLimitSet(address indexed sender, uint256 batchLimit);
    event BaseURIUpdated(string indexed baseUri);
    event ContractURIUpdated(string indexed contractUri);
    event RoyaltyUpdated(
        address indexed feeAddress,
        uint96 indexed royaltyNumerator
    );

    /**
     * Errors
     */
    error NFTContract_InsufficientTokenBalance();
    error NFTContract_InsufficientMintQuantity();
    error NFTContract_ExceedsMaxSupply();
    error NFTContract_ExceedsMaxPerWallet();
    error NFTContract_ExceedsBatchLimit();
    error NFTContract_FeeAddressIsZeroAddress();
    error NFTContract_TokenTransferFailed();
    error NFTContract_InsufficientEthFee(uint256 value, uint256 fee);
    error NFTContract_EthTransferFailed();
    error NFTContract_BatchLimitTooHigh();
    error NFTContract_NonexistentToken(uint256);
    error NFTContract_TokenUriError();
    error NFTContract_NoBaseURI();
    error NFTContract_ContractIsPaused();

    /// @notice Constructor
    /// @param args constructor arguments:
    ///                     name: collection name
    ///                     symbol: nft symbol
    ///                     owner: contract owner
    ///                     tokenFee: minting fee in tokens
    ///                     ethFee: minting fee in native coin
    ///                     feeAddress: address for fees
    ///                     tokenAddress: ERC20 token address
    ///                     baseURI: base uri
    ///                     contractURI: contract uri
    ///                     maxSupply: maximum nfts mintable
    ///                     royaltyNumerator: basis points for royalty fees
    constructor(
        ConstructorArguments memory args
    ) ERC721A(args.name, args.symbol) Ownable(msg.sender) {
        if (args.feeAddress == address(0)) {
            revert NFTContract_FeeAddressIsZeroAddress();
        }
        if (bytes(args.baseURI).length == 0) revert NFTContract_NoBaseURI();

        s_tokenFee = args.tokenFee;
        s_ethFee = args.ethFee;
        s_feeAddress = args.feeAddress;
        i_paymentToken = IERC20(args.tokenAddress);
        i_maxSupply = args.maxSupply;
        s_paused = true;

        _setBaseURI(args.baseURI);
        _setContractURI(args.contractURI);
        _setDefaultRoyalty(args.feeAddress, args.royaltyNumerator);
        _transferOwnership(args.owner);
    }

    receive() external payable {}

    /// @notice Mints NFT for a eth and a token fee
    /// @param quantity number of NFTs to mint
    function mint(uint256 quantity) external payable {
        if (s_paused) revert NFTContract_ContractIsPaused();

        if (quantity == 0) revert NFTContract_InsufficientMintQuantity();
        if (quantity > s_batchLimit) revert NFTContract_ExceedsBatchLimit();
        if (totalSupply() + quantity > i_maxSupply) {
            revert NFTContract_ExceedsMaxSupply();
        }

        if (i_paymentToken.balanceOf(msg.sender) < s_tokenFee * quantity) {
            revert NFTContract_InsufficientTokenBalance();
        }
        if (msg.value < s_ethFee * quantity) {
            revert NFTContract_InsufficientEthFee(msg.value, s_ethFee);
        }

        if (s_tokenFee > 0) {
            bool success = i_paymentToken.transferFrom(
                msg.sender,
                s_feeAddress,
                s_tokenFee * quantity
            );
            if (!success) revert NFTContract_TokenTransferFailed();
        }

        if (s_ethFee > 0) {
            (bool success, ) = payable(s_feeAddress).call{value: msg.value}("");
            if (!success) revert NFTContract_EthTransferFailed();
        }

        _mint(msg.sender, quantity);
    }

    /// @notice Sets minting fee in terms of ERC20 tokens (only owner)
    /// @param fee New fee in ERC20 tokens
    function setTokenFee(uint256 fee) external onlyOwner {
        s_tokenFee = fee;
        emit TokenFeeSet(msg.sender, fee);
    }

    /// @notice Sets minting fee in ETH (only owner)
    /// @param fee New fee in ETH
    function setEthFee(uint256 fee) external onlyOwner {
        s_ethFee = fee;
        emit EthFeeSet(msg.sender, fee);
    }

    /// @notice Sets the receiver address for the token/ETH fee (only owner)
    /// @param feeAddress New receiver address for tokens and ETH received through minting
    function setFeeAddress(address feeAddress) external onlyOwner {
        if (feeAddress == address(0)) {
            revert NFTContract_FeeAddressIsZeroAddress();
        }
        s_feeAddress = feeAddress;
        emit FeeAddressSet(msg.sender, feeAddress);
    }

    /// @notice Sets batch limit - maximum number of nfts that can be minted at once (only owner)
    /// @param batchLimit Maximum number of nfts that can be minted at once
    function setBatchLimit(uint256 batchLimit) external onlyOwner {
        if (batchLimit > 100) revert NFTContract_BatchLimitTooHigh();
        s_batchLimit = batchLimit;
        emit BatchLimitSet(msg.sender, batchLimit);
    }

    /// @notice Withdraw tokens from contract (only owner)
    /// @param tokenAddress Contract address of token to be withdrawn
    /// @param receiverAddress Tokens are withdrawn to this address
    /// @return success of withdrawal
    function withdrawTokens(
        address tokenAddress,
        address receiverAddress
    ) external onlyOwner returns (bool success) {
        IERC20 tokenContract = IERC20(tokenAddress);
        uint256 amount = tokenContract.balanceOf(address(this));
        success = tokenContract.transfer(receiverAddress, amount);
        if (!success) revert NFTContract_TokenTransferFailed();
    }

    /// @notice Withdraw ETH from contract (only owner)
    /// @param receiverAddress ETH withdrawn to this address
    /// @return success of withdrawal
    function withdrawETH(
        address receiverAddress
    ) external onlyOwner returns (bool success) {
        uint256 amount = address(this).balance;
        (success, ) = payable(receiverAddress).call{value: amount}("");
        if (!success) revert NFTContract_EthTransferFailed();
    }

    /// @notice Sets base Uri
    /// @param baseURI base uri
    function setBaseURI(string memory baseURI) external onlyOwner {
        _setBaseURI(baseURI);
    }

    /// @notice Sets royalty
    /// @param feeAddress address receiving royalties
    /// @param royaltyNumerator numerator to calculate fees (denominator is 10000)
    function setRoyalty(
        address feeAddress,
        uint96 royaltyNumerator
    ) external onlyOwner {
        _setDefaultRoyalty(feeAddress, royaltyNumerator);
        emit RoyaltyUpdated(feeAddress, royaltyNumerator);
    }

    /// @notice Pauses minting
    /// @param _isPaused boolean to set minting to be paused (true) or unpaused (false)
    function pause(bool _isPaused) external onlyOwner {
        s_paused = _isPaused;
        emit Paused(msg.sender, _isPaused);
    }

    /**
     * Getter Functions
     */

    /// @notice Gets payment token address
    function getPaymentToken() external view returns (address) {
        return address(i_paymentToken);
    }

    /// @notice Gets maximum supply
    function getMaxSupply() external view returns (uint256) {
        return i_maxSupply;
    }

    /// @notice Gets minting token fee in ERC20
    function getTokenFee() external view returns (uint256) {
        return s_tokenFee;
    }

    /// @notice Gets minting fee in ETH
    function getEthFee() external view returns (uint256) {
        return s_ethFee;
    }

    /// @notice Gets address that receives minting fees
    function getFeeAddress() external view returns (address) {
        return s_feeAddress;
    }

    /// @notice Gets number of nfts allowed minted at once
    function getBatchLimit() external view returns (uint256) {
        return s_batchLimit;
    }

    /// @notice Gets base uri
    function getBaseURI() external view returns (string memory) {
        return _baseURI();
    }

    /// @notice Gets whether contract is paused
    function isPaused() external view returns (bool) {
        return s_paused;
    }

    /**
     * Public Functions
     */

    /// @notice retrieves contractURI
    function contractURI() public view returns (string memory) {
        return s_contractURI;
    }

    /// @notice checks for supported interface
    /// @dev function override required by ERC721
    /// @param interfaceId interfaceId to be checked
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721A, IERC721A, ERC2981) returns (bool) {
        return
            ERC721A.supportsInterface(interfaceId) ||
            ERC2981.supportsInterface(interfaceId);
    }

    /**
     * Internal/Private Functions
     */
    /// @notice sets first tokenId to 1
    function _startTokenId()
        internal
        view
        virtual
        override(ERC721A)
        returns (uint256)
    {
        return 1;
    }

    /// @notice Retrieves base uri
    function _baseURI() internal view override returns (string memory) {
        return s_baseURI;
    }

    /// @notice Sets base uri
    /// @param baseURI base uri for NFT metadata
    function _setBaseURI(string memory baseURI) private {
        s_baseURI = baseURI;
        emit BaseURIUpdated(baseURI);
    }

    /// @notice Sets contract uri
    /// @param _contractURI contract uri for contract metadata
    function _setContractURI(string memory _contractURI) private {
        s_contractURI = _contractURI;
        emit ContractURIUpdated(_contractURI);
    }
}
