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

    ///@notice modifier to restrict non-static calls to clones to prevent direct
    ///        state-modifying calls to the implementation contract.
    modifier onlyClones() {
        // since IMPLEMENTATION is immutable, this check restricts calls to
        // DELEGATECALLS; DELEGATECALL'ing clones will have a different address
        // than is stored in the bytecode.
        // in this case, since there are no native DELEGATECALLs, there's no
        // actual danger in calling the implementation directly, but
        // it's best practice to restrict it anyway.
        if (address(this) == IMPLEMENTATION) {
            revert OnlyClones();
        }
        _;
    }

    constructor() {
        // store the implementation address in the implementation bytecode
        IMPLEMENTATION = address(this);
    }

    /**
     * @inheritdoc ERC20
     */
    function name() public pure override returns (string memory) {
        // note that behavior is undefined on the implementation contract
        // read the length of the name from the extra calldata appended by the clone proxy
        uint256 length = _getArgUint16(0x28);
        // read the packed bytes of name from the extra calldata appended by the clone proxy
        return string(_getArgBytes(0x2c, length));
    }

    /**
     * @inheritdoc ERC20
     */
    function symbol() public pure override returns (string memory) {
        // note that behavior is undefined on the implementation contract
        // read the length of the name to calculate the offset of the symbol
        uint256 nameLength = _getArgUint16(0x28);
        // read the length of the symbol from the extra calldata appended by the clone proxy
        uint256 length = _getArgUint16(0x2a);
        // read the packed bytes of symbol from the extra calldata appended by the clone proxy
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

    /**
     * @notice Get the address of the MINT_AUTHORITY for this contract
     *         Note that behavior is undefined on the implementation contract
     */
    function MINT_AUTHORITY() external pure returns (address) {
        return _MINT_AUTHORITY();
    }

    /**
     * @notice Get the address of the backing NFT_CONTRACT for this contract
     *         Note that behavior is undefined on the implementation contract
     */
    function NFT_CONTRACT() external pure returns (address) {
        return _NFT_CONTRACT();
    }

    /**
     * @dev Read the MINT_AUTHORITY address from the extra calldata appended
     *      by the clone proxy
     */
    function _MINT_AUTHORITY() internal pure returns (address) {
        return _getArgAddress(0);
    }

    /**
     * @dev Read the NFT_CONTRACT address from the extra calldata appended
     *      by the clone proxy
     */
    function _NFT_CONTRACT() internal pure returns (address) {
        return _getArgAddress(0x14);
    }
}
