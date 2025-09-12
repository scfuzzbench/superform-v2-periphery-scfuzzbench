# Properties Table

## SuperVault 
| Property | Description | Implemented | Tested |
| --- | --- | --- | --- |
| `doomsday_mintRedeemSymmetrical` | deposit/redeem is symmetrical, no value gained due to rounding | ✅ |  |
| `doomsday_depositWithdrawSymmetrical` | deposit/withdraw is symmetrical, no value gained due to rounding | ✅ |  |
| `doomsday_maxRedeemResetsAfterFullRedemption` | `maxRedeem` is reset to 0 after full redemption | ✅ |  |
| `doomsday_maxRedeemResetsAfterFullRedemption` | `maxRedeem` is reset to 0 after full redemption | ✅ |  |
| `doomsday_maxWithdrawResetsAfterFullWithdrawal` | `maxWithdraw` is reset to 0 after full withdrawal | ✅ |  |
| `doomsday_fulfillDoesntOverRedeemMultipleActors` | fulfillRedeemRequests doesn't redeem more than requested for multiple actors | ✅ |  |
| `property_naivePPSDoesntChangeOnRedeem` | fulfillRedeemRequest doesn't change naive PPS | ✅ | ❌ |
| `property_oraclePPSDoesntChangeOnAddOrRemove` | oracle PPS doesn't change on deposit/mint/redeem/withdraw | ✅ |  |
| `property_naivePPSDoesntChangeOnAddOrRemove` | naive PPS (assets/shares in system) never changes on deposit/mint/redeem/withdraw  | ✅ |  |
| `property_maxRedeemMaxWithdrawSymmetry` | `maxRedeem` and `maxWithdraw` should always be equivalent  | ✅ |  |
| `property_totalSharesDontDecreaseOnRedemptionRequest` | `requestRedeem` should never reduce `SuperVault` shares  | ✅ |  |
| `superVault_cancelRedeem` | `pendingRedeemRequest` should be 0 after a user calls `cancelRedeem`  | ✅ |  |
| `superVault_cancelRedeem` | `averageRequestPPS` should be 0 after a user calls `cancelRedeem`  | ✅ |  |
| `superVault_cancelRedeem` | user shouldn't receive more than convertToAssets(pendingRedeemRequest) after cancelRedeem | ✅ |  |
| `property_shareSolvency` | `SuperVault::totalSupply` == SUM(user balances) + balanceOf(escrow)  (solvency) | ✅ |  |
| `property_escrowBalance` | balanceOf(escrow) >= SUM(controllers.pendingRedeemRequest) | ✅ |  |
| `superVaultStrategy_fulfillRedeemRequests` | redemptions only burn the requested amount of shares (exact check) | ✅ |  |
| `property_maxMintZeroWhenPaused` | `maxMint` should be 0 when aggregator is paused | ✅ |  |
| `property_maxDepositZeroWhenPaused` | `maxDeposit` should be 0 when strategy is paused | ✅ |  |
| `property_avgWithdrawPriceSanity` | If user's maxWithdraw == 0 then getAverageWithdrawPrice for the user is also == 0 | ✅ |  |
| `property_accumulatorSharesSolvency` | SUM(accumulatorShares) doesn't change on `SuperVault` share transfers | ✅ |  |
| `property_accumulatorCostBasisSolvency` | SUM(accumulatorCostBasis) doesn't change on `SuperVault` share transfers | ✅ |  |
| `superVaultStrategy_fulfillRedeemRequests` | `accumulatorShares` decreases by the exact amounts requested when fulfilling redemptions | ✅ |  |
| `superVaultStrategy_fulfillRedeemRequests` | `accumulatorCostBasis` decrease by the exact amounts requested when fulfilling redemptions | ✅ |  |
| `property_cannotClaimMoreThanRequested` | user cannot claim more assets than requested in redemption | ✅ |  |
| `property_x` | PPS updates with a difference that exceeds maxPPSSlippage must revert |  |  |
| `property_x` | `requestRedeem()` should never alters the supply of SuperVault tokens (calculated by summing user share balances) |  |  |
| `property_x` | `cancelRedeem()` should never alters the supply of SuperVault tokens (calculated by summing user share balances) |  |  |
| `property_x` | if `totalAssets()` > 0, then `totalSupply()` > 0 |  |  |
| `property_x` | users shouldn't get a favorable exchange rate on loss on withdrawal in a yield vault |  |  |
| `property_x` | user shouldn't be able to frontrun an oracle update to get a favorable exchange when there's a loss (TODO: determine how to test this) |  |  |
| `property_x` | totalSupply * PPS == totalAssets |  |  |
| `property_x` | user should always be able to redeem the assets they're entitled to |  |  |
| `property_x` | `accumulatorShares` is always accurately updated (inductive) |  |  |
| `property_x` | `accumulatorCostBasis` is always accurately updated (inductive) |  |  |
| `property_x` | `_update` shouldn't change the `accumulatorShares` and `accumulatorCostBasis` |  |  |
| `property_x` | `_update` should never revert |  |  |
| `property_x` | `previewDeposit` returns the correct amounts compared to executing a deposit |  |  |
| `property_x` | `previewRedeem` returns the correct amounts compared to executing a redemption |  |  |
| `property_x` | `previewMint` and `previewDeposit` equivalence |  |  |
| `property_x` | When a user requests a redemption and the PPS is >= the user PPS, user `averageRequestPPS` must not decrease |  |  |


## SuperVaultAggregator 
| Property | Description | Implemented | Tested |
| --- | --- | --- | --- |
| `doomsday_primaryManagerAlwaysChangeable` | primary manager can always be replaced by governance via `changePrimaryManager` | ✅ | |

## SuperVaultEscrow 
| Property | Description | Implemented | Tested |
| --- | --- | --- | --- |
| `property_x` | <property description in plain English> | | |

## SuperVaultStrategy 
| Property | Description | Implemented | Tested |
| --- | --- | --- | --- |
| `property_x` | `fulfillRedeemRequests` should never fulfill redemptions for more shares than requested |  |  |