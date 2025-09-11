// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

// Recon deps
import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {vm} from "@chimera/Hevm.sol";
import {Panic} from "@recon/Panic.sol";

import "src/SuperVault/SuperVault.sol";

import {BeforeAfter, OpType} from "test/recon/BeforeAfter.sol";
import {Properties} from "../Properties.sol";

/// @dev All receivers are inherently clamped to actors to make checking properties easier
abstract contract SuperVaultTargets is BaseTargetFunctions, Properties {
    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///
    function superVault_requestRedeem_clamped(uint256 shares) public {
        shares %= superVault.balanceOf(_getActor());

        superVault_requestRedeem(shares);
    }

    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///

    function superVault_approve(address spender, uint256 value) public asActor {
        superVault.approve(spender, value);
    }

    function superVault_burnShares(uint256 amount) public asActor {
        superVault.burnShares(amount);
    }

    /// @dev Property: pendingRedeemRequest should be 0 after a user calls cancelRedeem
    function superVault_cancelRedeem() public asActor {
        superVault.cancelRedeem(_getActor());

        uint256 pendingRedeemRequests = superVault.pendingRedeemRequest(
            0,
            _getActor()
        );
        eq(
            pendingRedeemRequests,
            0,
            "pendingRedeemRequests should be 0 after cancelling a redemption"
        );
    }

    function superVault_deposit(
        uint256 assets
    ) public updateGhostsWithOpType(OpType.ADD) asActor {
        superVault.deposit(assets, _getActor());
    }

    function superVault_invalidateNonce(bytes32 nonce) public asActor {
        superVault.invalidateNonce(nonce);
    }

    function superVault_mint(
        uint256 shares
    ) public updateGhostsWithOpType(OpType.ADD) asActor {
        superVault.mint(shares, _getActor());
    }

    function superVault_redeem(
        uint256 shares
    ) public updateGhostsWithOpType(OpType.REMOVE) asActor {
        superVault.redeem(shares, _getActor(), _getActor());
    }

    function superVault_withdraw(
        uint256 assets
    ) public updateGhostsWithOpType(OpType.REMOVE) asActor {
        superVault.withdraw(assets, _getActor(), _getActor());
    }

    function superVault_requestRedeem(
        uint256 shares
    ) public updateGhostsWithOpType(OpType.REQUEST) asActor {
        superVault.requestRedeem(shares, _getActor(), _getActor());
    }

    function superVault_setOperator(
        uint256 entropy,
        bool approved
    ) public asActor {
        address operator = _getRandomActor(entropy);
        superVault.setOperator(operator, approved);
    }

    function superVault_transfer(
        uint256 entropy,
        uint256 value
    ) public asActor {
        address to = _getRandomActor(entropy);
        superVault.transfer(to, value);
    }

    function superVault_transferFrom(
        uint256 entropyFrom,
        uint256 entropyTo,
        uint256 value
    ) public asActor {
        address from = _getRandomActor(entropyFrom);
        address to = _getRandomActor(entropyTo);
        superVault.transferFrom(from, to, value);
    }

    /// @dev removed because signature components not fuzzable
    // function superVault_authorizeOperator(
    //     address controller,
    //     address operator,
    //     bool approved,
    //     bytes32 nonce,
    //     uint256 deadline,
    //     bytes memory signature
    // ) public asActor {
    //     superVault.authorizeOperator(
    //         controller,
    //         operator,
    //         approved,
    //         nonce,
    //         deadline,
    //         signature
    //     );
    // }
}
