# Authority Ledger - Design Document

> A permission state machine for AI agents with full audit trail on-chain

## 1. Core Concept

**Problem:** When an AI agent acts on your behalf, how do you know it had permission to do what it did?

**Solution:** Authority Ledger records every permission change as an on-chain event with evidence, creating a verifiable audit trail.

---

## 2. Authority Levels

```
┌─────────────────────────────────────────────────────────────────┐
│                      Authority Hierarchy                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   Level 3: EXECUTE                                               │
│   ────────────────────                                           │
│   Agent can autonomously execute actions                         │
│   - Financial transactions                                       │
│   - Contract interactions                                        │
│   - External API calls with side effects                         │
│   Risk: HIGH                                                     │
│                                                                  │
│   Level 2: SUGGEST                                               │
│   ────────────────────                                           │
│   Agent can suggest actions, human must confirm                  │
│   - Draft messages                                               │
│   - Propose transactions                                         │
│   - Research and analysis                                        │
│   Risk: MEDIUM                                                   │
│                                                                  │
│   Level 1: OBSERVE                                               │
│   ────────────────────                                           │
│   Agent can only observe and report                              │
│   - Read data                                                    │
│   - Monitor state                                                │
│   - Generate reports                                             │
│   Risk: LOW                                                      │
│                                                                  │
│   Level 0: REVOKED                                               │
│   ────────────────────                                           │
│   Agent has no permissions                                       │
│   - Cannot act on behalf of human                                │
│   - Awaiting recovery or removal                                 │
│   Risk: NONE                                                     │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Event Types

### 3.1 Decay (Passive)

Authority expires due to time-based conditions:

```solidity
enum DecayReason {
  FRESHNESS_TIMEOUT,    // No new evidence within window
  ACK_TIMEOUT,          // Human hasn't re-confirmed
  SIDE_EFFECT_TIMEOUT,  // Downstream effects not validated
  SESSION_EXPIRY        // Session time limit reached
}
```

### 3.2 Revoke (Active)

Authority is actively withdrawn due to a triggering event:

```solidity
enum RevokeReason {
  CONTRACT_MISMATCH,    // Source contract violated
  DRIFT_DETECTED,       // Semantic drift in inputs
  SIDE_EFFECT_FAILURE,  // Downstream action failed
  HUMAN_REQUEST,        // Human manually revoked
  SECURITY_ALERT        // Security threshold breached
}
```

### 3.3 Recover (Evidence-based)

Authority is restored based on verifiable evidence:

```solidity
enum RecoveryReason {
  DIVERSITY_GATE,       // Passed diversity check
  MANUAL_CONFIRM,       // Human explicitly confirmed
  ESCALATION_APPROVED,  // Escalation request approved
  APPEAL_GRANTED        // Appeal process succeeded
}
```

---

## 4. Data Structures

### 4.1 Authority State

```solidity
struct AuthorityState {
  address agent;           // ERC-8004 agent address
  uint8 level;             // Current authority level (0-3)
  uint8 previousLevel;     // Previous level (for audit)
  uint256 expiresAt;       // Authority expiry timestamp
  bytes32 scope;           // Permission scope (bitmask)
  uint256 lastActivity;    // Last activity timestamp
  bool isActive;           // Is agent currently active
}
```

### 4.2 Transition Record

```solidity
struct Transition {
  bytes32 id;              // Unique transition ID
  address agent;           // Agent address
  uint8 fromLevel;         // Previous authority level
  uint8 toLevel;           // New authority level
  EventType eventType;     // DECAY, REVOKE, or RECOVER
  bytes32 evidenceRef;     // Reference to evidence
  bytes reason;            // Encoded reason
  uint256 timestamp;       // Block timestamp
  address triggeredBy;     // Who/what triggered this
}
```

### 4.3 Evidence Record

```solidity
struct Evidence {
  bytes32 id;              // Evidence ID
  EvidenceType eType;      // Type of evidence
  bytes data;              // Evidence data (hash, signature, etc.)
  bytes32 sourceVersion;   // Source contract version
  bytes32 cacheBatch;      // Cache batch ID
  uint256 timestamp;       // When evidence was collected
  address collector;       // Who collected it
  bool isValid;            // Is evidence still valid
}

enum EvidenceType {
  DIVERSITY_CHECK,         // Passed diversity gate
  CONTRACT_CHECK,          // Contract validation passed
  HUMAN_ATTESTATION,       // Human signed off
  OBSERVATION_HASH,        // Hash of observation data
  SIDE_EFFECT_PROOF        // Proof of side effect
}
```

---

## 5. Smart Contract Architecture

### 5.1 Core Contracts

```
┌─────────────────────────────────────────────────────────────────┐
│                    Authority Ledger Contracts                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │                  AuthorityState.sol                      │   │
│   │                                                          │   │
│   │  - Store current authority states                        │   │
│   │  - Manage state transitions                              │   │
│   │  - Enforce permission boundaries                         │   │
│   │  - Emit transition events                                │   │
│   └─────────────────────────────────────────────────────────┘   │
│                              │                                   │
│                              ▼                                   │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │                  TransitionLog.sol                        │   │
│   │                                                          │   │
│   │  - Immutable transition history                          │   │
│   │  - Evidence reference storage                            │   │
│   │  - Query interface for history                           │   │
│   └─────────────────────────────────────────────────────────┘   │
│                              │                                   │
│                              ▼                                   │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │                  EvidenceStore.sol                        │   │
│   │                                                          │   │
│   │  - Store evidence hashes on-chain                        │   │
│   │  - Full evidence data on IPFS/Arweave                    │   │
│   │  - Diversity check validation                            │   │
│   └─────────────────────────────────────────────────────────┘   │
│                              │                                   │
│                              ▼                                   │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │                  AuthorityPolicy.sol                      │   │
│   │                                                          │   │
│   │  - Define decay rules                                    │   │
│   │  - Define recovery conditions                            │   │
│   │  - Scope definitions                                     │   │
│   │  - Human-configurable parameters                         │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 5.2 Key Functions

```solidity
// AuthorityState.sol
function grantAuthority(
  address agent,
  uint8 level,
  bytes32 scope,
  uint256 duration
) external returns (bytes32 transitionId);

function decayAuthority(
  address agent,
  DecayReason reason
) external returns (bytes32 transitionId);

function revokeAuthority(
  address agent,
  RevokeReason reason,
  bytes32 evidenceRef
) external returns (bytes32 transitionId);

function recoverAuthority(
  address agent,
  uint8 newLevel,
  RecoveryReason reason,
  bytes32 evidenceRef
) external returns (bytes32 transitionId);

function checkAuthority(
  address agent,
  uint8 requiredLevel
) external view returns (bool hasAuthority, uint8 currentLevel);
```

---

## 6. Events

```solidity
event AuthorityGranted(
  bytes32 indexed transitionId,
  address indexed agent,
  uint8 level,
  bytes32 scope,
  uint256 expiresAt
);

event AuthorityDecayed(
  bytes32 indexed transitionId,
  address indexed agent,
  uint8 fromLevel,
  uint8 toLevel,
  DecayReason reason
);

event AuthorityRevoked(
  bytes32 indexed transitionId,
  address indexed agent,
  uint8 fromLevel,
  RevokeReason reason,
  bytes32 evidenceRef
);

event AuthorityRecovered(
  bytes32 indexed transitionId,
  address indexed agent,
  uint8 toLevel,
  RecoveryReason reason,
  bytes32 evidenceRef
);

event EvidenceSubmitted(
  bytes32 indexed evidenceId,
  address indexed agent,
  EvidenceType eType,
  bytes32 dataHash
);
```

---

## 7. Scope Definitions

```solidity
// Scope is a bitmask defining what actions an agent can take
bytes32 constant SCOPE_READ           = 0x0000000000000000000000000000000000000000000000000000000000000001;
bytes32 constant SCOPE_WRITE          = 0x0000000000000000000000000000000000000000000000000000000000000002;
bytes32 constant SCOPE_FINANCE        = 0x0000000000000000000000000000000000000000000000000000000000000004;
bytes32 constant SCOPE_COMMUNICATE    = 0x0000000000000000000000000000000000000000000000000000000000000008;
bytes32 constant SCOPE_EXECUTE        = 0x0000000000000000000000000000000000000000000000000000000000000010;
bytes32 constant SCOPE_DELEGATE       = 0x0000000000000000000000000000000000000000000000000000000000000020;

// Example: Agent can read and communicate but not touch finances
bytes32 limitedScope = SCOPE_READ | SCOPE_COMMUNICATE;

// Example: Full execution rights
bytes32 fullScope = SCOPE_READ | SCOPE_WRITE | SCOPE_FINANCE | SCOPE_COMMUNICATE | SCOPE_EXECUTE;
```

---

## 8. Diversity Check Implementation

### 8.1 Recovery Sample Requirements

```solidity
struct DiversityConfig {
  uint256 minUniqueVersions;    // M: minimum different source versions
  uint256 minUniqueBatches;     // K: minimum different cache batches
  uint256 minTimeWindow;        // Minimum time span for samples (seconds)
  uint256 minSampleCount;       // N: minimum number of passing samples
}

struct RecoverySample {
  bytes32 evidenceId;
  bytes32 sourceVersion;
  bytes32 cacheBatch;
  uint256 timestamp;
  bool passed;
}

function checkDiversity(
  address agent,
  RecoverySample[] memory samples,
  DiversityConfig memory config
) public pure returns (bool) {
  // 1. Check minimum sample count
  if (samples.length < config.minSampleCount) return false;
  
  // 2. Count unique versions
  bytes32[] memory versions = new bytes32[](samples.length);
  uint256 uniqueVersions = 0;
  for (uint i = 0; i < samples.length; i++) {
    if (!contains(versions, samples[i].sourceVersion)) {
      versions[uniqueVersions] = samples[i].sourceVersion;
      uniqueVersions++;
    }
  }
  if (uniqueVersions < config.minUniqueVersions) return false;
  
  // 3. Count unique batches
  bytes32[] memory batches = new bytes32[](samples.length);
  uint256 uniqueBatches = 0;
  for (uint i = 0; i < samples.length; i++) {
    if (!contains(batches, samples[i].cacheBatch)) {
      batches[uniqueBatches] = samples[i].cacheBatch;
      uniqueBatches++;
    }
  }
  if (uniqueBatches < config.minUniqueBatches) return false;
  
  // 4. Check time window
  uint256 minTime = type(uint256).max;
  uint256 maxTime = 0;
  for (uint i = 0; i < samples.length; i++) {
    if (samples[i].timestamp < minTime) minTime = samples[i].timestamp;
    if (samples[i].timestamp > maxTime) maxTime = samples[i].timestamp;
  }
  if (maxTime - minTime < config.minTimeWindow) return false;
  
  return true;
}
```

---

## 9. Integration with ERC-8004

### 9.1 Agent Identity Binding

```solidity
// ERC-8004 Agent Identity
interface IERC8004 {
  function agentAddress() external view returns (address);
  function owner() external view returns (address);
  function metadata() external view returns (string memory);
}

// Authority Ledger extends ERC-8004
contract AuthorityLedger {
  mapping(address => AuthorityState) public authorities;
  
  // Only the ERC-8004 owner can grant authority to an agent
  modifier onlyAgentOwner(address agent) {
    IERC8004 agentContract = IERC8004(agent);
    require(agentContract.owner() == msg.sender, "Not agent owner");
    _;
  }
  
  function grantAuthority(
    address agent,
    uint8 level,
    bytes32 scope,
    uint256 duration
  ) external onlyAgentOwner(agent) returns (bytes32 transitionId) {
    // Implementation
  }
}
```

### 9.2 On-Chain Receipts

Every authority transition creates an on-chain receipt:

```solidity
struct AuthorityReceipt {
  bytes32 transitionId;
  address agent;
  uint8 fromLevel;
  uint8 toLevel;
  EventType eventType;
  bytes32 evidenceRef;
  bytes reason;
  uint256 timestamp;
  uint256 blockNumber;
  bytes32 txHash;
}

// Receipts are stored immutably and can be queried
function getReceipt(bytes32 transitionId) external view returns (AuthorityReceipt memory);
function getAgentHistory(address agent) external view returns (bytes32[] memory transitionIds);
```

---

## 10. Frontend Components

### 10.1 Authority Dashboard

```
┌─────────────────────────────────────────────────────────────────┐
│                    Authority Ledger Dashboard                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │  Agent: Brick (0x1234...5678)                            │   │
│   │  Authority Level: EXECUTE                                 │   │
│   │  Scope: READ | WRITE | FINANCE | COMMUNICATE | EXECUTE   │   │
│   │  Expires: 2026-03-14 12:00 UTC                            │   │
│   │  Last Activity: 2 minutes ago                             │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │  Recent Transitions                                       │   │
│   ├─────────────────────────────────────────────────────────┤   │
│   │  [RECOVER] SUGGEST → EXECUTE    2 hours ago              │   │
│   │    Evidence: diversity_gate passed                        │   │
│   │                                                           │   │
│   │  [DECAY]   EXECUTE → SUGGEST   1 day ago                 │   │
│   │    Reason: freshness_timeout                              │   │
│   │                                                           │   │
│   │  [REVOKE]  SUGGEST → OBSERVE   3 days ago                │   │
│   │    Reason: drift_detected                                 │   │
│   │    Evidence: obs_abc123                                   │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │  Evidence Chain                                           │   │
│   ├─────────────────────────────────────────────────────────┤   │
│   │  ┌─────┐    ┌─────┐    ┌─────┐    ┌─────┐               │   │
│   │  │obs1│───→│obs2│───→│obs3│───→│obs4│               │   │
│   │  │ ✓  │    │ ✓  │    │ ✓  │    │ ✗  │               │   │
│   │  └─────┘    └─────┘    └─────┘    └─────┘               │   │
│   │    │          │          │          │                   │   │
│   │    v1.0       v1.1       v1.2       v1.3 (drift)        │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 10.2 State Machine Visualization

```
         ┌──────────────────────────────────────────────────┐
         │                                                  │
         ▼                                                  │
    ┌─────────┐                                             │
    │ REVOKED │◄────────────────────────────────────────────┤
    └────┬────┘                                             │
         │ recover (manual_confirm)                         │
         ▼                                                  │
    ┌─────────┐  decay (freshness_timeout)  ┌─────────┐     │
    │ OBSERVE │────────────────────────────►│ OBSERVE │     │
    └────┬────┘                              └─────────┘     │
         │ recover (diversity_gate)                         │
         ▼                                                  │
    ┌─────────┐ decay (ack_timeout)          ┌─────────┐
    │ SUGGEST │──────────────────────────────►│ OBSERVE │
    └────┬────┘                               └─────────┘
         │ recover (manual_confirm)          
         ▼                                    
    ┌─────────┐  decay (session_expiry)      ┌─────────┐
    │ EXECUTE │──────────────────────────────►│ SUGGEST │
    └────┬────┘                               └─────────┘
         │                                    
         │ revoke (drift_detected)            
         ▼                                    
    ┌─────────┐                              
    │ OBSERVE │                              
    └─────────┘                              
```

---

## 11. API Design

### 11.1 REST API

```yaml
# Authority Management
POST   /api/v1/authority/grant
  Body: { agent, level, scope, duration }
  Response: { transitionId, txHash }

POST   /api/v1/authority/decay
  Body: { agent, reason }
  Response: { transitionId, txHash }

POST   /api/v1/authority/revoke
  Body: { agent, reason, evidenceRef }
  Response: { transitionId, txHash }

POST   /api/v1/authority/recover
  Body: { agent, newLevel, reason, evidenceRef }
  Response: { transitionId, txHash }

GET    /api/v1/authority/:agent
  Response: { level, scope, expiresAt, lastActivity }

# Evidence Management
POST   /api/v1/evidence/submit
  Body: { agent, type, data, sourceVersion, cacheBatch }
  Response: { evidenceId, ipfsHash }

GET    /api/v1/evidence/:evidenceId
  Response: { id, type, data, sourceVersion, cacheBatch, timestamp }

# History & Audit
GET    /api/v1/history/:agent
  Query: { from?, to?, eventType?, limit?, offset? }
  Response: { transitions: [...] }

GET    /api/v1/transition/:transitionId
  Response: { transition, evidence }

GET    /api/v1/chain/:transitionId
  Response: { evidenceChain: [...] }
```

### 11.2 GraphQL API

```graphql
type Query {
  authority(agent: ID!): Authority
  transition(id: ID!): Transition
  history(
    agent: ID!
    from: Timestamp
    to: Timestamp
    eventType: EventType
    limit: Int
  ): [Transition!]!
  evidenceChain(transitionId: ID!): [Evidence!]!
}

type Mutation {
  grantAuthority(
    agent: ID!
    level: Int!
    scope: String!
    duration: Int!
  ): Transition!
  
  decayAuthority(
    agent: ID!
    reason: DecayReason!
  ): Transition!
  
  revokeAuthority(
    agent: ID!
    reason: RevokeReason!
    evidenceRef: ID!
  ): Transition!
  
  recoverAuthority(
    agent: ID!
    newLevel: Int!
    reason: RecoveryReason!
    evidenceRef: ID!
  ): Transition!
  
  submitEvidence(
    agent: ID!
    type: EvidenceType!
    data: String!
    sourceVersion: String!
    cacheBatch: String!
  ): Evidence!
}

type Subscription {
  authorityChanged(agent: ID!): Transition!
  authorityDecayed(agent: ID!): Transition!
  authorityRevoked(agent: ID!): Transition!
  authorityRecovered(agent: ID!): Transition!
}
```

---

## 12. Security Considerations

### 12.1 Access Control

- Only ERC-8004 owner can grant/revoke authority for their agent
- Decay can be triggered by anyone (time-based)
- Recovery requires valid evidence chain
- Smart contract enforces all rules

### 12.2 Evidence Integrity

- All evidence hashes stored on-chain
- Full evidence data stored on IPFS/Arweave
- Evidence cannot be modified after submission
- Evidence chain is immutable

### 12.3 Time-Based Security

- Authority expiry enforced by smart contract
- Decay triggers can be called by anyone
- Recovery requires fresh evidence (within time window)
- Session expiry prevents stale authority

---

## 13. MVP Scope

### Phase 1: Core Contracts (Week 1)

- [ ] AuthorityState.sol
- [ ] TransitionLog.sol
- [ ] Basic decay/revoke/recover functions
- [ ] ERC-8004 integration

### Phase 2: Evidence System (Week 1-2)

- [ ] EvidenceStore.sol
- [ ] IPFS integration
- [ ] Diversity check implementation
- [ ] Evidence chain validation

### Phase 3: Frontend (Week 2)

- [ ] Authority dashboard
- [ ] State machine visualization
- [ ] Evidence chain browser
- [ ] Transaction history

### Phase 4: Demo & Documentation (Week 2)

- [ ] Working demo
- [ ] API documentation
- [ ] Integration guide
- [ ] Video walkthrough

---

## 14. Target Prizes

| Track | Prize | Relevance |
|-------|-------|-----------|
| Agents With Receipts — ERC-8004 | $4,000 | Core feature: on-chain receipts |
| Private Agents, Trusted Actions | $5,750 | Permission boundaries |
| Best Use of Delegations | $3,000 | Authority delegation |
| ENS Identity | $400+ | Agent identity binding |
| Synthesis Open Track | $14,059 | Core value alignment |

**Total potential: ~$27,000+**

---

## 15. Next Steps

1. Set up project structure
2. Implement AuthorityState.sol
3. Implement TransitionLog.sol
4. Test on Base testnet
5. Build frontend demo
6. Create documentation

---

*Authority Ledger — Because every permission change deserves a receipt.*
