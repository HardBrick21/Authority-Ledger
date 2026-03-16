# Authority Ledger - Demo Script

## 30-Second Pitch

"Authority Ledger is an on-chain permission state machine for AI agents. Every time an agent's authority changes—whether it gains, loses, or recovers permissions—that change is recorded on-chain with cryptographic evidence. This creates a verifiable audit trail that answers the question: 'Did this agent have permission to do what it did?'"

---

## Demo Walkthrough (2-3 minutes)

### Step 1: Connect Wallet
1. Open `frontend/index.html` in Chrome/Firefox with MetaMask
2. Ensure MetaMask is on Base Sepolia testnet
3. Click "Connect Wallet"
4. Approve the connection

### Step 2: Register an Agent
1. Enter an agent address (e.g., your second wallet)
2. Click "Register"
3. Confirm transaction in MetaMask
4. Agent is now registered with OBSERVE level

### Step 3: Grant Authority
1. Enter the same agent address
2. Select "EXECUTE" level
3. Set duration to 3600 seconds (1 hour)
4. Click "Grant"
5. Confirm transaction
6. Agent now has full execution rights

### Step 4: Check Authority
1. Enter the agent address
2. Click "Check"
3. See current level: EXECUTE
4. See expiry time

### Step 5: Revoke Authority
1. Enter the agent address
2. Select "Drift Detected" as reason
3. Click "Revoke"
4. Confirm transaction
5. Authority drops to OBSERVE

### Step 6: Verify on Block Explorer
1. Open https://sepolia.basescan.org/address/0xe7da77beBf85a0b3BEDf46c056e7Fb4f77AC2aD8
2. Click "Events" tab
3. See AuthorityGranted, AuthorityRevoked events
4. Each event has transitionId, agent, level, timestamp

---

## Key Points to Emphasize

1. **Every transition is on-chain** - No hidden state changes
2. **Evidence-based recovery** - Can't just "click to restore"
3. **Diversity checks** - Prevents false recovery from same batch
4. **Human stays in control** - Only owner can grant/recover authority

---

## Questions Judges Might Ask

**Q: How does this integrate with existing AI agents?**
A: Agents call `checkAuthority()` before executing privileged actions. If level < required, they escalate or abort.

**Q: What prevents unauthorized authority changes?**
A: Only the ERC-8004 owner can grant/recover authority. Decay is time-based and automatic.

**Q: How does diversity check work?**
A: Recovery requires N samples spanning M versions, K batches, and minimum time window. This prevents "same batch" false positives.

**Q: What's the gas cost?**
A: ~117k gas for registration, ~360k for grant, ~204k for revoke. At 0.01 gwei, that's fractions of a cent.

---

## Closing Statement

"Authority Ledger brings transparency and accountability to AI agent permissions. Every permission change has a receipt on-chain. This is infrastructure that lets humans trust their agents—and verify that trust when it matters."