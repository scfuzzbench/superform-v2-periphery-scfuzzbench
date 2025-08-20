Got it — here’s a clean, **4-message** plan (4 commits in one PR) that fixes **#1, #10, #15, #45**.
They’re ordered to minimize blast radius and keep each commit reviewable. Each block below is a copy-pasteable prompt for your code LLM, plus the exact commit message.

Quick rationale for the order:

1. **#1 (critical)**: stop state cloning on transfer immediately.
2. **#10 (high)**: align deposit accounting with minted receiver.
3. **#15 (medium)**: enforce `owner == controller` on redeem (auditor’s remedy) so fulfillment won’t subtract the “wrong” accumulator.
4. **#45 (high)**: fix cancel flow so users aren’t bricked.

---

# Message 1/4 — Fix **#1**: stop state overwrite/clone on share transfer

**Goal:** Prevent copying the entire `SuperVaultState` during ERC-20 share transfers. Move **only** accumulators **pro-rata**; never touch request/claim state.

**Make these edits:**

**A) In `SuperVault` (ERC-20 shares), in `_update(from, to, value)`**
Replace the state copy with a strategy call that moves *only* accumulators:

```diff
function _update(address from, address to, uint256 value) internal override {
    if (from != address(0) && to != address(0)) {
-       ISuperVaultStrategy.SuperVaultState memory state = strategy.getSuperVaultState(from);
-       strategy.updateSuperVaultState(to, state);
+       uint256 shares = value;
+       // Zero-value transfers are legal: treat as accounting no-op.
+       if (shares > 0) {
+           strategy.moveAccumulatorOnTransfer(from, to, shares);
+       }
    }
    super._update(from, to, value);
}
```

**B) In `SuperVaultStrategy` add:**

```solidity
function moveAccumulatorOnTransfer(address from, address to, uint256 shares) external {
    _requireVault();
    if (shares == 0) return;

    SuperVaultState storage fromState = superVaultState[from];
    SuperVaultState storage toState   = superVaultState[to];

    if (shares > fromState.accumulatorShares) revert INSUFFICIENT_SHARES();

    // Pro-rata move of cost basis (NO PPS here; preserves fee correctness)
    uint256 movedCostBasis = shares * fromState.accumulatorCostBasis / fromState.accumulatorShares;

    fromState.accumulatorShares    -= shares;
    fromState.accumulatorCostBasis -= movedCostBasis;

    toState.accumulatorShares      += shares;
    toState.accumulatorCostBasis   += movedCostBasis;

    // Never touch: pendingRedeemRequest, averageRequestPPS, maxWithdraw, averageWithdrawPrice
}
```

**Tests to add/update:**

* Transfer does **not** change `pendingRedeemRequest`, `maxWithdraw`, `averageRequestPPS`, `averageWithdrawPrice`.
* Transfer moves `accumulatorShares`/`accumulatorCostBasis` pro-rata; total basis conserved (±1 wei dust).
* Attack scenarios in audit #1 fail (no clone/overwrite of claimable).
* Zero-value transfer is a no-op.

**Commit message:**

```
fix(#1): prevent state overwrite on transfer; move accumulators pro-rata only
- Remove full-state copy in _update
- Add moveAccumulatorOnTransfer() to strategy
- Keep request/claim state immutable across transfers
- Tests for clone/overwrite prevention and rounding invariants
```

---

# Message 2/4 — Fix **#10**: deposit accounting must follow the minted receiver

**Goal:** When depositing, the **receiver** of ERC-20 shares must also receive the corresponding **accumulator** (shares & cost basis). Avoid the mismatch where controller pays assets but receiver can’t redeem.

**Make these edits:**

**A) In `SuperVault` deposit/mint flow** (where you currently do):

```solidity
strategy.handleOperation(msg.sender, receiver, assets, shares, ISuperVaultStrategy.Operation.Deposit);
_mint(receiver, shares);
```

Change to:

```diff
- strategy.handleOperation(msg.sender, receiver, assets, shares, ISuperVaultStrategy.Operation.Deposit);
+ strategy.handleOperation(receiver, receiver, assets, shares, ISuperVaultStrategy.Operation.Deposit);
_mint(receiver, shares);
```

(Using the current signature `(controller, receiver, assets, shares, op)`: make **controller = receiver** for deposits.)

**B) In `SuperVaultStrategy._handleDeposit`** verify it keys by the first arg (controller), which now equals `receiver`:

```solidity
// already present:
state.accumulatorShares += shares;
state.accumulatorCostBasis += assets;
```

**Tests:**

* After deposit with `receiver != msg.sender`, `superVaultState[receiver].accumulatorShares` and `accumulatorCostBasis` reflect the deposit.
* Subsequent transfer still uses pro-rata move from Message 1.

**Commit message:**

```
fix(#10): attribute deposit accumulators to the minted receiver
- Pass (receiver, receiver, assets, shares) to strategy on deposit
- Ensure receiver’s accumulator updated; avoids controller/receiver mismatch
- Tests for receiver-based accounting
```

---

# Message 3/4 — Fix **#15**: enforce `owner == controller` when redeeming

**Goal:** Avoid fulfillment subtracting from a controller that has no accumulator by **enforcing** the auditor’s invariant: on redeem **the `controller` must equal the `owner`** whose shares were escrowed. (This is a tactical fix consistent with your current data model; it prevents the original revert pattern without a larger spec refactor.)

**Make these edits:**

**A) In `SuperVault.requestRedeem(uint256 shares, address controller, address owner)`** add the check and forward only the (now equal) address to strategy:

```diff
function requestRedeem(uint256 shares, address controller, address owner) external returns (uint256) {
    if (shares == 0) revert ZERO_AMOUNT();
    if (owner == address(0) || controller == address(0)) revert ZERO_ADDRESS();
    if (owner != msg.sender && !isOperator[owner][msg.sender]) revert INVALID_OWNER_OR_OPERATOR();
    if (balanceOf(owner) < shares) revert INVALID_AMOUNT();

+   // Enforce auditor's invariant for current accounting model
+   if (controller != owner) revert CONTROLLER_MUST_EQUAL_OWNER();

    // Transfer shares to escrow for temporary locking
    _approve(owner, escrow, shares);
    ISuperVaultEscrow(escrow).escrowShares(owner, shares);

    // Forward to strategy
-   strategy.handleOperation(controller, address(0), 0, shares, ISuperVaultStrategy.Operation.RedeemRequest);
+   strategy.handleOperation(controller, address(0), 0, shares, ISuperVaultStrategy.Operation.RedeemRequest);

    emit RedeemRequest(controller, owner, REQUEST_ID, msg.sender, shares);
    return REQUEST_ID;
}
```

*(No change needed in the strategy for this commit, because its fulfillment already uses the `controller`-keyed accumulator. The constraint above guarantees the right bucket is debited.)*

**B) (Optional defense-in-depth)** In `SuperVaultStrategy._handleRequestRedeem`, assert non-zero accumulator on the `controller`:

```solidity
if (superVaultState[controller].accumulatorShares == 0) revert INSUFFICIENT_SHARES();
```

**Tests:**

* Redeem with `controller != owner` reverts with `CONTROLLER_MUST_EQUAL_OWNER()`.
* Redeem with `controller == owner` succeeds; fulfillment no longer hits `INSUFFICIENT_SHARES()` due to mismatched bucket.

**Commit message:**

```
fix(#15): enforce owner==controller on redeem to match controller-keyed accounting
- Add CONTROLLER_MUST_EQUAL_OWNER() check in requestRedeem
- Optional strategy assert that controller has accumulator shares
- Tests covering mismatch revert and happy path
```

---

# Message 4/4 — Fix **#45**: cancel must not wipe accumulators / brick future redeems

**Goal:** Cancelling a pending request should clear **only the pending fields**, not the whole `superVaultState[controller]`. Keep accumulators and any existing claimable intact.

**Make these edits:**

**A) In `SuperVaultStrategy._handleCancelRedeem(address controller)`**
Replace the struct deletion with targeted resets:

```diff
function _handleCancelRedeem(address controller) private {
    if (controller == address(0)) revert ZERO_ADDRESS();
    SuperVaultState storage state = superVaultState[controller];
    uint256 pendingShares = state.pendingRedeemRequest;
    if (pendingShares == 0) revert REQUEST_NOT_FOUND();
-   delete superVaultState[controller];
+   // Only clear pending request metadata
+   state.pendingRedeemRequest = 0;
+   state.averageRequestPPS = 0;

    emit RedeemRequestCanceled(controller, pendingShares);
}
```

**B) Double-check fulfillment code paths** don’t assume the struct was ever deleted. (Your current `_processRedeemFulfillments` already reads/updates specific fields; no change needed.)

**Tests:**

* Cancel → re-request → fulfill works (no permanent lockout; no `INSUFFICIENT_SHARES()` due to wiped accumulators).
* `maxWithdraw` and `averageWithdrawPrice` remain unchanged by cancel.
* Accumulators remain unchanged by cancel.

**Commit message:**

```
fix(#45): safe cancel — clear pending fields only; preserve accumulators and claimable
- Replace delete(superVaultState[controller]) with targeted resets
- Tests for cancel→re-request→fulfill, and invariants on accumulators/claimable
```

---

## Synergies / Notes

* **#1 and #10** together ensure the right address holds both shares and cost basis, and transfers preserve fee correctness.
* **#15** then locks down the redeem flow under the current controller-keyed accounting, preventing the mismatch that caused fulfillment to subtract from an empty bucket.
* **#45** ensures user cancellations don’t nuke long-lived state.

> If you later decide to **decouple** “owner (accumulators)” from “controller (requests/claims)” for full ERC-7540 flexibility, do it in a dedicated follow-up PR: introduce `accumByOwner` vs `ctrl[controller]` maps and pass `owner` through `handleOperation` on redeem. The four fixes above keep this PR focused and auditable per issue.

Good to go.

## Progress Update

✅ **Message 1/4 — Fix #1: stop state overwrite/clone on share transfer** — COMPLETED
- Added `moveAccumulatorOnTransfer` function to `ISuperVaultStrategy` interface
- Implemented `moveAccumulatorOnTransfer` in `SuperVaultStrategy` that moves only accumulators pro-rata
- Updated `SuperVault._update` to call new function instead of copying entire state
- Added comprehensive tests covering transfer behavior, pro-rata movement, zero transfers, and audit attack scenario
- All tests passing ✅

✅ **Message 2/4 — Fix #10: deposit accounting must follow the minted receiver** — COMPLETED
- Updated `SuperVault.deposit()` to pass `(receiver, receiver, assets, shares)` to strategy instead of `(msg.sender, receiver, assets, shares)`
- Updated `SuperVault.mint()` to pass `(receiver, receiver, assets, shares)` to strategy instead of `(msg.sender, receiver, assets, shares)`
- Verified `SuperVaultStrategy._handleDeposit` correctly keys accumulator by controller (first parameter)
- Added comprehensive tests verifying receiver gets accumulator shares/cost basis, not sender
- Added test verifying receiver can successfully redeem after receiving deposit from another user
- All tests passing ✅

✅ **Message 3/4 — Fix #15: enforce owner==controller on redeem to match controller-keyed accounting** — COMPLETED
- Added `CONTROLLER_MUST_EQUAL_OWNER()` error to `ISuperVault` interface
- Added controller != owner validation check in `SuperVault.requestRedeem()` that reverts with `CONTROLLER_MUST_EQUAL_OWNER()`
- Added defense-in-depth check in `SuperVaultStrategy._handleRequestRedeem()` that asserts controller has accumulator shares
- Added comprehensive tests covering controller/owner mismatch revert, happy path success, fulfillment correctness, and defense-in-depth scenario
- All tests passing ✅
