// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC721} from "solady/tokens/ERC721.sol";
import {ERC20Bucket} from "./ERC20Bucket.sol";

/**
 * @title BucketFactory
 * @author emo.eth
 * @notice A factory contract for minting ERC20 "bucket" tokens backed by non-fungible tokens belonging to any ERC721 contract.
 *         On first deposit, the BucketFactory deploys a corresponding fungible ERC20 "bucket" token for the specific ERC721 contract,
 *         which the factory can then use to mint and burn fungible tokens as ERC721 tokens are deposited and redeemed.
 *         Each ERC721 token deposited into the factory contract will mint 10,000 fungible tokens (18 decimals) from the corresponding ERC20
 *         "bucket" to the sender or specified recipient.
 *         Conversely, any account can call the redeem functions to burn 10,000 fungible tokens from an ERC20 "bucket" and receive any corresponding
 *         ERC721 token that the factory holds.
 */
contract BucketFactory {
    ///@notice The number of fungible tokens minted per NFT (18 decimal places)
    uint256 public constant FUNGIBLE_TOKENS_PER_NFT = 10_000 ether;

    ///@notice A mapping from NFT contract addresses to its corresponding ERC20 bucket contract addresses
    mapping(address nftContract => address erc20BucketContract) public nftToErc20Bucket;

    ///@notice An error to be used when a bucket does not exist
    error BucketDoesNotExist();

    /**
     * @notice Deposit an NFT into the contract from the sender and mint the corresponding fungible tokens to the sender
     * @param nftContract The address of the NFT contract
     * @param tokenId The ID of the NFT to deposit
     */
    function deposit(address nftContract, uint256 tokenId) external {
        deposit(nftContract, tokenId, msg.sender);
    }

    /**
     * @notice Deposit an NFT into the contract from the sender and mint the corresponding fungible tokens to the recipient
     * @param nftContract The address of the NFT contract
     * @param tokenId The ID of the NFT to deposit
     * @param recipient The address to mint the fungible tokens to
     */
    function deposit(address nftContract, uint256 tokenId, address recipient) public {
        // take ownership of the nft
        ERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
        // mint fungible tokens to the sender
        _bucketMint(nftContract, recipient, FUNGIBLE_TOKENS_PER_NFT);
    }

    /**
     * @notice Deposit multiple NFTs into the contract from the sender and mint the corresponding fungible tokens to the sender
     * @param nftContract The address of the NFT contract
     * @param tokenIds The IDs of the NFTs to deposit
     */
    function deposit(address nftContract, uint256[] calldata tokenIds) external {
        deposit(nftContract, tokenIds, msg.sender);
    }

    /**
     * @notice Deposit multiple NFTs into the contract from the sender and mint the corresponding fungible tokens to the recipient
     * @param nftContract The address of the NFT contract
     * @param tokenIds The IDs of the NFTs to deposit
     * @param recipient The address to mint the fungible tokens to
     */
    function deposit(address nftContract, uint256[] calldata tokenIds, address recipient) public {
        // take ownership of the nfts
        for (uint256 i = 0; i < tokenIds.length; ++i) {
            ERC721(nftContract).transferFrom(msg.sender, address(this), tokenIds[i]);
        }
        // mint fungible tokens to the sender
        _bucketMint(nftContract, recipient, FUNGIBLE_TOKENS_PER_NFT * tokenIds.length);
    }

    /**
     * @notice Burn fungible tokens from the sender and transfer a corresponding NFT to the sender
     * @param nftContract The address of the NFT contract
     * @param tokenId The ID of the NFT to redeem
     */
    function redeem(address nftContract, uint256 tokenId) external {
        redeem(nftContract, tokenId, msg.sender);
    }

    /**
     * @notice Burn fungible tokens from the sender and transfer a corresponding NFT to the recipient
     * @param nftContract The address of the NFT contract
     * @param tokenId The ID of the NFT to redeem
     * @param recipient The address to transfer the NFT to
     */
    function redeem(address nftContract, uint256 tokenId, address recipient) public {
        // burn fungible tokens from msg.sender
        _bucketBurn(nftContract, FUNGIBLE_TOKENS_PER_NFT);
        // transfer the nft to the recipient
        ERC721(nftContract).transferFrom(address(this), recipient, tokenId);
    }

    /**
     * @notice Burn fungible tokens from the sender and transfer multiple corresponding NFTs to the sender
     * @param nftContract The address of the NFT contract
     * @param tokenIds The IDs of the NFTs to redeem
     */
    function redeem(address nftContract, uint256[] calldata tokenIds) external {
        redeem(nftContract, tokenIds, msg.sender);
    }

    /**
     * @notice Burn fungible tokens from the sender and transfer multiple corresponding NFTs to the recipient
     * @param nftContract The address of the NFT contract
     * @param tokenIds The IDs of the NFTs to redeem
     * @param recipient The address to transfer the NFTs to
     */
    function redeem(address nftContract, uint256[] calldata tokenIds, address recipient) public {
        // burn fungible tokens from msg.sender
        _bucketBurn(nftContract, FUNGIBLE_TOKENS_PER_NFT * tokenIds.length);
        // transfer the nfts to the recipient
        for (uint256 i = 0; i < tokenIds.length; ++i) {
            ERC721(nftContract).transferFrom(address(this), recipient, tokenIds[i]);
        }
    }

    /**
     * @notice Mint any outstanding fungible tokens to the sender
     * @param nftContract The address of the NFT contract
     */
    function skim(address nftContract) public {
        skim(nftContract, msg.sender);
    }

    /**
     * @notice Mint any outstanding fungible tokens to the recipient
     * @param nftContract The address of the NFT contract
     * @param recipient The address to mint any outstanding fungible tokens to
     */
    function skim(address nftContract, address recipient) public {
        uint256 nftBalance = ERC721(nftContract).balanceOf(address(this));
        if (nftBalance > 0) {
            ERC20Bucket erc20Bucket = _getBucket(nftContract);
            uint256 actual = erc20Bucket.totalSupply();
            uint256 expected = nftBalance * FUNGIBLE_TOKENS_PER_NFT;
            if (expected > actual) {
                erc20Bucket.mint(recipient, expected - actual);
            }
        }
    }

    /**
     * @notice Mint any outstanding fungible tokens to the sender for multiple NFT contracts
     * @param nftContracts The addresses of the NFT contracts
     */
    function skim(address[] calldata nftContracts) external {
        skim(nftContracts, msg.sender);
    }

    /**
     * @notice Mint any outstanding fungible tokens to the recipient for multiple NFT contracts
     * @param nftContracts The addresses of the NFT contracts
     * @param recipient The address to mint any outstanding fungible tokens to
     */
    function skim(address[] calldata nftContracts, address recipient) public {
        for (uint256 i = 0; i < nftContracts.length; ++i) {
            skim(nftContracts[i], recipient);
        }
    }

    /**
     * @dev Get or create the ERC20 bucket for the given NFT contract
     * @param nftContract The address of the NFT contract to get the bucket for
     */
    function _getBucket(address nftContract) internal returns (ERC20Bucket) {
        ERC20Bucket erc20Bucket = ERC20Bucket(nftToErc20Bucket[nftContract]);
        // create a new bucket if one doesn't exist
        if (address(erc20Bucket) == address(0)) {
            erc20Bucket = new ERC20Bucket{salt: bytes32(bytes20(nftContract))}(
                string.concat(ERC721(nftContract).name(), " (Bucket)"),
                string.concat(ERC721(nftContract).symbol(), "(B)"),
                nftContract
            );
            // store the address of the new bucket
            nftToErc20Bucket[nftContract] = address(erc20Bucket);
        }
        return erc20Bucket;
    }

    /**
     * @dev Check that the ERC20 bucket for the given NFT contract exists and return it
     * @param nftContract The address of the NFT contract to check the bucket for
     */
    function _checkBucket(address nftContract) internal view returns (ERC20Bucket) {
        ERC20Bucket erc20Bucket = ERC20Bucket(nftToErc20Bucket[nftContract]);
        // revert if the bucket doesn't exist
        if (address(erc20Bucket) == address(0)) {
            revert BucketDoesNotExist();
        }
        return erc20Bucket;
    }

    /**
     * @dev Mint fungible tokens to the recipient for the given NFT contract
     * @param nftContract The address of the NFT contract
     * @param recipient The address to mint the fungible tokens to
     * @param amount The amount of fungible tokens to mint
     */
    function _bucketMint(address nftContract, address recipient, uint256 amount) internal {
        // get or create the bucket ERC20 for the nft
        ERC20Bucket erc20Bucket = _getBucket(nftContract);
        // mint fungible tokens to the recipient
        erc20Bucket.mint(recipient, amount);
    }

    /**
     * @dev Burn the corresponding fungible tokens from the sender for the given NFT contract
     * @param nftContract The address of the NFT contract
     * @param amount The amount of fungible tokens to burn
     */
    function _bucketBurn(address nftContract, uint256 amount) internal {
        // check that the bucket exists
        ERC20Bucket erc20Bucket = _checkBucket(nftContract);
        // burn fungible tokens from the sender
        // ERC20 performs the necessary checks to ensure the sender has enough tokens
        erc20Bucket.burn(msg.sender, amount);
    }

    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be
     * reverted.
     *
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(address, address from, uint256, bytes calldata) external returns (bytes4) {
        ERC20Bucket erc20Bucket = _getBucket(msg.sender);
        erc20Bucket.mint(from, FUNGIBLE_TOKENS_PER_NFT);
        return this.onERC721Received.selector;
    }
}
