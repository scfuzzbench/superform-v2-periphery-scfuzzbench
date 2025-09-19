# Properties Table

## SuperVault 
| Property | Description | Comments | Implemented | Tested |
| --- | --- | --- | --- | --- |
| `doomsday_mintRedeemSymmetrical` | deposit/redeem is symmetrical, no value gained due to rounding |  | ✅ |  |
| `doomsday_depositWithdrawSymmetrical` | deposit/withdraw is symmetrical, no value gained due to rounding |  | ✅ |  |
| `doomsday_maxRedeemResetsAfterFullRedemption` | `maxRedeem` is reset to 0 after full redemption |  | ✅ |  |
| `doomsday_maxRedeemResetsAfterFullRedemption` | `maxRedeem` is reset to 0 after full redemption |  | ✅ |  |
| `doomsday_maxWithdrawResetsAfterFullWithdrawal` | `maxWithdraw` is reset to 0 after full withdrawal |  | ✅ |  |
| `doomsday_fulfillDoesntOverRedeemMultipleActors` | fulfillRedeemRequests doesn't redeem more than requested for multiple actors |  | ✅ |  |
| `property_naivePPSDoesntChangeOnRedeem` | fulfillRedeemRequest doesn't change naive PPS |  | ✅ | ❌ |
| `property_oraclePPSDoesntChangeOnAddOrRemove` | oracle PPS doesn't change on deposit/mint/redeem/withdraw |  | ✅ |  |
| `property_naivePPSDoesntChangeOnAddOrRemove` | naive PPS (assets/shares in system) never changes on deposit/mint/redeem/withdraw  |  | ✅ |  |
| `property_maxRedeemMaxWithdrawSymmetry` | `maxRedeem` and `maxWithdraw` should always be equivalent  |  | ✅ |  |
| `property_totalSharesDontDecreaseOnRedemptionRequest` | `requestRedeem` should never reduce `SuperVault` shares  |  | ✅ |  |
| `superVault_cancelRedeem` | `pendingRedeemRequest` should be 0 after a user calls `cancelRedeem`  |  | ✅ |  |
| `superVault_cancelRedeem` | `averageRequestPPS` should be 0 after a user calls `cancelRedeem`  |  | ✅ |  |
| `superVault_cancelRedeem` | user shouldn't receive more than convertToAssets(pendingRedeemRequest) after cancelRedeem |  | ✅ |  |
| `property_shareSolvency` | `SuperVault::totalSupply` == SUM(user balances) + balanceOf(escrow)  (solvency) |  | ✅ |  |
| `property_escrowBalance` | balanceOf(escrow) >= SUM(controllers.pendingRedeemRequest) |  | ✅ |  |
| `superVaultStrategy_fulfillRedeemRequests` | redemptions only burn the requested amount of shares (exact check) |  | ✅ |  |
| `property_maxMintZeroWhenPaused` | `maxMint` should be 0 when aggregator is paused |  | ✅ |  |
| `property_maxDepositZeroWhenPaused` | `maxDeposit` should be 0 when strategy is paused |  | ✅ |  |
| `property_avgWithdrawPriceSanity` | If user's maxWithdraw == 0 then getAverageWithdrawPrice for the user is also == 0 |  | ✅ |  |
| `property_accumulatorSharesSolvency` | SUM(accumulatorShares) doesn't change on `SuperVault` share transfers |  | ✅ |  |
| `property_accumulatorCostBasisSolvency` | SUM(accumulatorCostBasis) doesn't change on `SuperVault` share transfers |  | ✅ |  |
| `superVaultStrategy_fulfillRedeemRequests` | `accumulatorShares` decreases by the exact amounts requested when fulfilling redemptions |  | ✅ |  |
| `superVaultStrategy_fulfillRedeemRequests` | `accumulatorCostBasis` decrease by the exact amounts requested when fulfilling redemptions |  | ✅ |  |
| `property_cannotClaimMoreThanRequested` | user cannot claim more assets than requested in redemption |  | ✅ |  |
| `property_x` | PPS updates with a difference that exceeds maxPPSSlippage must revert |  |  |  |
| `property_cancelDoesntChangeTotalSupply` | `cancelRedeem()` should never alter the supply of SuperVault tokens (calculated by summing user share balances) |  | ✅ |  |
| `property_assetBacking` | if `totalSupply()` > 0, then `totalAssets()` > 0  |  | ✅ |  |
| `property_x` | users shouldn't get a favorable exchange rate on loss on withdrawal in a yield vault |  |  |  |
| `property_x` | user shouldn't be able to frontrun an oracle update to get a favorable exchange when there's a loss (TODO: determine how to test this) |  |  |  |
| `property_totalAssets` | SUM(shares) * PPS == totalAssets |  | ✅ |  |
| `superVault_mint`, `superVault_deposit` | `accumulatorShares` is always accurately increased |  | ✅ |  |
| `superVault_mint`, `superVault_deposit` | `accumulatorCostBasis` is always accurately accurately increased |  | ✅ |  |
| `superVault_transfer`, `superVault_transferFrom` | `_update` should never revert |  | ✅ |  |
| `superVault_deposit` | `previewDeposit` returns the correct amounts compared to executing a deposit |  | ✅ |  |
| `superVault_mint` | `previewMint` returns the correct amounts compared to executing a redemption |  | ✅ |  |
| `doomsday_previewEquivalenceFromShares`, `doomsday_previewEquivalenceFromAssets` | `previewMint` and `previewDeposit` equivalence |  | ✅ |  |
| `property_avgPPSDoesntDecrease` | When a user requests a redemption and the PPS is >= the user PPS, user `averageRequestPPS` must not decrease |  | ✅ |  |
| `superVault_redeem` | Redeem should never revert due to underflow |  | ✅ |  |
| `doomsday_allUsersCanRedeem` | All users should always be able to redeem unless the system is paused | most likely will break if vault experiences a loss; meant to catch issues related to insufficient redemption processing | ✅ |  |
| `property_sumOfClaimable` | After all redemptions are processed, the sum of all claimable is <= balance available |  | ✅ |  |
| `property_sumOfAssetsMaxWithdrawable` | If the sum of assets in `SuperVaultStrategy` and yield strategies is 0, `maxWithdraw` should be 0 | Related to dust issue described [here](https://github.com/superform-xyz/v2-periphery/pull/43) | ✅ |  |
| `property_redemptionsNeverReverts` | When claiming redemption, it should never revert with `INVALID_REDEEM_CLAIM` (doomsday) | Related to second doomsday property outlined [here](https://github.com/Recon-Fuzz/superform-review/issues/20#issue-3405662380) | ✅ |  |
| `superVault_transfer` | Transfers of shares should transfer the exact amount of `accumulatorShares` to the recipient | Related to high risk issue outlined [here](https://github.com/Recon-Fuzz/superform-review/issues/20#issue-3405662380), potential to cause overflows? Might be useful to have an optimization test for the difference | ✅ |  |
| `superVault_transfer` | Transfers of shares should transfer the exact amount of `accumulatorCostBasis` to the recipient |  | ✅ |  |
| `property_avgPPSMonotonicity` | `averageWithdrawPrice` should never decrease when new redemptions are fulfilled at a higher PPS |  | ✅ |  |
| `property_maxWithdraw` | If maxWithdraw > 0, then `averageWithdrawPrice` > 0 |  | ✅ |  |
| `property_avgWithdrawPrice` | If maxWithdraw == 0, then `averageWithdrawPrice` == 0 |  | ✅ |  |
| `property_maxWithdraw` | `state.accumulatorShares` >= `superVaultState[controllers[i]].pendingRedeemRequest` for each user |  | ✅ |  |

## SuperVaultAggregator 
| Property | Description | Comments | Implemented | Tested |
| --- | --- | --- | --- | --- |
| `doomsday_primaryManagerAlwaysChangeable` | primary manager can always be replaced by governance via `changePrimaryManager` |  | ✅ | |


## Todo 
Property for checking accumulator ratios

Can reduction be magnified to force other person to pay 100% fee?
- compounding implicit rounding