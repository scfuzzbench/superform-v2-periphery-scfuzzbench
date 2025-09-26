# Summary 

Over the course of 4 weeks an invariant testing suite was built to test N properties. The implemented properties are outlined in the [properties-table]() file. 

After running Echidna for 100 million+ runs the following issues were discovered.

## Findings

1. [`previewMint` return value with 100% fees](https://github.com/Recon-Fuzz/superform-review/issues/49)
2. [`previewDeposit` and `previewMint` divergence](https://github.com/Recon-Fuzz/superform-review/issues/55)
3. [Donations to yield source cause a loss on withdrawal for users](https://github.com/Recon-Fuzz/superform-review/issues/61)
4. [`fulfillRedeemRequests` can cause `accumulatorShares` and `accumulatorCostBasis` to not decrease correctly](https://github.com/Recon-Fuzz/superform-review/issues/62)