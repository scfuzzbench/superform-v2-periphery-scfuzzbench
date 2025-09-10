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
| `property_naivePPSDoesntChangeOnRedeem` | fulfillRedeemRequest doesn't change naive PPS | ✅ |  |
| `property_oraclePPSDoesntChangeOnAddOrRemove` | oracle PPS doesn't change on deposit/mint/redeem/withdraw | ✅ |  |
| `property_naivePPSDoesntChangeOnAddOrRemove` | naive PPS (assets/shares in system) never changes on deposit/mint/redeem/withdraw  | ✅ |  |
| `property_maxRedeemMaxWithdrawSymmetry` | `maxRedeem` and `maxWithdraw` should always be equivalent  | ✅ |  |
| `property_x` | PPS always > 0  |  |  |
| `property_x` | `requestRedeem` should never reduce `totalSupply` of `SuperVault` shares  |  |  |
| `property_x` | `pendingRedeemRequest` should be 0 after a user calls `cancelRedeem`  |  |  |
| `property_x` | `averageRequestPPS` should be 0 after a user calls `cancelRedeem`  |  |  |
| `property_x` | user shouldn't receive more than `pendingRedeemRequest` after `cancelRedeem`  |  |  |
| `property_x` | `SuperVault::totalSupply` equals the sum of all user balances (solvency) |  |  |
| `property_x` | PPS == PRECISION when totalSupply == 0 |  |  |
| `property_x` | balanceOf(escrow) >= SUM(controllers.pendingRedeemRequest) |  |  |
| `property_x` | redemptions only burn the requested amount of shares (exact check) |  |  |




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