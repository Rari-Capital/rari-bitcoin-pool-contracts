/**
 * COPYRIGHT © 2020 RARI CAPITAL, INC. ALL RIGHTS RESERVED.
 * Anyone is free to integrate the public (i.e., non-administrative) application programming interfaces (APIs) of the official Ethereum smart contract instances deployed by Rari Capital, Inc. in any application (commercial or noncommercial and under any license), provided that the application does not abuse the APIs or act against the interests of Rari Capital, Inc.
 * Anyone is free to study, review, and analyze the source code contained in this package.
 * Reuse (including deployment of smart contracts other than private testing on a private network), modification, redistribution, or sublicensing of any source code contained in this package is not permitted without the explicit permission of David Lucid of Rari Capital, Inc.
 * No one is permitted to use the software for any purpose other than those allowed by this license.
 * This license is liable to change at any time at the sole discretion of David Lucid of Rari Capital, Inc.
 */

pragma solidity 0.5.17;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";

import "../../external/aavev2/ILendingPool.sol";
import "../../external/aave/AToken.sol";

/**
 * @title AaveV2PoolController
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 * @dev This library handles deposits to and withdrawals from Aave V2 liquidity pools.
 */
library AaveV2PoolController {
    using SafeERC20 for IERC20;

    /**
     * @dev Aave LendingPool contract address.
     */
    address constant private LENDING_POOL_CONTRACT = 0x398eC7346DcD622eDc5ae82352F02bE94C62d119;

    /**
     * @dev Aave LendingPool contract object.
     */
    ILendingPool constant private _lendingPool = ILendingPool(LENDING_POOL_CONTRACT);

    /**
     * @dev Returns a token's aToken contract address given its ERC20 contract address.
     * @param erc20Contract The ERC20 contract address of the token.
     */
    function getATokenContract(address erc20Contract) private pure returns (address) {
        if (erc20Contract == 0x2260fac5e5542a773aa44fbcfedf7c193bc2c599) return 0x9ff58f4fFB29fA2266Ab25e75e2A8b3503311656; // WBTC => aWBTC
        else revert("Supported Aave aToken address not found for this token address.");
    }

    /**
     * @dev Returns the fund's balance of the specified currency in the Aave pool.
     * @param erc20Contract The ERC20 contract address of the token.
     */
    function getBalance(address erc20Contract) external view returns (uint256) {
        AToken aToken = AToken(getATokenContract(erc20Contract));
        return aToken.balanceOf(address(this));
    }

    /**
     * @dev Approves tokens to Aave without spending gas on every deposit.
     * @param erc20Contract The ERC20 contract address of the token.
     * @param amount Amount of the specified token to approve to Aave.
     */
    function approve(address erc20Contract, uint256 amount) external {
        IERC20 token = IERC20(erc20Contract);
        uint256 allowance = token.allowance(address(this), LENDING_POOL_CONTRACT);
        if (allowance == amount) return;
        if (amount > 0 && allowance > 0) token.safeApprove(LENDING_POOL_CONTRACT, 0);
        token.safeApprove(LENDING_POOL_CONTRACT, amount);
        return;
    }

    /**
     * @dev Deposits funds to the Aave pool. Assumes that you have already approved >= the amount to Aave.
     * @param erc20Contract The ERC20 contract address of the token to be deposited.
     * @param amount The amount of tokens to be deposited.
     * @param referralCode Referral code.
     */
    function deposit(address erc20Contract, uint256 amount, uint16 referralCode) external {
        require(amount > 0, "Amount must be greater than 0.");
        _lendingPool.deposit(erc20Contract, amount, address(this), referralCode);
    }

    /**
     * @dev Withdraws funds from the Aave pool.
     * @param erc20Contract The ERC20 contract address of the token to be withdrawn.
     * @param amount The amount of tokens to be withdrawn.
     */
    function withdraw(address erc20Contract, uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0.");
        _lendingPool.withdraw(erc20Contract, amount, address(this));
    }

    /**
     * @dev Withdraws all funds from the Aave pool.
     * @param erc20Contract The ERC20 contract address of the token to be withdrawn.
     * @return Boolean indicating success.
     */
    function withdrawAll(address erc20Contract) external returns (bool) {
        AToken aToken = AToken(getATokenContract(erc20Contract));
        uint256 balance = aToken.balanceOf(address(this));
        if (balance <= 0) return false;
        _lendingPool.withdraw(erc20Contract, balance, address(this));
        return true;
    }
}
