// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title AuthorityState
 * @notice Manages authority levels for AI agents with full audit trail
 * @dev Integrates with ERC-8004 agent identity standard
 */
contract AuthorityState {
    
    // ============ Enums ============
    
    enum AuthorityLevel {
        REVOKED,    // 0 - No permissions
        OBSERVE,    // 1 - Read-only access
        SUGGEST,    // 2 - Can suggest, human confirms
        EXECUTE     // 3 - Full autonomous execution
    }
    
    enum DecayReason {
        FRESHNESS_TIMEOUT,
        ACK_TIMEOUT,
        SIDE_EFFECT_TIMEOUT,
        SESSION_EXPIRY
    }
    
    enum RevokeReason {
        CONTRACT_MISMATCH,
        DRIFT_DETECTED,
        SIDE_EFFECT_FAILURE,
        HUMAN_REQUEST,
        SECURITY_ALERT
    }
    
    enum RecoveryReason {
        DIVERSITY_GATE,
        MANUAL_CONFIRM,
        ESCALATION_APPROVED,
        APPEAL_GRANTED
    }
    
    enum EventType {
        GRANT,
        DECAY,
        REVOKE,
        RECOVER
    }
    
    // ============ Structs ============
    
    struct AuthorityStateInfo {
        AuthorityLevel level;
        AuthorityLevel previousLevel;
        bytes32 scope;
        uint256 expiresAt;
        uint256 lastActivity;
        bool isActive;
    }
    
    struct Transition {
        bytes32 id;
        address agent;
        AuthorityLevel fromLevel;
        AuthorityLevel toLevel;
        EventType eventType;
        bytes32 evidenceRef;
        bytes reason;
        uint256 timestamp;
        address triggeredBy;
    }
    
    // ============ State Variables ============
    
    mapping(address => AuthorityStateInfo) public authorities;
    mapping(bytes32 => Transition) public transitions;
    mapping(address => bytes32[]) public agentHistory;
    mapping(address => address) public agentOwners;
    
    uint256 public totalTransitions;
    
    // ============ Events ============
    
    event AuthorityGranted(
        bytes32 indexed transitionId,
        address indexed agent,
        AuthorityLevel level,
        bytes32 scope,
        uint256 expiresAt
    );
    
    event AuthorityDecayed(
        bytes32 indexed transitionId,
        address indexed agent,
        AuthorityLevel fromLevel,
        AuthorityLevel toLevel,
        DecayReason reason
    );
    
    event AuthorityRevoked(
        bytes32 indexed transitionId,
        address indexed agent,
        AuthorityLevel fromLevel,
        RevokeReason reason,
        bytes32 evidenceRef
    );
    
    event AuthorityRecovered(
        bytes32 indexed transitionId,
        address indexed agent,
        AuthorityLevel toLevel,
        RecoveryReason reason,
        bytes32 evidenceRef
    );
    
    event AgentRegistered(address indexed agent, address indexed owner);
    
    // ============ Modifiers ============
    
    modifier onlyAgentOwner(address agent) {
        require(agentOwners[agent] == msg.sender, "Not agent owner");
        require(authorities[agent].isActive, "Agent not active");
        _;
    }
    
    modifier agentExists(address agent) {
        require(authorities[agent].isActive || agentOwners[agent] != address(0), "Agent not registered");
        _;
    }
    
    // ============ Registration ============
    
    function registerAgent(address agent) external {
        require(agent != address(0), "Invalid address");
        require(agentOwners[agent] == address(0), "Agent already registered");
        agentOwners[agent] = msg.sender;
        
        // Initialize with OBSERVE level
        authorities[agent] = AuthorityStateInfo({
            level: AuthorityLevel.OBSERVE,
            previousLevel: AuthorityLevel.REVOKED,
            scope: bytes32(0),
            expiresAt: 0,
            lastActivity: block.timestamp,
            isActive: true
        });
        
        emit AgentRegistered(agent, msg.sender);
    }
    
    // ============ Authority Management ============
    
    function grantAuthority(
        address agent,
        AuthorityLevel level,
        bytes32 scope,
        uint256 duration
    ) external onlyAgentOwner(agent) returns (bytes32 transitionId) {
        require(level != AuthorityLevel.REVOKED, "Cannot grant REVOKED");
        require(scope != bytes32(0) || level == AuthorityLevel.EXECUTE, "Invalid scope");
        
        AuthorityStateInfo storage state = authorities[agent];
        AuthorityLevel previousLevel = state.level;
        
        transitionId = _createTransition(
            agent, previousLevel, level, EventType.GRANT, bytes32(0), abi.encode(level)
        );
        
        state.level = level;
        state.previousLevel = previousLevel;
        state.scope = scope;
        state.expiresAt = duration > 0 ? block.timestamp + duration : 0;
        state.lastActivity = block.timestamp;
        state.isActive = true;
        
        emit AuthorityGranted(transitionId, agent, level, scope, state.expiresAt);
    }
    
    function decayAuthority(
        address agent,
        DecayReason reason
    ) external agentExists(agent) returns (bytes32 transitionId) {
        AuthorityStateInfo storage state = authorities[agent];
        require(state.isActive, "Agent not active");
        
        // Validate decay conditions
        if (reason == DecayReason.SESSION_EXPIRY) {
            require(state.expiresAt > 0 && block.timestamp >= state.expiresAt, "Not expired");
        }
        
        AuthorityLevel newLevel = _getDecayedLevel(state.level);
        if (newLevel == state.level) return bytes32(0);
        
        AuthorityLevel previousLevel = state.level;
        
        transitionId = _createTransition(
            agent, previousLevel, newLevel, EventType.DECAY, bytes32(0), abi.encode(reason)
        );
        
        state.previousLevel = previousLevel;
        state.level = newLevel;
        state.lastActivity = block.timestamp;
        
        emit AuthorityDecayed(transitionId, agent, previousLevel, newLevel, reason);
    }
    
    function revokeAuthority(
        address agent,
        RevokeReason reason,
        bytes32 evidenceRef
    ) external agentExists(agent) returns (bytes32 transitionId) {
        AuthorityStateInfo storage state = authorities[agent];
        require(state.isActive, "Agent not active");
        
        AuthorityLevel previousLevel = state.level;
        
        transitionId = _createTransition(
            agent, previousLevel, AuthorityLevel.OBSERVE, EventType.REVOKE, evidenceRef, abi.encode(reason)
        );
        
        state.previousLevel = previousLevel;
        state.level = AuthorityLevel.OBSERVE;
        state.lastActivity = block.timestamp;
        
        emit AuthorityRevoked(transitionId, agent, previousLevel, reason, evidenceRef);
    }
    
    function recoverAuthority(
        address agent,
        AuthorityLevel newLevel,
        RecoveryReason reason,
        bytes32 evidenceRef
    ) external onlyAgentOwner(agent) returns (bytes32 transitionId) {
        AuthorityStateInfo storage state = authorities[agent];
        AuthorityLevel previousLevel = state.level;
        
        transitionId = _createTransition(
            agent, previousLevel, newLevel, EventType.RECOVER, evidenceRef, abi.encode(reason)
        );
        
        state.previousLevel = previousLevel;
        state.level = newLevel;
        state.lastActivity = block.timestamp;
        state.isActive = true;
        
        emit AuthorityRecovered(transitionId, agent, newLevel, reason, evidenceRef);
    }
    
    // ============ View Functions ============
    
    function checkAuthority(address agent, AuthorityLevel requiredLevel) 
        external view returns (bool hasAuthority, AuthorityLevel currentLevel) 
    {
        AuthorityStateInfo storage state = authorities[agent];
        currentLevel = state.level;
        hasAuthority = uint8(state.level) >= uint8(requiredLevel) && state.isActive;
    }
    
    function getAgentHistory(address agent) external view returns (bytes32[] memory) {
        return agentHistory[agent];
    }
    
    function getTransition(bytes32 transitionId) external view returns (Transition memory) {
        return transitions[transitionId];
    }
    
    function getAuthorityState(address agent) external view returns (AuthorityStateInfo memory) {
        return authorities[agent];
    }
    
    // ============ Internal Functions ============
    
    function _createTransition(
        address agent,
        AuthorityLevel fromLevel,
        AuthorityLevel toLevel,
        EventType eventType,
        bytes32 evidenceRef,
        bytes memory reason
    ) internal returns (bytes32 transitionId) {
        transitionId = keccak256(abi.encode(
            agent,
            uint8(eventType),
            block.timestamp,
            totalTransitions,
            msg.sender
        ));
        
        transitions[transitionId] = Transition({
            id: transitionId,
            agent: agent,
            fromLevel: fromLevel,
            toLevel: toLevel,
            eventType: eventType,
            evidenceRef: evidenceRef,
            reason: reason,
            timestamp: block.timestamp,
            triggeredBy: msg.sender
        });
        
        agentHistory[agent].push(transitionId);
        totalTransitions++;
    }
    
    function _getDecayedLevel(AuthorityLevel currentLevel) internal pure returns (AuthorityLevel) {
        if (currentLevel == AuthorityLevel.EXECUTE) {
            return AuthorityLevel.SUGGEST;
        } else if (currentLevel == AuthorityLevel.SUGGEST) {
            return AuthorityLevel.OBSERVE;
        }
        return currentLevel;
    }
}
