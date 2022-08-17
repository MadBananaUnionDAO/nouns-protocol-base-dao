// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {NounsBuilderTest} from "./utils/NounsBuilderTest.sol";

contract AuctionTest is NounsBuilderTest {
    address internal bidder1;
    address internal bidder2;

    function setUp() public virtual override {
        super.setUp();

        bidder1 = vm.addr(0xB1);
        bidder2 = vm.addr(0xB2);

        vm.deal(bidder1, 100 ether);
        vm.deal(bidder2, 100 ether);

        deploy();
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function test_AuctionHouseInitialized() public {
        assertEq(auction.owner(), founder);

        (address _timelock, uint40 _duration, uint40 _timeBuffer, uint16 _minBidIncrementPercentage, uint256 _reservePrice) = auction.settings();

        assertEq(_timelock, address(timelock));
        assertEq(_duration, auctionParams.duration);
        assertEq(_reservePrice, auctionParams.reservePrice);
        assertEq(_timeBuffer, 5 minutes);
        assertEq(_minBidIncrementPercentage, 10);
    }

    function testRevert_AlreadyInitialized() public {
        vm.expectRevert(abi.encodeWithSignature("ALREADY_INITIALIZED()"));
        auction.initialize(address(token), address(this), address(timelock), 1 minutes, 0 ether);
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function test_UnpauseAndCreateFirstAuction() public {
        vm.prank(founder);
        auction.unpause();

        // assertEq(auction.owner(), address(timelock));

        // assertEq(token.ownerOf(0), founder);
        // assertEq(token.ownerOf(1), address(auction));

        // (uint256 tokenId, uint256 highestBid, address highestBidder, uint256 startTime, uint256 endTime, bool settled) = auction.auction();

        // assertEq(tokenId, 1);
        // assertEq(highestBid, 0);
        // assertEq(highestBidder, address(0));
        // assertEq(startTime, 1);
        // assertEq(endTime, 1 + auctionParams.duration);
        // assertEq(settled, false);
    }

    function testRevert_OnlyOwnerCanUnpause() public {
        vm.expectRevert(abi.encodeWithSignature("ONLY_OWNER()"));
        auction.unpause();
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function test_CreateBid() public {
        vm.prank(founder);
        auction.unpause();

        vm.prank(bidder1);
        auction.createBid{value: 0.420 ether}(1);

        (, uint256 highestBid, address highestBidder, , , ) = auction.auction();

        assertEq(highestBid, 0.420 ether);
        assertEq(highestBidder, bidder1);

        assertEq(bidder1.balance, 99.58 ether);
        assertEq(address(auction).balance, 0.420 ether);
    }

    function testRevert_InvalidBidTokenId() public {
        vm.prank(founder);
        auction.unpause();

        vm.prank(bidder1);
        vm.expectRevert(abi.encodeWithSignature("INVALID_TOKEN_ID()"));
        auction.createBid{value: 0.420 ether}(2);
    }

    function testRevert_MustMeetReservePrice() public {
        vm.prank(founder);
        auction.unpause();

        vm.prank(bidder1);
        vm.expectRevert(abi.encodeWithSignature("RESERVE_PRICE_NOT_MET()"));
        auction.createBid{value: 0.0001 ether}(1);
    }

    function test_CreateSubsequentBid() public {
        vm.prank(founder);
        auction.unpause();

        uint256 bidder1BeforeBalance = bidder1.balance;

        vm.prank(bidder1);
        auction.createBid{value: 0.420 ether}(1);

        vm.warp(5 minutes);

        vm.prank(bidder2);
        auction.createBid{value: 1 ether}(1);

        uint256 bidder1AfterBalance = bidder1.balance;

        assertEq(bidder1BeforeBalance, bidder1AfterBalance);

        assertEq(bidder2.balance, 99 ether);
        assertEq(address(auction).balance, 1 ether);

        (, uint256 highestBid, address highestBidder, , , ) = auction.auction();

        assertEq(highestBid, 1 ether);
        assertEq(highestBidder, bidder2);
    }

    function testRevert_MustMeetMinBidIncrement() public {
        vm.prank(founder);
        auction.unpause();

        vm.prank(bidder1);
        auction.createBid{value: 0.420 ether}(1);

        vm.warp(5 minutes);

        vm.prank(bidder2);
        vm.expectRevert(abi.encodeWithSignature("MINIMUM_BID_NOT_MET()"));
        auction.createBid{value: 0.461 ether}(1);
    }

    function test_ExtendAuction() public {
        vm.prank(founder);
        auction.unpause();

        vm.prank(bidder1);
        auction.createBid{value: 0.420 ether}(1);

        vm.warp(9 minutes);

        vm.prank(bidder2);
        auction.createBid{value: 1 ether}(1);

        (, , , , uint256 endTime, ) = auction.auction();

        assertEq(endTime, 14 minutes);
    }

    function testRevert_AuctionExpired() public {
        vm.prank(founder);
        auction.unpause();

        vm.warp(10 minutes + 1 seconds);

        vm.prank(bidder1);
        vm.expectRevert(abi.encodeWithSignature("AUCTION_OVER()"));
        auction.createBid{value: 0.420 ether}(1);
    }

    ///                                                          ///
    ///                                                          ///
    ///                                                          ///

    function test_SettleAuction() public {
        vm.prank(founder);
        auction.unpause();

        vm.prank(bidder1);
        auction.createBid{value: 0.420 ether}(1);

        vm.prank(bidder2);
        auction.createBid{value: 1 ether}(1);

        vm.warp(10 minutes + 1 seconds);

        auction.settleCurrentAndCreateNewAuction();

        assertEq(token.ownerOf(1), bidder2);
        assertEq(token.getVotes(bidder2), 1);

        assertEq(address(timelock).balance, 1 ether);
    }

    function testRevert_CannotSettleWhenAuctionStillActive() public {
        vm.prank(founder);
        auction.unpause();

        vm.prank(bidder1);
        auction.createBid{value: 0.420 ether}(1);

        vm.warp(5 minutes);

        vm.prank(bidder2);
        auction.createBid{value: 1 ether}(1);

        vm.expectRevert(abi.encodeWithSignature("AUCTION_NOT_OVER()"));
        auction.settleCurrentAndCreateNewAuction();
    }

    function testRevert_TokenBurnFromNoBids() public {
        vm.prank(founder);
        auction.unpause();

        assertEq(token.ownerOf(1), address(auction));

        vm.warp(10 minutes + 1 seconds);
        auction.settleCurrentAndCreateNewAuction();

        vm.expectRevert(abi.encodeWithSignature("NO_OWNER()"));
        token.ownerOf(1);
    }

    function test_OnlySettleWhenPaused() public {
        vm.prank(founder);
        auction.unpause();

        vm.prank(bidder1);
        auction.createBid{value: 0.420 ether}(1);

        vm.prank(bidder2);
        auction.createBid{value: 1 ether}(1);

        vm.warp(10 minutes + 1 seconds);

        vm.prank(address(timelock));
        auction.pause();

        auction.settleAuction();

        (, , , , , bool settled) = auction.auction();

        assertEq(settled, true);
    }

    function testRevert_CannotOnlySettleWhenNotPaused() public {
        vm.prank(founder);
        auction.unpause();

        vm.prank(bidder1);
        auction.createBid{value: 0.420 ether}(1);

        vm.prank(bidder2);
        auction.createBid{value: 1 ether}(1);

        vm.warp(10 minutes + 1 seconds);

        vm.expectRevert(abi.encodeWithSignature("UNPAUSED()"));
        auction.settleAuction();
    }
}