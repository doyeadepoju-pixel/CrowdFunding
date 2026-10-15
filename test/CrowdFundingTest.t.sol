// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {CrowdFunding} from "../src/CrowdFunding.sol";
import {MockToken} from "../src/MockToken.sol";

contract CrowdFundingTest is Test {
    CrowdFunding cf;
    MockToken token;

    // Test users
    address creator = makeAddr("creator");
    address alice   = makeAddr("alice");
    address bob     = makeAddr("bob");

    uint256 constant GOAL = 100_000e18;   // ₦100,000 in mNGN (18 decimals)

    function setUp() public {
        token = new MockToken();
        cf = new CrowdFunding(address(token));

        // Give Alice and Bob tokens, and let the contract spend them
        token.mint(alice, 200_000e18);
        token.mint(bob, 200_000e18);

        vm.prank(alice);
        token.approve(address(cf), type(uint256).max);
        vm.prank(bob);
        token.approve(address(cf), type(uint256).max);
    }

    // Helper: creator starts a 7-day campaign
    function _createCampaign() internal returns (uint256 id) {
        vm.prank(creator);
        id = cf.createCampaign(GOAL, 7 days, "Solar panels for a school");
    }

    // ------------------------------------------------------------
    // createCampaign
    // ------------------------------------------------------------
    function test_CreateCampaign() public {
        uint256 id = _createCampaign();

        (
            address c,
            uint256 goal,
            uint256 total,
            uint64 deadline,
            bool ended,
            string memory description
        ) = cf.campaigns(id);

        assertEq(id, 1);
        assertEq(cf.campaignCount(), 1);
        assertEq(c, creator);
        assertEq(goal, GOAL);
        assertEq(total, 0);
        assertEq(deadline, block.timestamp + 7 days);
        assertFalse(ended);
        assertEq(description, "Solar panels for a school");
        assertEq(uint256(cf.getStatus(id)), uint256(CrowdFunding.Status.campaignActive));
    }

    function test_RevertWhen_GoalIsZero() public {
        vm.expectRevert(CrowdFunding.InvalidGoal.selector);
        cf.createCampaign(0, 7 days, "x");
    }

    function test_RevertWhen_DurationIsZero() public {
        vm.expectRevert(CrowdFunding.InvalidDuration.selector);
        cf.createCampaign(GOAL, 0, "x");
    }

    function test_RevertWhen_DurationTooLong() public {
        vm.expectRevert(CrowdFunding.InvalidDuration.selector);
        cf.createCampaign(GOAL, 91 days, "x");
    }

    // ------------------------------------------------------------
    // pledge
    // ------------------------------------------------------------
    function test_Pledge() public {
        uint256 id = _createCampaign();

        vm.prank(alice);
        cf.pledge(id, 30_000e18);
        vm.prank(bob);
        cf.pledge(id, 20_000e18);

        (, , uint256 total, , , ) = cf.campaigns(id);
        assertEq(total, 50_000e18);
        assertEq(cf.pledgedAmount(id, alice), 30_000e18);
        assertEq(cf.pledgedAmount(id, bob), 20_000e18);
        assertEq(token.balanceOf(address(cf)), 50_000e18);
        assertEq(token.balanceOf(alice), 170_000e18);
    }

    function test_RevertWhen_PledgeZero() public {
        uint256 id = _createCampaign();
        vm.prank(alice);
        vm.expectRevert(CrowdFunding.InvalidAmount.selector);
        cf.pledge(id, 0);
    }

    function test_RevertWhen_PledgeToMissingCampaign() public {
        vm.prank(alice);
        vm.expectRevert(CrowdFunding.CampaignNotFound.selector);
        cf.pledge(99, 1e18);
    }

    function test_RevertWhen_PledgeAfterDeadline() public {
        uint256 id = _createCampaign();
        vm.warp(block.timestamp + 7 days); // jump to the deadline

        vm.prank(alice);
        vm.expectRevert(CrowdFunding.CampaignNotActive.selector);
        cf.pledge(id, 1e18);
    }

    function test_RevertWhen_PledgeWithoutApproval() public {
        uint256 id = _createCampaign();
        address carol = makeAddr("carol");
        token.mint(carol, 10e18); // carol has tokens but never approved

        vm.prank(carol);
        vm.expectRevert(); // the token itself rejects the transfer
        cf.pledge(id, 10e18);
    }

    // ------------------------------------------------------------
    // withdraw (goal met)
    // ------------------------------------------------------------
    function test_Withdraw() public {
        uint256 id = _createCampaign();
        vm.prank(alice);
        cf.pledge(id, 60_000e18);
        vm.prank(bob);
        cf.pledge(id, 40_000e18); // exactly the goal

        vm.warp(block.timestamp + 7 days);
        assertEq(uint256(cf.getStatus(id)), uint256(CrowdFunding.Status.goalAchieved));

        vm.prank(creator);
        cf.withdraw(id);

        assertEq(token.balanceOf(creator), GOAL);
        assertEq(token.balanceOf(address(cf)), 0);
        assertEq(uint256(cf.getStatus(id)), uint256(CrowdFunding.Status.campaignEnded));
    }

    function test_RevertWhen_WithdrawBeforeDeadline() public {
        uint256 id = _createCampaign();
        vm.prank(alice);
        cf.pledge(id, GOAL);

        vm.prank(creator);
        vm.expectRevert(CrowdFunding.CampaignStillActive.selector);
        cf.withdraw(id);
    }

    function test_RevertWhen_WithdrawByNonCreator() public {
        uint256 id = _createCampaign();
        vm.prank(alice);
        cf.pledge(id, GOAL);
        vm.warp(block.timestamp + 7 days);

        vm.prank(alice);
        vm.expectRevert(CrowdFunding.NotCreator.selector);
        cf.withdraw(id);
    }

    function test_RevertWhen_WithdrawGoalNotMet() public {
        uint256 id = _createCampaign();
        vm.prank(alice);
        cf.pledge(id, 10_000e18);
        vm.warp(block.timestamp + 7 days);

        vm.prank(creator);
        vm.expectRevert(CrowdFunding.GoalNotAchieved.selector);
        cf.withdraw(id);
    }

    function test_RevertWhen_WithdrawTwice() public {
        uint256 id = _createCampaign();
        vm.prank(alice);
        cf.pledge(id, GOAL);
        vm.warp(block.timestamp + 7 days);

        vm.startPrank(creator);
        cf.withdraw(id);
        vm.expectRevert(CrowdFunding.CampaignAlreadyEnded.selector);
        cf.withdraw(id);
        vm.stopPrank();
    }

    // ------------------------------------------------------------
    // refund (goal NOT met)
    // ------------------------------------------------------------
    function test_Refund() public {
        uint256 id = _createCampaign();
        vm.prank(alice);
        cf.pledge(id, 30_000e18);
        vm.prank(bob);
        cf.pledge(id, 20_000e18); // 50k < 100k goal

        vm.warp(block.timestamp + 7 days);
        assertEq(uint256(cf.getStatus(id)), uint256(CrowdFunding.Status.goalFailed));

        vm.prank(alice);
        cf.refund(id);
        vm.prank(bob);
        cf.refund(id);

        assertEq(token.balanceOf(alice), 200_000e18);
        assertEq(token.balanceOf(bob), 200_000e18);
        assertEq(cf.pledgedAmount(id, alice), 0);
        assertEq(token.balanceOf(address(cf)), 0);
    }

    function test_RevertWhen_RefundBeforeDeadline() public {
        uint256 id = _createCampaign();
        vm.prank(alice);
        cf.pledge(id, 10_000e18);

        vm.prank(alice);
        vm.expectRevert(CrowdFunding.CampaignStillActive.selector);
        cf.refund(id);
    }

    function test_RevertWhen_RefundGoalWasMet() public {
        uint256 id = _createCampaign();
        vm.prank(alice);
        cf.pledge(id, GOAL);
        vm.warp(block.timestamp + 7 days);

        vm.prank(alice);
        vm.expectRevert(CrowdFunding.GoalWasAchieved.selector);
        cf.refund(id);
    }

    function test_RevertWhen_RefundTwice() public {
        uint256 id = _createCampaign();
        vm.prank(alice);
        cf.pledge(id, 10_000e18);
        vm.warp(block.timestamp + 7 days);

        vm.startPrank(alice);
        cf.refund(id);
        vm.expectRevert(CrowdFunding.NothingToRefund.selector);
        cf.refund(id);
        vm.stopPrank();
    }

    function test_RevertWhen_RefundWithNoPledge() public {
        uint256 id = _createCampaign();
        vm.prank(alice);
        cf.pledge(id, 10_000e18);
        vm.warp(block.timestamp + 7 days);

        vm.prank(bob); // bob never pledged
        vm.expectRevert(CrowdFunding.NothingToRefund.selector);
        cf.refund(id);
    }
}
