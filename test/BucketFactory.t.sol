// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {BucketFactory} from "src/./BucketFactory.sol";
import {TestERC721} from "test/helpers/TestERC721.sol";
import {ERC20Bucket} from "src/./ERC20Bucket.sol";
import {Solarray} from "solarray/Solarray.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {ERC20} from "solady/tokens/ERC20.sol";

contract BucketsTest is Test {
    TestERC721 token1;
    TestERC721 token2;
    BucketFactory factory;
    address alice;
    address bob;

    function setUp() public {
        token1 = new TestERC721();
        token2 = new TestERC721();
        factory = new BucketFactory();
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        token1.mint(address(this), 1);
        token1.mint(address(alice), 2);
        token1.mint(address(bob), 3);
        token2.mint(address(this), 11);
        token2.mint(address(alice), 12);
        token2.mint(address(bob), 13);

        _approveFactory(address(this));
        _approveFactory(address(alice));
        _approveFactory(address(bob));
    }

    function _approveFactory(address approver) internal {
        vm.startPrank(approver);
        token1.setApprovalForAll(address(factory), true);
        token2.setApprovalForAll(address(factory), true);
        vm.stopPrank();
    }

    function testDeposit() public {
        factory.deposit(address(token1), 1);
        assertNotEq(factory.nftToErc20Bucket(address(token1)), address(0));
        ERC20Bucket bucket = ERC20Bucket(factory.nftToErc20Bucket(address(token1)));
        assertEq(bucket.balanceOf(address(this)), 10_000 ether);

        // subsequent deposits should not create a new bucket
        vm.prank(alice);
        factory.deposit(address(token1), 2);
        assertEq(factory.nftToErc20Bucket(address(token1)), address(bucket));
        assertEq(bucket.balanceOf(address(alice)), 10_000 ether);
        assertEq(bucket.totalSupply(), 20_000 ether);
    }

    function testDeposit_recipient() public {
        factory.deposit(address(token1), 1, address(alice));
        ERC20Bucket bucket = ERC20Bucket(factory.nftToErc20Bucket(address(token1)));
        assertEq(bucket.balanceOf(address(alice)), 10_000 ether);
    }

    function testDepositMany() public {
        token1.mint(address(this), 4);
        factory.deposit(address(token1), Solarray.uint256s(1, 4));
        assertNotEq(factory.nftToErc20Bucket(address(token1)), address(0));
        ERC20Bucket bucket = ERC20Bucket(factory.nftToErc20Bucket(address(token1)));
        assertEq(bucket.balanceOf(address(this)), 20_000 ether);
    }

    function testDeposit_approvedButUnowned() public {
        // try to deposit someone else's token when they have approved the factory
        vm.expectRevert(ERC721.TransferFromIncorrectOwner.selector);
        factory.deposit(address(token1), 2);
    }

    function testDeposit_unapproved() public {
        // try to deposit a token when the sender has not approved the factory
        token1.setApprovalForAll(address(factory), false);
        vm.expectRevert(ERC721.NotOwnerNorApproved.selector);
        factory.deposit(address(token1), 1);
    }

    function testRedeem() public {
        factory.deposit(address(token1), 1);
        vm.prank(alice);
        factory.deposit(address(token1), 2);
        ERC20Bucket bucket = ERC20Bucket(factory.nftToErc20Bucket(address(token1)));
        factory.redeem(address(token1), 2);
        assertEq(bucket.balanceOf(address(this)), 0);
        assertEq(bucket.balanceOf(address(alice)), 10_000 ether);
        assertEq(token1.ownerOf(2), address(this));

        // redeem to a different recipient
        vm.prank(alice);
        factory.redeem(address(token1), 1, address(bob));
        assertEq(bucket.balanceOf(address(alice)), 0);
        assertEq(token1.ownerOf(1), address(bob));
    }

    function testRedeem_many() public {
        vm.prank(alice);
        token1.transferFrom(address(alice), address(this), 2);
        factory.deposit(address(token1), Solarray.uint256s(1, 2));
        ERC20Bucket bucket = ERC20Bucket(factory.nftToErc20Bucket(address(token1)));
        factory.redeem(address(token1), Solarray.uint256s(1, 2));
        assertEq(bucket.balanceOf(address(this)), 0);
        assertEq(token1.ownerOf(1), address(this));
        assertEq(token1.ownerOf(2), address(this));

        // re-deposit and redeem to a different recipient
        factory.deposit(address(token1), Solarray.uint256s(1, 2));
        factory.redeem(address(token1), Solarray.uint256s(1, 2), address(bob));
        assertEq(token1.ownerOf(1), address(bob));
        assertEq(token1.ownerOf(2), address(bob));
        assertEq(bucket.balanceOf(address(this)), 0);
    }

    function testRedeem_insufficientBalance() public {
        factory.deposit(address(token1), 1);
        vm.startPrank(alice);
        vm.expectRevert(ERC20.InsufficientBalance.selector);
        factory.redeem(address(token1), 1);
        vm.stopPrank();
        ERC20Bucket bucket = ERC20Bucket(factory.nftToErc20Bucket(address(token1)));
        bucket.transfer(address(alice), 9_999 ether);
        vm.startPrank(alice);
        vm.expectRevert(ERC20.InsufficientBalance.selector);
        factory.redeem(address(token1), 1);
    }

    function testRedeem_bucketDoesNotExist() public {
        vm.expectRevert(BucketFactory.BucketDoesNotExist.selector);
        factory.redeem(address(token1), 1);
    }

    function testSkim() public {
        token1.transferFrom(address(this), address(factory), 1);
        ERC20Bucket bucket = ERC20Bucket(factory.nftToErc20Bucket(address(token1)));
        assertEq(address(bucket), address(0));
        factory.skim(address(token1));
        bucket = ERC20Bucket(factory.nftToErc20Bucket(address(token1)));
        assertNotEq(address(bucket), address(0));
        assertEq(bucket.balanceOf(address(this)), 10_000 ether);

        // test skimming works when the bucket already exists
        vm.prank(alice);
        token1.transferFrom(address(alice), address(factory), 2);
        factory.skim(address(token1));
        assertEq(bucket.balanceOf(address(this)), 20_000 ether);
    }

    function testSkimMany() public {
        token1.transferFrom(address(this), address(factory), 1);
        token2.transferFrom(address(this), address(factory), 11);
        ERC20Bucket bucket = ERC20Bucket(factory.nftToErc20Bucket(address(token1)));
        ERC20Bucket bucket2 = ERC20Bucket(factory.nftToErc20Bucket(address(token2)));
        assertEq(address(bucket), address(0));
        assertEq(address(bucket2), address(0));
        factory.skim(Solarray.addresses(address(token1), address(token2)));

        bucket = ERC20Bucket(factory.nftToErc20Bucket(address(token1)));
        bucket2 = ERC20Bucket(factory.nftToErc20Bucket(address(token2)));
        assertNotEq(address(bucket), address(0));
        assertNotEq(address(bucket2), address(0));
        assertEq(bucket.balanceOf(address(this)), 10_000 ether);
        assertEq(bucket2.balanceOf(address(this)), 10_000 ether);
    }

    function testSkim_doNothing() public {
        factory.skim(address(token1));
        ERC20Bucket bucket = ERC20Bucket(factory.nftToErc20Bucket(address(token1)));
        assertEq(address(bucket), address(0));

        factory.deposit(address(token1), 1);
        factory.skim(address(token1));
        bucket = ERC20Bucket(factory.nftToErc20Bucket(address(token1)));
        assertEq(bucket.balanceOf(address(this)), 10_000 ether);
    }

    function testSkim_recipient() public {
        token1.transferFrom(address(this), address(factory), 1);
        ERC20Bucket bucket = ERC20Bucket(factory.nftToErc20Bucket(address(token1)));
        assertEq(address(bucket), address(0));
        factory.skim(address(token1), address(alice));
        bucket = ERC20Bucket(factory.nftToErc20Bucket(address(token1)));
        assertNotEq(address(bucket), address(0));
        assertEq(bucket.balanceOf(address(alice)), 10_000 ether);
    }

    function testSkimMany_recipient() public {
        token1.transferFrom(address(this), address(factory), 1);
        token2.transferFrom(address(this), address(factory), 11);
        ERC20Bucket bucket = ERC20Bucket(factory.nftToErc20Bucket(address(token1)));
        ERC20Bucket bucket2 = ERC20Bucket(factory.nftToErc20Bucket(address(token2)));
        assertEq(address(bucket), address(0));
        assertEq(address(bucket2), address(0));
        factory.skim(Solarray.addresses(address(token1), address(token2)), address(alice));

        bucket = ERC20Bucket(factory.nftToErc20Bucket(address(token1)));
        bucket2 = ERC20Bucket(factory.nftToErc20Bucket(address(token2)));
        assertNotEq(address(bucket), address(0));
        assertNotEq(address(bucket2), address(0));
        assertEq(bucket.balanceOf(address(alice)), 10_000 ether);
        assertEq(bucket2.balanceOf(address(alice)), 10_000 ether);
    }

    function testOnErc721Received() public {
        vm.prank(alice);
        token1.setApprovalForAll(address(this), true);
        token1.safeTransferFrom(address(alice), address(factory), 2, "");
        ERC20Bucket bucket = ERC20Bucket(factory.nftToErc20Bucket(address(token1)));
        assertNotEq(address(bucket), address(0));
        assertEq(bucket.balanceOf(address(alice)), 10_000 ether);
    }

    function testBucketConfiguration() public {
        factory.deposit(address(token1), 1);
        ERC20Bucket bucket = ERC20Bucket(factory.nftToErc20Bucket(address(token1)));
        assertEq(bucket.name(), "TestERC721 (Bucket)");
        assertEq(bucket.symbol(), "TST(B)");
        assertEq(bucket.MINT_AUTHORITY(), address(factory));
        assertEq(bucket.NFT_CONTRACT(), address(token1));
    }
}
