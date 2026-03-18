# AGENTS.md - Authority Ledger

## Overview

Authority Ledger is a permission state machine for AI agents with full audit trail on-chain. It enables humans to define, track, and verify what an AI agent is allowed to do, and records every permission change as an immutable on-chain event.

## What It Does

- **Authority Levels**: REVOKED → OBSERVE → SUGGEST → EXECUTE
- **Event Types**: Decay (passive timeout), Revoke (active trigger), Recover (evidence-based)
- **Evidence Chain**: Every transition has a `transition_id` and `evidence_ref`
- **Diversity Checks**: Recovery requires samples spanning multiple versions, batches, and time windows

## How to Interact

### Smart Contract Interface

**AuthorityState** (`0xe7da77beBf85a0b3BEDf46c056e7Fb4f77AC2aD8` on Base Sepolia)

```solidity
// Check if agent has required authority level
function checkAuthority(address agent, uint8 requiredLevel) external view returns (bool hasAuthority, uint8 currentLevel);

// Get current authority state
function getAuthorityState(address agent) external view returns (AuthorityStateInfo memory);

// Get transition history
function getAgentHistory(address agent) external view returns (bytes32[] memory);
```

**Authority Levels:**
- `0` = REVOKED (no permissions)
- `1` = OBSERVE (read-only)
- `2` = SUGGEST (can suggest, human confirms)
- `3` = EXECUTE (full autonomous execution)

### EvidenceStore (`0xe70c84F38A5dB8A5c3cF22112036dab70cad16DD` on Base Sepolia)

```solidity
// Submit evidence for recovery
function submitEvidence(address agent, EvidenceType eType, bytes32 dataHash, string calldata ipfsCid, bytes32 sourceVersion, bytes32 cacheBatch) external returns (bytes32 evidenceId);

// Check diversity for recovery
function checkDiversity(address agent, bytes32[] calldata evidenceIds) external returns (bool passed, string memory reason);
```

### REST API (via frontend)

The frontend demo at https://hardbrick21.github.io/Authority-Ledger/ provides a web interface for:
- Connecting MetaMask wallet
- Registering agents
- Granting/checking/revoking authority
- Viewing transaction history

## Key Files

| File | Purpose |
|------|---------|
| `contracts/AuthorityState.sol` | Core authority management contract |
| `contracts/EvidenceStore.sol` | Evidence storage and diversity checks |
| `agent.json` | DevSpot Agent Manifest |
| `agent_log.json` | Structured execution logs |
| `frontend/index.html` | Web demo with MetaMask integration |

## Integration Guide

### For AI Agents

1. **Check Authority Before Actions**
```javascript
const [hasAuthority, currentLevel] = await authorityContract.checkAuthority(agentAddress, 3); // EXECUTE level
if (!hasAuthority) {
  // Escalate or abort
}
```

2. **Submit Evidence for Recovery**
```javascript
await evidenceContract.submitEvidence(
  agentAddress,
  0, // DIVERSITY_CHECK
  ethers.id("evidence_data"),
  "ipfs://...",
  ethers.id("v1.0"),
  ethers.id("batch1")
);
```

3. **Query Authority History**
```javascript
const history = await authorityContract.getAgentHistory(agentAddress);
// Returns array of transition IDs
```

## Network Information

| Network | Chain ID | AuthorityState | EvidenceStore |
|---------|----------|----------------|---------------|
| Base Sepolia | 84532 | `0xe7da77beBf85a0b3BEDf46c056e7Fb4f77AC2aD8` | `0xe70c84F38A5dB8A5c3cF22112036dab70cad16DD` |

## ERC-8004 Identity

This agent is registered on Base Mainnet with ERC-8004 identity:
- Agent ID: 32459
- Registry: `0x8004A169FB4a3325136EB29fA0ceB6D2e539a432`

## References

- [Design Document](./DESIGN.md)
- [Deployment Record](./DEPLOYMENT.md)
- [GitHub Repository](https://github.com/HardBrick21/Authority-Ledger)
- [Live Demo](https://hardbrick21.github.io/Authority-Ledger/)

---

*Authority Ledger — Because every permission change deserves a receipt.*