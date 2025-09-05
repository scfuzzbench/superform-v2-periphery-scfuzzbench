// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {BeforeAfter} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";
// Chimera deps
import {vm} from "@chimera/Hevm.sol";

// Helpers
import {Panic} from "@recon/Panic.sol";

import "src/SuperVault/SuperVault.sol";

abstract contract SuperVaultTargets is BaseTargetFunctions, Properties {
    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///

    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///

    function superVault_approve(address spender, uint256 value) public asActor {
        superVault.approve(spender, value);
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

    function superVault_burnShares(uint256 amount) public asActor {
        superVault.burnShares(amount);
    }

    function superVault_cancelRedeem(address controller) public asActor {
        superVault.cancelRedeem(controller);
    }

    function superVault_deposit(
        uint256 assets,
        address receiver
    ) public asActor {
        superVault.deposit(assets, receiver);
    }

    function superVault_invalidateNonce(bytes32 nonce) public asActor {
        superVault.invalidateNonce(nonce);
    }

    function superVault_mint(uint256 shares, address receiver) public asActor {
        superVault.mint(shares, receiver);
    }

    function superVault_redeem(
        uint256 shares,
        address receiver,
        address controller
    ) public asActor {
        superVault.redeem(shares, receiver, controller);
    }

    function superVault_requestRedeem(
        uint256 shares,
        address controller,
        address owner
    ) public asActor {
        superVault.requestRedeem(shares, controller, owner);
    }

    function superVault_setOperator(
        address operator,
        bool approved
    ) public asActor {
        superVault.setOperator(operator, approved);
    }

    function superVault_transfer(address to, uint256 value) public asActor {
        superVault.transfer(to, value);
    }

    function superVault_transferFrom(
        address from,
        address to,
        uint256 value
    ) public asActor {
        superVault.transferFrom(from, to, value);
    }

    function superVault_withdraw(
        uint256 assets,
        address receiver,
        address controller
    ) public asActor {
        superVault.withdraw(assets, receiver, controller);
    }
}
