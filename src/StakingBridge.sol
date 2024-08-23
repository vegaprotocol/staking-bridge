// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IStake} from "./IStake.sol";

/// @title ERC20 Staking Bridge
/// @author Vega Protocol
/// @notice This contract manages the vesting of the Vega V2 ERC20 token
contract StakingBridge is IStake {
    using SafeERC20 for IERC20;

    error InsufficientBalance(address user, bytes32 vegaPublicKey, uint256 stakeBalance, uint256 needed);

    IERC20 public immutable token;

    constructor(address tokenAddress) {
        token = IERC20(tokenAddress);
    }

    /// @dev user => amount staked
    mapping(address user => mapping(bytes32 vegaPublicKey => uint256 stakingBalance)) stakes;

    /// @notice This stakes the given amount of tokens and credits them to the provided Vega public key
    /// @param amount Token amount to stake
    /// @param vegaPublicKey Target Vega public key to be credited with the stake
    /// @dev Emits StakeDeposited event
    /// @dev User MUST run "approve" on token prior to running Stake
    function stake(uint256 amount, bytes32 vegaPublicKey) public {
        token.transferFrom(msg.sender, address(this), amount);
        stakes[msg.sender][vegaPublicKey] += amount;
        emit StakeDeposited(msg.sender, amount, vegaPublicKey);
    }

    function stake(uint256 amount, bytes32 vegaPublicKey, address owner) public {
        token.transferFrom(msg.sender, address(this), amount);
        stakes[owner][vegaPublicKey] += amount;
        emit StakeDeposited(msg.sender, amount, vegaPublicKey);
        emit StakeTransferred(msg.sender, amount, owner, vegaPublicKey);
    }

    /// @notice This removes specified amount of stake of available to user
    /// @dev Emits StakeRemoved event if successful
    /// @param amount Amount of tokens to remove from staking
    /// @param vegaPublicKey Target Vega public key from which to deduct stake
    function removeStake(uint256 amount, bytes32 vegaPublicKey) public {
        uint256 currentStake = stakes[msg.sender][vegaPublicKey];
	if (amount > currentStake) {
            revert InsufficientBalance(msg.sender, vegaPublicKey, currentStake, amount - currentStake);
        }
        stakes[msg.sender][vegaPublicKey] -= amount;
        token.transfer(msg.sender, amount);
        emit StakeRemoved(msg.sender, amount, vegaPublicKey);
    }

    /// @notice This transfers all stake from the sender's address to the "newAddress"
    /// @dev Emits Stake_Transfered event if successful
    /// @param amount Stake amount to transfer
    /// @param newAddress Target ETH address to recieve the stake
    /// @param vegaPublicKey Target Vega public key to be credited with the transfer
    function transferStake(uint256 amount, address newAddress, bytes32 vegaPublicKey) public {
        uint256 currentStake = stakes[msg.sender][vegaPublicKey];
        if (amount > currentStake) {
            revert InsufficientBalance(msg.sender, vegaPublicKey, currentStake, amount - currentStake);
        }
        stakes[msg.sender][vegaPublicKey] -= amount;
        stakes[newAddress][vegaPublicKey] += amount;
        emit StakeTransferred(msg.sender, amount, newAddress, vegaPublicKey);
    }

    /// @dev This is IStake.stakeBalance
    /// @param target Target address to check
    /// @param vegaPublicKey Target vega public key to check
    /// @return the number of tokens staked for that address->vegaPublicKey pair
    function stakeBalance(address target, bytes32 vegaPublicKey) external view override returns (uint256) {
        return stakes[target][vegaPublicKey];
    }

    /// @dev This is IStake.totalStaked
    /// @return total tokens staked on contract
    function totalStaked() external view override returns (uint256) {
        return token.balanceOf(address(this));
    }

    /// @dev This is IStake.stakingToken
    /// @return total tokens staked on contract
    function stakingToken() external view returns (address) {
        return address(token);
    }
}
