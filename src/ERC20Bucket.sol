// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC20} from "solady/tokens/ERC20.sol";

/**
 * @title ERC20Bucket
 * @author emo.eth
 * @notice A fungible ERC20 backed by tokens from a non-fungible ERC721
 */
contract ERC20Bucket is ERC20 {
    string _name;
    string _symbol;
    ///@notice The address that is authorized to mint and burn tokens
    address public immutable MINT_AUTHORITY;
    ///@notice The address of the NFT contract whose tokens back this ERC20
    address public immutable NFT_CONTRACT;

    ///@notice An error to be used when the mint or burn are called by an unauthorized address
    error NotAuthorized();

    constructor(string memory name_, string memory symbol_, address nftContract) {
        _name = name_;
        _symbol = symbol_;
        MINT_AUTHORITY = msg.sender;
        NFT_CONTRACT = nftContract;
    }

    /**
     * @inheritdoc ERC20
     */
    function name() public view override returns (string memory) {
        return _name;
    }

    /**
     * @inheritdoc ERC20
     */
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    /**
     * @notice Mint tokens to an address. Only the MINT_AUTHORITY can call this function.
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external {
        if (msg.sender != MINT_AUTHORITY) {
            revert NotAuthorized();
        }
        _mint(to, amount);
    }

    /**
     * @notice Burn tokens from an address. Only the MINT_AUTHORITY can call this function.
     * @param from The address to burn tokens from
     * @param amount The amount of tokens to burn
     */
    function burn(address from, uint256 amount) external {
        if (msg.sender != MINT_AUTHORITY) {
            revert NotAuthorized();
        }
        _burn(from, amount);
    }
}
