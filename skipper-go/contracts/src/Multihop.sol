// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IUniswapV2Router02} from "uniswap-v2-periphery/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Pair} from "uniswap-v2-core/interfaces/IUniswapV2Pair.sol";

contract Multihop is Ownable {
    /**
     * @dev Struct that defines a bundle of trades along a arbitrage route.
     * Hops are separated by DEXes.
     * @param pairAddress The address of the pair you are performing the swap on
     * @param zeroToOne Whether the swap is from the pools token0 -> token1 or token1 -> token0
     * @param fee The DEX's fee amount in hundredths (Example: 0.03% = 3)
     */
    struct DexHop {
        address pairAddress;
        bool zeroToOne;
        uint256 fee;
    }

    // ------------------- Functions ------------------- //
    /**
     * @dev Allows the contract to receive funds
     */
    receive() external payable {}

    /**
     * @dev Executes an arbitrage between the DEXes
     * @param fromToken Address of the token to sell
     * @param fromAmount Amount of tokens to sell
     * @param route Route of the arbitrage
     */
        function swapMultihop(
        address fromToken,
        uint256 fromAmount,
        DexHop[] memory route
    ) external onlyOwner {
        // Get the initial balance of the token
        uint256 initialBalance = IERC20(fromToken).balanceOf(address(this));

        require(initialBalance >= fromAmount, "Insufficient contract balance for the swap");

        // Adjust fromAmount if it's more than the initial balance
        if (fromAmount > initialBalance) {
            fromAmount = initialBalance;
        }

        // Transfer fromAmount to first pair in the route
        IERC20(fromToken).transfer(route[0].pairAddress, fromAmount);

        // Loop through the route and execute the trades
        for (uint256 i = 0; i < route.length; i++) {
            DexHop memory hop = route[i];

            address destination = i == route.length - 1
                ? address(this)
                : route[i + 1].pairAddress;

            fromAmount = swapOnDex(hop, fromAmount, destination);
        }

        // Get the final balance of the token
        uint256 finalBalance = IERC20(fromToken).balanceOf(address(this));

        // Require that the arbitrage was profitable
        require(
            finalBalance > initialBalance,
            "The arbitrage was not profitable"
        );
    }

    /**
     * @dev Execute a trade given a DEX, token and amount. returns the amount of tokens received.
     * @param hop Hop of the arbitrage
     * @param amount Amount of tokens to sell
     * @param destination Address to send tokens to
     */
    function swapOnDex(
        DexHop memory hop,
        uint256 amount,
        address destination
    ) internal returns (uint256) {
        (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(hop.pairAddress)
            .getReserves();

        (uint256 reserveIn, uint256 reserveOut) = hop.zeroToOne
            ? (reserve0, reserve1)
            : (reserve1, reserve0);

        uint256 fromAmountWithFee = amount * (1000 - hop.fee);

        amount = (fromAmountWithFee * reserveOut) / ((reserveIn * 1000) + fromAmountWithFee);

        IUniswapV2Pair(hop.pairAddress).swap(
            hop.zeroToOne ? 0 : amount,
            hop.zeroToOne ? amount : 0,
            destination,
            ""
        );

        return amount;
    }

    /**
     * @dev Withdraws the funds from the contract
     * @param token Address of the token to withdraw
     */
    function withdraw(address token) external onlyOwner returns (bool) {
        uint256 balance = IERC20(token).balanceOf(address(this));
        return IERC20(token).transfer(owner(), balance);
    }

    /**
     * @dev Withdraws the funds from the contract
     */
    function withdrawNativeBalance() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(owner()).transfer(balance);
    }
}
