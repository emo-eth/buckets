// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC20} from "solady/tokens/ERC20.sol";
import {Clone} from "solady/utils/Clone.sol";

/**
 * @title ERC20Bucket
 * @author emo.eth
 * @notice A fungible ERC20 backed by tokens from a non-fungible ERC721
 */
contract ERC20Bucket is ERC20, Clone {
    ///@notice The address of the implementation contract.
    address public immutable IMPLEMENTATION;

    ///@notice An error to be used when the mint or burn are called by an unauthorized address
    error NotAuthorized();

    ///@notice An error to be used when an account tries to interact with the implementation contract directly.
    error OnlyClones();

    modifier onlyClones() {
        // since SELF is immutable, this check restricts calls to DELEGATECALLS
        // DELEGATECALL'ing clones will have a different address than is stored
        // in the bytecode.
        // in this case, since there are no native DELEGATECALLs, there's no
        // actual danger in calling the implementation directly, but
        // it's best practice to restrict it anyway.
        if (address(this) == IMPLEMENTATION) {
            revert OnlyClones();
        }
        _;
    }

    constructor() {
        IMPLEMENTATION = address(this);
    }

    function MINT_AUTHORITY() external view onlyClones returns (address) {
        return _MINT_AUTHORITY();
    }

    function NFT_CONTRACT() external view onlyClones returns (address) {
        return _NFT_CONTRACT();
    }

    function _MINT_AUTHORITY() internal pure returns (address) {
        return _getArgAddress(0);
    }

    function _NFT_CONTRACT() internal pure returns (address) {
        return _getArgAddress(0x14);
    }

    /**
     * @inheritdoc ERC20
     */
    function name() public view override onlyClones returns (string memory) {
        uint256 length = _getArgUint16(0x28);
        return string(_getArgBytes(0x2c, length));
    }

    /**
     * @inheritdoc ERC20
     */
    function symbol() public view override onlyClones returns (string memory) {
        uint256 nameLength = _getArgUint16(0x28);
        uint256 length = _getArgUint16(0x2a);
        return string(_getArgBytes(0x2c + nameLength, length));
    }

    /**
     * @notice Mint tokens to an address. Only the MINT_AUTHORITY can call this function.
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyClones {
        if (msg.sender != _MINT_AUTHORITY()) {
            revert NotAuthorized();
        }
        _mint(to, amount);
    }

    /**
     * @notice Burn tokens from an address. Only the MINT_AUTHORITY can call this function.
     * @param from The address to burn tokens from
     * @param amount The amount of tokens to burn
     */
    function burn(address from, uint256 amount) external onlyClones {
        if (msg.sender != _MINT_AUTHORITY()) {
            revert NotAuthorized();
        }
        _burn(from, amount);
    }
}
