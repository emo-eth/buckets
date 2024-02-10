// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {ERC20Bucket} from "src/./ERC20Bucket.sol";
import {LibClone} from "solady/utils/LibClone.sol";

contract ERC20BucketTest is Test {
    ERC20Bucket impl;
    ERC20Bucket bucket;

    function setUp() public {
        impl = new ERC20Bucket();
        bucket = newERC20Bucket("Test", "TST", address(1234), address(this));
    }

    function test_constructor() public {
        assertEq(bucket.name(), "Test");
        assertEq(bucket.symbol(), "TST");
        assertEq(bucket.decimals(), 18);
        assertEq(bucket.NFT_CONTRACT(), address(1234));
        assertEq(bucket.MINT_AUTHORITY(), address(this));
    }

    function test_msgSender_mintAuthority(address sender) public {
        vm.prank(sender);
        ERC20Bucket _bucket = newERC20Bucket("Test", "TST", address(1234), sender);
        assertEq(_bucket.MINT_AUTHORITY(), sender);
    }

    function test_mint_mintAuthority(address sender, address recipient) public {
        vm.startPrank(sender);
        ERC20Bucket _bucket = newERC20Bucket("Test", "TST", address(1234), sender);
        _bucket.mint(recipient, 100);
        vm.stopPrank();
        assertEq(_bucket.balanceOf(recipient), 100);
        unchecked {
            vm.startPrank(address(uint160(sender) + 1));
        }
        vm.expectRevert(ERC20Bucket.NotAuthorized.selector);
        _bucket.mint(recipient, 100);
    }

    function test_burn_mintAuthority(address sender, address recipient) public {
        vm.startPrank(sender);
        ERC20Bucket _bucket = newERC20Bucket("Test", "TST", address(1234), sender);
        _bucket.mint(recipient, 100);
        _bucket.burn(recipient, 100);
        assertEq(_bucket.balanceOf(recipient), 0);
        vm.stopPrank();
        unchecked {
            vm.startPrank(address(uint160(sender) + 1));
        }
        vm.expectRevert(ERC20Bucket.NotAuthorized.selector);
        _bucket.burn(recipient, 100);
    }

    function testEmptyNameSymbol() public {
        ERC20Bucket _bucket = newERC20Bucket("", "", address(1234), address(this));
        assertEq(_bucket.name(), "");
        assertEq(_bucket.symbol(), "");
    }

    function newERC20Bucket(string memory name, string memory symbol, address nftContract, address authority)
        public
        returns (ERC20Bucket)
    {
        address clone = LibClone.clone(
            address(impl),
            abi.encodePacked(
                authority,
                nftContract,
                uint16(bytes(name).length),
                uint16(bytes(symbol).length),
                bytes(name),
                bytes(symbol)
            )
        );
        return ERC20Bucket(clone);
    }

    function testOnlyClones() public {
        vm.expectRevert(ERC20Bucket.OnlyClones.selector);
        impl.mint(address(this), 100);
        vm.expectRevert(ERC20Bucket.OnlyClones.selector);
        impl.burn(address(this), 100);
    }
}
