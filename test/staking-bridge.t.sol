// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {BalanceTooLow, StakingBridge} from "../src/staking-bridge.sol";

contract TestERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address recipient, uint256 amount) external {
        _mint(recipient, amount);
    }

    function burn(address owner, uint256 amount) external {
        _burn(owner, amount);
    }
}

contract StakingBridgeTest is Test {
    event StakeDeposited(address indexed user, uint256 amount, bytes32 indexed vegaPublicKey);
    event StakeRemoved(address indexed user, uint256 amount, bytes32 indexed vegaPublicKey);
    event StakeTransferred(address indexed from, uint256 amount, address indexed to, bytes32 indexed vegaPublicKey);

    TestERC20 public stakingToken;
    StakingBridge public bridge;

    function setUp() public {
        stakingToken = new TestERC20("Staking", "STAKE");
        bridge = new StakingBridge(address(stakingToken));
    }

    // Staking Bridge accepts and locks deposited VEGA
    // tokens and emits Stake_Deposited event (0071-STAK-001)
    function test_LocksTokenAndEmitEvent() public {
        bytes32 pkey = 0x17a33504a3f676fe940d629da5105402df8c4b8d9d2665c02ed280abb0aa4278;
        address user = address(1337);

        assertEq(bridge.totalStaked(), 0);

        // mint token to address 1337
        stakingToken.mint(user, 10);
        assertEq(stakingToken.balanceOf(user), 10);

        // address 1337 approve bridge transfers
        vm.prank(user);
        stakingToken.approve(address(bridge), 10);

        // address 1337 deposit tokens on the staking bridge
        vm.prank(user);

        // check emitted event
        vm.expectEmit(true, true, true, false);
        // The event we expect
        emit StakeDeposited(user, 10, pkey);

        bridge.stake(10, pkey);

        // ensure balances
        assertEq(bridge.totalStaked(), 10);
        assertEq(bridge.stakeBalance(user, pkey), 10);
        assertEq(stakingToken.balanceOf(user), 0);
    }

    // Staking Bridge allows only stakers to remove their
    // staked tokens and emits Stake_Removed event (0071-STAK-002
    function test_RemoveTokenAndEmitEvent() public {
        bytes32 pkey = 0x17a33504a3f676fe940d629da5105402df8c4b8d9d2665c02ed280abb0aa4278;
        address user = address(1337);

        assertEq(bridge.totalStaked(), 0);

        // mint token to address 1337
        stakingToken.mint(user, 10);
        assertEq(stakingToken.balanceOf(user), 10);

        // address 1337 approve bridge transfers
        vm.prank(user);
        stakingToken.approve(address(bridge), 10);

        // address 1337 deposit tokens on the staking bridge
        vm.prank(user);
        bridge.stake(10, pkey);

        // now user unstake 5
        vm.prank(user);

        // check emitted event
        vm.expectEmit(true, true, true, false);
        // The event we expect
        emit StakeRemoved(user, 5, pkey);

        bridge.removeStake(5, pkey);

        // ensure balances
        assertEq(bridge.totalStaked(), 5);
        assertEq(bridge.stakeBalance(user, pkey), 5);
        assertEq(stakingToken.balanceOf(user), 5);
    }

    // Staking Bridge allows users with staked balance to
    // transfer ownership of stake to new ethereum address
    // that only the new address can remove (0071-STAK-003)
    // also
    // Staking Bridge prohibits users from removing stake
    // they have transfered to other ETH address (0071-STAK-013)
    function test_TransferStakeAndEmitEventThenRemoveStake() public {
        bytes32 pkey = 0x17a33504a3f676fe940d629da5105402df8c4b8d9d2665c02ed280abb0aa4278;
        address user = address(1337);
        address user2 = address(1338);

        assertEq(bridge.totalStaked(), 0);

        // mint token to address 1337
        stakingToken.mint(user, 10);
        assertEq(stakingToken.balanceOf(user), 10);

        // address 1337 approve bridge transfers
        vm.prank(user);
        stakingToken.approve(address(bridge), 10);

        // address 1337 deposit tokens on the staking bridge
        vm.prank(user);
        bridge.stake(10, pkey);

        // now user unstake 5
        vm.prank(user);

        // check emitted event
        vm.expectEmit(true, true, true, false);
        // The event we expect
        emit StakeTransferred(user, 10, user2, pkey);

        bridge.transferStake(10, user2, pkey);

        // ensure balances
        assertEq(bridge.totalStaked(), 10);
        assertEq(bridge.stakeBalance(user, pkey), 0);
        assertEq(bridge.stakeBalance(user2, pkey), 10);

        // now user1 try to removeStake
        vm.expectRevert(BalanceTooLow.selector);
        vm.prank(user);
        bridge.removeStake(10, pkey);

        // now user2 try to remove stake
        vm.prank(user2);

        // check emitted event
        vm.expectEmit(true, true, true, false);
        // The event we expect
        emit StakeRemoved(user2, 10, pkey);

        bridge.removeStake(10, pkey);

        // ensure balances
        assertEq(bridge.totalStaked(), 0);
        assertEq(stakingToken.balanceOf(user), 0);
        assertEq(stakingToken.balanceOf(user2), 10);
    }

    // Staking Bridge prohibits users from
    // removing stake they don't own (0071-STAK-012)
    function test_CannotRemoveStakeUserDoNotOwn() public {
        bytes32 pkey = 0x17a33504a3f676fe940d629da5105402df8c4b8d9d2665c02ed280abb0aa4278;
        address user = address(1337);
        assertEq(bridge.totalStaked(), 0);

        // address 1337 deposit tokens on the staking bridge
        vm.expectRevert(BalanceTooLow.selector);
        vm.prank(user);
        bridge.removeStake(10, pkey);
    }
}
