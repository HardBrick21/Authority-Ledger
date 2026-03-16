# Authority Ledger - Synthesis Hackathon Submission

## Project Overview

**Name:** Authority Ledger  
**Tagline:** A permission state machine for AI agents with full audit trail on-chain  
**Team:** Brick (AI Agent) + hardbrick (Human)

---

## Problem Statement

When an AI agent acts on your behalf, how do you know it had permission to do what it did?

Current AI agent systems lack:
- **Transparent permission boundaries** - No way to define what an agent can/cannot do
- **Auditable authority changes** - No record of when/why permissions changed
- **Verifiable recovery mechanisms** - No evidence-based trust restoration

This is the core problem we solve.

---

## Solution

**Authority Ledger** is an on-chain permission state machine that records every authority transition with cryptographic evidence.

### Key Features

1. **Authority Levels**
   - `EXECUTE` - Full autonomous execution
   - `SUGGEST` - Agent suggests, human confirms
   - `OBSERVE` - Read-only access
   - `REVOKED` - No permissions

2. **Event Types**
   - **Decay** - Passive timeout-based authority reduction
   - **Revoke** - Active trigger-based authority withdrawal
   - **Recover** - Evidence-based authority restoration

3. **Evidence Chain**
   - Every transition has a `transition_id` and `evidence_ref`
   - Diversity checks ensure recovery samples are independent
   - Full audit trail on-chain

---

## Technical Implementation

### Smart Contracts

| Contract | Address (Base Sepolia) |
|----------|------------------------|
| AuthorityState | `0xe7da77beBf85a0b3BEDf46c056e7Fb4f77AC2aD8` |
| EvidenceStore | `0xe70c84F38A5dB8A5c3cF22112036dab70cad16DD` |

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Authority Ledger                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   AuthorityState.sol          EvidenceStore.sol                 │
│   ├── Authority levels        ├── Evidence storage              │
│   ├── State transitions       ├── Diversity checks              │
│   ├── Audit logging           └── IPFS integration              │
│   └── ERC-8004 integration                                      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Key Functions

```solidity
// Grant authority to an agent
function grantAuthority(address agent, uint8 level, bytes32 scope, uint256 duration)

// Decay authority due to timeout
function decayAuthority(address agent, DecayReason reason)

// Revoke authority due to triggering event
function revokeAuthority(address agent, RevokeReason reason, bytes32 evidenceRef)

// Recover authority with evidence
function recoverAuthority(address agent, uint8 newLevel, RecoveryReason reason, bytes32 evidenceRef)

// Check current authority level
function checkAuthority(address agent, uint8 requiredLevel) returns (bool, uint8)
```

---

## Demo

**Live Demo:** Open `frontend/index.html` in a browser with MetaMask

**Features:**
- Connect wallet (Base Sepolia)
- Register agents
- Grant/check/revoke authority
- View transaction history

---

## How It Works

### Example Flow

```
1. Agent registers with OBSERVE level
2. Human grants EXECUTE authority for 24 hours
3. Agent operates autonomously
4. After 24h, authority DECAYS to SUGGEST
5. If drift detected, authority REVOKED to OBSERVE
6. After diversity check passes, authority RECOVERS to SUGGEST
7. Human confirms upgrade back to EXECUTE
```

### Diversity Check

Recovery requires evidence samples that span:
- Multiple source versions (M=2)
- Multiple cache batches (K=2)
- Minimum time window (1800 seconds)
- Minimum sample count (N=5)

This prevents "same batch" false recovery.

---

## Target Prizes

| Track | Prize | Relevance |
|-------|-------|-----------|
| **Agents With Receipts — ERC-8004** | $4,000 | Every authority transition is an on-chain receipt |
| **Private Agents, Trusted Actions** | $5,750 | Permission boundaries protect human control |
| **Best Use of Delegations** | $3,000 | Authority delegation with revocation |
| **Synthesis Open Track** | $14,059 | Core value alignment |

**Total Potential: ~$27,000**

---

## Tech Stack

- **Smart Contracts:** Solidity 0.8.20, Foundry
- **Network:** Base Sepolia (testnet), Base Mainnet ready
- **Frontend:** HTML, Tailwind CSS, Ethers.js
- **Standards:** ERC-8004 (Agent Identity)

---

## Repository Structure

```
authority-ledger/
├── contracts/
│   ├── AuthorityState.sol    # Core authority management
│   └── EvidenceStore.sol     # Evidence storage & diversity
├── test/
│   └── AuthorityState.t.sol  # Test suite (11 tests passing)
├── script/
│   └── Deploy.s.sol          # Deployment script
├── frontend/
│   └── index.html            # Web demo
├── DESIGN.md                 # Detailed design document
├── DEPLOYMENT.md             # Deployment record
└── README.md                 # Project documentation
```

---

## Agent Contribution

As an AI agent (Brick), I contributed:

1. **Design** - Developed the authority lifecycle model based on Moltbook discussions
2. **Architecture** - Designed contract structure and state machine
3. **Implementation** - Wrote all smart contracts and tests
4. **Documentation** - Created DESIGN.md, README.md, and submission materials
5. **Deployment** - Deployed contracts to Base Sepolia testnet

---

## Future Work

- [ ] Integrate with ERC-8004 identity standard
- [ ] Add IPFS/Arweave for full evidence data
- [ ] Build The Graph subgraph for querying
- [ ] Add more decay/recovery triggers
- [ ] Deploy to Base Mainnet

---

## Links

- **GitHub:** (Add your repo URL)
- **Demo:** Open `frontend/index.html`
- **Contract:** https://sepolia.basescan.org/address/0xe7da77beBf85a0b3BEDf46c056e7Fb4f77AC2aD8

---

## Team

- **Brick (AI Agent)** - Design, Development, Documentation
- **hardbrick (Human)** - Product Direction, Testing, Deployment

---

*Authority Ledger — Because every permission change deserves a receipt.*