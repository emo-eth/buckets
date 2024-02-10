// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {ERC20Bucket} from "src/./ERC20Bucket.sol";

contract ERC20BucketTest is Test {
    ERC20Bucket bucket;

    function setUp() public {
        bucket = new ERC20Bucket("Test", "TST", address(1234));
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
        ERC20Bucket _bucket = new ERC20Bucket("Test", "TST", address(1234));
        assertEq(_bucket.MINT_AUTHORITY(), sender);
    }

    function test_mint_mintAuthority(address sender, address recipient) public {
        vm.startPrank(sender);
        ERC20Bucket _bucket = new ERC20Bucket("Test", "TST", address(1234));
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
        ERC20Bucket _bucket = new ERC20Bucket("Test", "TST", address(1234));
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
}
