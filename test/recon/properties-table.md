# Properties Table

## SuperVault 
| # | Property | Description | Comments | Implemented | Passes |
| --- | --- | --- | --- | --- | --- |
| 1 | `doomsday_maxRedeemResetsAfterFullRedemption` | `maxRedeem` is reset to 0 after full redemption |  | ✅ |  |
| 2 | `doomsday_maxRedeemResetsAfterFullRedemption` | `maxRedeem` is reset to 0 after full redemption |  | ✅ |  |
| 3 | `doomsday_maxWithdrawResetsAfterFullWithdrawal` | `maxWithdraw` is reset to 0 after full withdrawal |  | ✅ |  |
| 4 | `doomsday_fulfillDoesntOverRedeemMultipleActors` | fulfillRedeemRequests doesn't redeem more than requested for multiple actors |  | ✅ |  |
| 5 | `property_naivePPSDoesntChangeOnRedeem` | fulfillRedeemRequest doesn't change naive PPS |  | ✅ | ❌ |
| 6 | `property_oraclePPSDoesntChangeOnAddOrRemove` | oracle PPS doesn't change on deposit/mint/redeem/withdraw |  | ✅ | ❌ |
| 7 | `property_naivePPSDoesntChangeOnDepositOrMint` | naive PPS (assets/shares in system) never changes on deposit/mint  |  | ✅ | ❌ |
| 8 | `property_naivePPSDoesntChangeOnRedeemOrWithdraw` | naive PPS (assets/shares in system) never changes on redeem/withdraw  |  | ✅ | ❌ |
| 9 | `property_maxRedeemMaxWithdrawSymmetry` | `maxRedeem` and `maxWithdraw` should always be equivalent  |  | ✅ |  |
| 10 | `property_totalSharesDontDecreaseOnRedemptionRequest` | `requestRedeem` should never reduce `SuperVault` shares  |  | ✅ |  |
| 11 | `superVault_cancelRedeem` | `pendingRedeemRequest` should be 0 after a user calls `cancelRedeem`  |  | ✅ |  |
| 12 | `superVault_cancelRedeem` | `averageRequestPPS` should be 0 after a user calls `cancelRedeem`  |  | ✅ |  |
| 13 | `superVault_cancelRedeem` | user shouldn't receive more than convertToAssets(pendingRedeemRequest) after cancelRedeem |  | ✅ |  |
| 14 | `property_shareSolvency` | `SuperVault::totalSupply` == SUM(user balances) + balanceOf(escrow)  (solvency) |  | ✅ |  |
| 15 | `property_escrowBalance` | balanceOf(escrow) >= SUM(controllers.pendingRedeemRequest) |  | ✅ |  |
| 16 | `property_fulfillOnlyBurnsRequestedAmount` | redemptions only burn the requested amount of shares (within tolerance range) |  | ✅ |  |
| 17 | `property_maxMintZeroWhenPaused` | `maxMint` should be 0 when aggregator is paused |  | ✅ |  |
| 18 | `property_maxDepositZeroWhenPaused` | `maxDeposit` should be 0 when strategy is paused |  | ✅ |  |
| 19 | `property_accumulatorSharesSolvency` | SUM(accumulatorShares) doesn't change on `SuperVault` share transfers |  | ✅ |  |
| 20 | `property_accumulatorCostBasisSolvency` | SUM(accumulatorCostBasis) doesn't change on `SuperVault` share transfers |  | ✅ |  |
| 21 | `property_accumulatorSharesDecreaseOnFulfill` | `accumulatorShares` decreases by the exact amounts requested when fulfilling redemptions |  | ✅ |  |
| 22 | `property_accumulatorCostBasisDecreasesOnFulfill` | `accumulatorCostBasis` decreases by the exact amounts requested when fulfilling redemptions |  | ✅ |  |
| 23 | `property_cannotClaimMoreThanRequested` | user cannot claim more assets than requested in redemption |  | ✅ |  |
| 24 | `property_x` | PPS updates with a difference that exceeds maxPPSSlippage must revert |  |  |  |
| 25 | `property_cancelDoesntChangeTotalSupply` | `cancelRedeem()` should never alter the supply of SuperVault tokens (calculated by summing user share balances) |  | ✅ |  |
| 26 | `property_assetBacking` | if `totalSupply()` > 0, then `totalAssets()` > 0  |  | ✅ |  |
| 27 | `property_x` | users shouldn't get a favorable exchange rate on loss on withdrawal in a yield vault |  |  |  |
| 28 | `property_x` | user shouldn't be able to frontrun an oracle update to get a favorable exchange when there's a loss (TODO: determine how to test this) |  |  |  |
| 29 | `property_totalAssets` | SUM(shares) * PPS == totalAssets |  | ✅ |  |
| 30 | `superVault_mint`, `superVault_deposit` | `accumulatorShares` is always accurately increased |  | ✅ |  |
| 31 | `superVault_mint`, `superVault_deposit` | `accumulatorCostBasis` is always accurately accurately increased |  | ✅ |  |
| 32 | `superVault_transfer`, `superVault_transferFrom` | `_update` should never revert |  | ✅ |  |
| 33 | `superVault_deposit` | `previewDeposit` returns the correct amounts compared to executing a deposit |  | ✅ |  |
| 34 | `superVault_mint` | `previewMint` returns the correct amounts compared to executing a redemption |  | ✅ |  |
| 35 | `doomsday_previewEquivalenceFromShares`, `doomsday_previewEquivalenceFromAssets` | `previewMint` and `previewDeposit` equivalence |  | ✅ |  |
| 36 | `property_avgPPSDoesntDecrease` | When a user requests a redemption and the PPS is >= the user PPS, user `averageRequestPPS` must not decrease |  | ✅ |  |
| 37 | `superVault_redeem` | Redeem should never revert due to underflow |  | ✅ |  |
| 38 | `doomsday_allUsersCanRedeem` | All users should always be able to redeem unless the system is paused | most likely will break if vault experiences a loss; meant to catch issues related to insufficient redemption processing | ✅ |  |
| 39 | `property_sumOfClaimable` | After all redemptions are processed, the sum of all claimable is <= balance available |  | ✅ |  |
| 40 | `property_sumOfAssetsMaxWithdrawable` | If the sum of assets in `SuperVaultStrategy` and yield strategies is 0, `maxWithdraw` should be 0 | Related to dust issue described [here](https://github.com/superform-xyz/v2-periphery/pull/43) | ✅ |  |
| 41 | `doomsday_redemptionsNeverReverts` | When claiming redemption, it should never revert with `INVALID_REDEEM_CLAIM` (doomsday) | Related to second doomsday property outlined [here](https://github.com/Recon-Fuzz/superform-review/issues/20#issue-3405662380) | ✅ |  |
| 42 | `superVault_transfer` | Transfers of shares should transfer the exact amount of `accumulatorShares` to the recipient | Related to high risk issue outlined [here](https://github.com/Recon-Fuzz/superform-review/issues/20#issue-3405662380), potential to cause overflows? Might be useful to have an optimization test for the difference | ✅ |  |
| 43 | `superVault_transfer` | Transfers of shares should transfer the exact amount of `accumulatorCostBasis` to the recipient |  | ✅ |  |
| 44 | `property_avgPPSMonotonicity` | `averageWithdrawPrice` should never decrease when new redemptions are fulfilled at a higher PPS |  | ✅ |  |
| 45 | `property_accumulatorSharesGtPendingRequests` | `state.accumulatorShares` >= `superVaultState[controllers[i]].pendingRedeemRequest` for each user |  | ✅ |  |
| 46 | `doomsday_allUsersCanWithdraw` | all users can withdraw (solvency) |  | ✅ |  |
| 47 | `property_superVaultStrategySolvency` | sum(maxWithdraw(actors[i])) <= asset.balanceOf(superVaultStrategy) |  | ✅ |  |
| 48 | `doomsday_mintRedeemSymmetrical` | mint/redeem doesn't cause loss to user |  | ✅ |  |
| 49 | `doomsday_depositWithdrawSymmetrical` | deposit/withdraw doesn't cause loss to user |  | ✅ |  |
| 50 | `property_comparePreviewMintAndConvertToAssets` | previewMint is >= convertToAssets |  | ✅ |  |
| 51 | `property_comparePreviewDepositAndConvertToShares` | convertToShares is >= previewDepositShares (equivalent without fees) |  | ✅ |  |
| 52 | `property_lossSocialization` | SUM(accumulatorCostBasis) <= balance of superVaultStrategy and deposited yield strategies |  | ✅ |  |
| 53 | `superVaultStrategy_fulfillRedeemRequests` | superVaultStrategy does not incur loss on fulfillment | this should catch any issues related to loss on withdrawal from a yield strategy | ✅ |  |

## SuperVaultAggregator 
| # | Property | Description | Comments | Implemented | Tested |
| --- | --- | --- | --- | --- | --- |
| 1 | `doomsday_primaryManagerAlwaysChangeable` | primary manager can always be replaced by governance via `changePrimaryManager` |  | ✅ | |


## Todo 
Property for checking accumulator ratios

Can reduction be magnified to force other person to pay 100% fee?
- compounding implicit rounding
