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
| `property_x` | estimate internal PPS on request, check if fulfillment causes this estimation to be altered |  |  |
| `property_x` | current PPS doesn't change on deposit |  |  |
| `property_x` | current PPS doesn't change on redeem |  |  |
| `property_x` | implied PPS (assets/share in system) never changes on deposit  |  |  |
| `property_x` | implied PPS (assets/share in system) never changes on redeem  |  |  |


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