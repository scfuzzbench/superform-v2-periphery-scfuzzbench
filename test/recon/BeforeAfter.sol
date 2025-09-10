// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {Setup} from "./Setup.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

enum OpType {
    DEFAULT,
    ADD,
    REMOVE,
    FULFILL
}

// ghost variables for tracking state variable values before and after function calls
abstract contract BeforeAfter is Setup {
    struct Vars {
        uint256 oraclePPS;
        uint256 naivePPS;
    }

    Vars internal _before;
    Vars internal _after;
    OpType internal _currentOp;

    modifier updateGhosts() {
        _currentOp = OpType.DEFAULT;
        __before();
        _;
        __after();
    }

    modifier updateGhostsWithOpType(OpType op) {
        _currentOp = op;
        __before();
        _;
        __after();
    }

    function __before() internal {
        _before.oraclePPS = superVaultAggregator.getPPS(
            address(superVaultStrategy)
        );
        _before.naivePPS = _calculateNaivePPS();
    }

    function __after() internal {
        _after.oraclePPS = superVaultAggregator.getPPS(
            address(superVaultStrategy)
        );
        _after.naivePPS = _calculateNaivePPS();
    }

    /// @notice Calculates the naive price per share by summing all assets across strategy and yield sources
    /// @return naivePPS The calculated price per share (scaled by 1e18)
    function _calculateNaivePPS() internal view returns (uint256 naivePPS) {
        // Get the underlying asset
        address asset = superVault.asset();

        // Get total supply of SuperVault shares
        uint256 totalSupply = superVault.totalSupply();

        // If no shares exist, PPS is 1e18 (1:1)
        if (totalSupply == 0) {
            return 0;
        }

        // Calculate total assets across all locations
        uint256 totalAssets;

        // 1. Assets held directly in SuperVaultStrategy
        totalAssets += IERC20(asset).balanceOf(address(superVaultStrategy));

        // 2. Loop through all yield sources and sum underlying asset balances
        address[] memory yieldSources = _getYieldSources();
        for (uint256 i = 0; i < yieldSources.length; i++) {
            if (yieldSources[i] != address(0)) {
                // Get the underlying asset balance held in each yield source
                totalAssets += IERC20(asset).balanceOf(yieldSources[i]);
            }
        }

        // Calculate naive PPS: (totalAssets * PRECISION) / totalSupply
        // Using 1e18 as precision to match the system's PPS_DECIMALS
        naivePPS = (totalAssets * superVault.PRECISION()) / totalSupply;

        return naivePPS;
    }
}
