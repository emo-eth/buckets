// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC721} from "solady/tokens/ERC721.sol";

contract TestERC721 is ERC721 {
    function name() public pure override returns (string memory) {
        return "TestERC721";
    }

    function symbol() public pure override returns (string memory) {
        return "TST";
    }

    function tokenURI(uint256) public pure override returns (string memory) {
        return "https://example.com";
    }

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    function burn(uint256 tokenId) external {
        _burn(tokenId);
    }
}
