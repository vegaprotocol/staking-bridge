// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {StakingBridge} from "../src/staking-bridge.sol";

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

    /* function test_RemoveTokenAndEmitEvent() public { */
    /*     bytes32 pkey = 0x17a33504a3f676fe940d629da5105402df8c4b8d9d2665c02ed280abb0aa4278; */
    /* 	address user = address(1337); */
    /*     assertEq(bridge.totalStaked(), 0); */
    /* } */

    /* function testFuzz_SetNumber(uint256 x) public { */
    /*     counter.setNumber(x); */
    /*     assertEq(counter.number(), x); */
    /* } */
}
