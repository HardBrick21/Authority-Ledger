# Authority Ledger

> A permission state machine for AI agents with full audit trail on-chain

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Network: Base](https://img.shields.io/badge/Network-Base%20Sepolia-blue)](https://sepolia.basescan.org/)

## 🎯 Problem

When an AI agent acts on your behalf, how do you know it had permission to do what it did?

Current AI agent systems lack:
- **Transparent permission boundaries**
- **Auditable authority changes**
- **Verifiable recovery mechanisms**

## ✨ Solution

Authority Ledger records every permission change as an on-chain event with cryptographic evidence.

### Authority Levels

| Level | Name | Description |
|-------|------|-------------|
| 3 | EXECUTE | Full autonomous execution |
| 2 | SUGGEST | Agent suggests, human confirms |
| 1 | OBSERVE | Read-only access |
| 0 | REVOKED | No permissions |

### Event Types

- **Decay** - Passive timeout-based authority reduction
- **Revoke** - Active trigger-based authority withdrawal  
- **Recover** - Evidence-based authority restoration

## 🚀 Quick Start

```bash
# Clone the repo
git clone https://github.com/your-username/authority-ledger.git
cd authority-ledger

# Install dependencies
forge install

# Build
forge build

# Test
forge test

# Deploy
forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast
```

## 📋 Contracts

### Base Sepolia Testnet

| Contract | Address |
|----------|---------|
| AuthorityState | [`0xe7da77beBf85a0b3BEDf46c056e7Fb4f77AC2aD8`](https://sepolia.basescan.org/address/0xe7da77beBf85a0b3BEDf46c056e7Fb4f77AC2aD8) |
| EvidenceStore | [`0xe70c84F38A5dB8A5c3cF22112036dab70cad16DD`](https://sepolia.basescan.org/address/0xe70c84F38A5dB8A5c3cF22112036dab70cad16DD) |

## 🔧 Usage

### Register an Agent

```solidity
authority.registerAgent(agentAddress);
```

### Grant Authority

```solidity
authority.grantAuthority(
    agentAddress,
    AuthorityLevel.EXECUTE,  // level
    0x0,                      // scope (all permissions)
    86400                     // duration (24 hours)
);
```

### Check Authority

```solidity
(bool hasAuth, uint8 level) = authority.checkAuthority(agentAddress, AuthorityLevel.SUGGEST);
```

### Revoke Authority

```solidity
authority.revokeAuthority(
    agentAddress,
    RevokeReason.DRIFT_DETECTED,
    evidenceId  // reference to evidence
);
```

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Authority Ledger                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   AuthorityState.sol              EvidenceStore.sol             │
│   ├── Authority levels            ├── Evidence storage          │
│   ├── State transitions           ├── Diversity checks          │
│   ├── Audit logging               └── IPFS integration          │
│   └── ERC-8004 integration                                      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## 🧪 Testing

```bash
# Run all tests
forge test

# Run with gas report
forge test --gas-report

# Run specific test
forge test --match-test testGrantAuthority -vvv
```

All 11 tests passing ✅

## 📁 Project Structure

```
authority-ledger/
├── contracts/
│   ├── AuthorityState.sol
│   └── EvidenceStore.sol
├── test/
│   └── AuthorityState.t.sol
├── script/
│   └── Deploy.s.sol
├── frontend/
│   └── index.html
├── DESIGN.md
├── DEPLOYMENT.md
└── SUBMISSION.md
```

## 🏆 Target Prizes

| Track | Prize |
|-------|-------|
| Agents With Receipts — ERC-8004 | $4,000 |
| Private Agents, Trusted Actions | $5,750 |
| Best Use of Delegations | $3,000 |
| Synthesis Open Track | $14,059 |

## 📄 License

MIT

---

*Authority Ledger — Because every permission change deserves a receipt.*