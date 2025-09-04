# Recon Invariant Testing Suite

## Usage
This test suite uses the [Chimera Framework](https://book.getrecon.xyz/writing_invariant_tests/chimera_framework.html) to allow testing using multiple fuzzers and formal verification tools. 

## Setup
Currently the test setup deploys a single triad of `SuperVault`, `SuperVaultStrategy` and `SuperVaultEscrow`. It also deploys three yield sources using the `YieldManager` which deploys an instance of the `MockERC4626Tester`, `MockERC5115Tester` and `MockERC7540Tester`. This can be switched as the yield source targeted by the fuzzer using the `_switchYieldSource` function. 

The setup also currently defaults to setting the deposit and redeem hooks on the strategy for simplicity. Hook validation is currently bypassed by using the `UnsafeSuperVaultAggregator` which inherits from the `SuperVaultAggregator` to always return true when hooks need to be verified.

### Property Testing
This test suite uses assertion property tests defined for the system contracts in the [`Properties`](https://github.com/superform-xyz/v2-periphery/blob/recon-invariants/test/recon/Properties.sol) contract and in the function handlers in the [targets/ directory](https://github.com/superform-xyz/v2-periphery/tree/recon-invariants/test/recon/targets).  

See [this section](https://book.getrecon.xyz/extra/advanced.html) of the Recon book about techniques we use when writing properties and how we ensure full coverage.

#### Echidna Property Testing
To locally test properties using Echidna, run the following command in your terminal:
```shell
echidna . --contract CryticTester --config echidna.yaml
```

### Foundry Testing
Broken properties found when running Echidna can be turned into unit tests for easier debugging with [Recon's tools](https://getrecon.xyz/tools/echidna) and added to the `CryticToFoundry` contract.

```shell
forge test --match-test <reproducer-test-name> -vv
```

## Expanding Target Functions
See [this section](https://book.getrecon.xyz/writing_invariant_tests/sample_project.html#building-target-functions) of the Recon book on how to add additional target functions for testing. 

## Uploading Fuzz Job To Recon

You can offload your fuzzing job to Recon to run long duration jobs and share test results with collaborators using the [jobs page](https://getrecon.xyz/dashboard/jobs)

See the [Recon book](https://book.getrecon.xyz/using_recon/running_jobs.html) for more info on how to upload a job to the Recon web app. 