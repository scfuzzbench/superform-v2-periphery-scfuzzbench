// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {Asserts} from "@chimera/Asserts.sol";

import {OpType} from "test/recon/BeforeAfter.sol";
import {BeforeAfter} from "./BeforeAfter.sol";

abstract contract Properties is BeforeAfter, Asserts {
    /// @dev Property: oracle PPS doesn't change on deposit/mint/redeem/withdraw
    function property_oraclePPSDoesntChangeOnAddOrRemove() public {
        if (_currentOp == OpType.ADD || _currentOp == OpType.REMOVE) {
            eq(
                _before.oraclePPS,
                _after.oraclePPS,
                "deposit/withdrawal changes oracle PPS"
            );
        }
    }

    /// @dev Property: naive PPS doesn't change on deposit/mint/redeem/withdraw
    function property_naivePPSDoesntChangeOnAddOrRemove() public {
        if (
            (_currentOp == OpType.ADD || _currentOp == OpType.REMOVE) &&
            _before.summedTotalShares == 0 // if no shares existed before the naively calculated price is 0 so causes a false positive
        ) {
            eq(
                _before.naivePPS,
                _after.naivePPS,
                "deposit/withdrawal changes naive PPS"
            );
        }
    }

    /// @dev Property: fulfillRedeemRequest doesn't change naive PPS
    function property_naivePPSDoesntChangeOnRedeem() public {
        if (_currentOp == OpType.FULFILL) {
            eq(
                _before.naivePPS,
                _after.naivePPS,
                "fulfilling redemption changes naive PPS"
            );
        }
    }

    /// @dev Property: maxRedeem and maxWithdraw should always be equivalent
    function property_maxRedeemMaxWithdrawSymmetry() public {
        uint256 maxWithdraw = superVault.maxWithdraw(_getActor());
        uint256 maxWithdrawAsShares = superVault.convertToShares(maxWithdraw);
        uint256 maxRedeem = superVault.maxRedeem(_getActor());

        eq(maxWithdrawAsShares, maxRedeem, "maxWithdrawAsShares != maxRedeem");
    }

    /// @dev Property: PPS for a strategy should always be > 0
    function property_ppsNeverZero() public {
        uint256 currentPPS = superVaultAggregator.getPPS(
            address(superVaultStrategy)
        );

        if (hasUpdatedPPS) {
            gt(currentPPS, 0, "currentPPS should never be 0");
        }
    }

    /// @dev requestRedeem should never reduce SuperVault shares
    function property_totalSharesDontDecreaseOnRedemptionRequest() public {
        if (_currentOp == OpType.REQUEST) {
            eq(
                _before.summedTotalShares,
                _after.summedTotalShares,
                "requestRedeem should never reduce SuperVault shares"
            );
        }
    }

    /// @dev `SuperVault::totalSupply` == SUM(user balances) + balanceOf(escrow)
    function property_shareSolvency() public {
        eq(
            superVault.totalSupply(),
            _after.summedTotalShares,
            "vault shares are insolvent"
        );
    }

    /// @dev Property: balanceOf(escrow) >= SUM(controllers.pendingRedeemRequest)
    function property_escrowBalance() public {
        address[] memory actors = _getActors();

        uint256 escrowBalance = superVault.balanceOf(address(superVaultEscrow));
        uint256 pendingAtorShares;
        for (uint256 i; i < actors.length; i++) {
            pendingAtorShares += superVault.pendingRedeemRequest(0, actors[i]);
        }

        gte(
            escrowBalance,
            pendingAtorShares,
            "balanceOf(escrow) < SUM(controllers.pendingRedeemRequest)"
        );
    }
}
