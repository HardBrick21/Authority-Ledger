// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title EvidenceStore
 * @notice Stores evidence for authority transitions with diversity check support
 * @dev Evidence hashes on-chain, full data on IPFS/Arweave
 */
contract EvidenceStore {
    
    // ============ Enums ============
    
    enum EvidenceType {
        DIVERSITY_CHECK,
        CONTRACT_CHECK,
        HUMAN_ATTESTATION,
        OBSERVATION_HASH,
        SIDE_EFFECT_PROOF
    }
    
    enum EvidenceStatus {
        PENDING,
        VALID,
        INVALID,
        EXPIRED
    }
    
    // ============ Structs ============
    
    struct Evidence {
        bytes32 id;
        address agent;
        EvidenceType eType;
        bytes32 dataHash;
        string ipfsCid;
        bytes32 sourceVersion;
        bytes32 cacheBatch;
        uint256 timestamp;
        address collector;
        EvidenceStatus status;
    }
    
    struct DiversityConfig {
        uint256 minUniqueVersions;
        uint256 minUniqueBatches;
        uint256 minTimeWindow;
        uint256 minSampleCount;
    }
    
    // ============ State Variables ============
    
    mapping(bytes32 => Evidence) public evidences;
    mapping(address => bytes32[]) public agentEvidences;
    mapping(address => DiversityConfig) public diversityConfigs;
    
    DiversityConfig public defaultConfig = DiversityConfig({
        minUniqueVersions: 2,
        minUniqueBatches: 2,
        minTimeWindow: 1800,
        minSampleCount: 5
    });
    
    uint256 public totalEvidences;
    address public authorityState;
    
    // ============ Events ============
    
    event EvidenceSubmitted(
        bytes32 indexed evidenceId,
        address indexed agent,
        EvidenceType eType,
        bytes32 dataHash,
        string ipfsCid
    );
    
    event EvidenceValidated(bytes32 indexed evidenceId, EvidenceStatus status);
    event DiversityCheckPassed(address indexed agent, bytes32[] evidenceIds);
    event DiversityCheckFailed(address indexed agent, string reason);
    
    // ============ Constructor ============
    
    constructor(address _authorityState) {
        authorityState = _authorityState;
    }
    
    // ============ External Functions ============
    
    function submitEvidence(
        address agent,
        EvidenceType eType,
        bytes32 dataHash,
        string calldata ipfsCid,
        bytes32 sourceVersion,
        bytes32 cacheBatch
    ) external returns (bytes32 evidenceId) {
        evidenceId = keccak256(abi.encodePacked(
            agent, uint8(eType), dataHash, block.timestamp, totalEvidences
        ));
        
        evidences[evidenceId] = Evidence({
            id: evidenceId,
            agent: agent,
            eType: eType,
            dataHash: dataHash,
            ipfsCid: ipfsCid,
            sourceVersion: sourceVersion,
            cacheBatch: cacheBatch,
            timestamp: block.timestamp,
            collector: msg.sender,
            status: EvidenceStatus.PENDING
        });
        
        agentEvidences[agent].push(evidenceId);
        totalEvidences++;
        
        emit EvidenceSubmitted(evidenceId, agent, eType, dataHash, ipfsCid);
    }
    
    function validateEvidence(bytes32 evidenceId, bool isValid) external {
        Evidence storage evidence = evidences[evidenceId];
        require(evidence.id == evidenceId, "Evidence not found");
        evidence.status = isValid ? EvidenceStatus.VALID : EvidenceStatus.INVALID;
        emit EvidenceValidated(evidenceId, evidence.status);
    }
    
    function checkDiversity(
        address agent,
        bytes32[] calldata evidenceIds
    ) external returns (bool passed, string memory reason) {
        DiversityConfig memory config = diversityConfigs[agent];
        if (config.minSampleCount == 0) config = defaultConfig;
        
        if (evidenceIds.length < config.minSampleCount) {
            reason = "Insufficient samples";
            emit DiversityCheckFailed(agent, reason);
            return (false, reason);
        }
        
        bytes32[] memory versions = new bytes32[](evidenceIds.length);
        bytes32[] memory batches = new bytes32[](evidenceIds.length);
        uint256 uniqueVersions = 0;
        uint256 uniqueBatches = 0;
        uint256 minTime = type(uint256).max;
        uint256 maxTime = 0;
        
        for (uint256 i = 0; i < evidenceIds.length; i++) {
            Evidence storage evidence = evidences[evidenceIds[i]];
            if (evidence.agent != agent || evidence.status != EvidenceStatus.VALID) continue;
            
            bool versionFound = false;
            for (uint256 j = 0; j < uniqueVersions; j++) {
                if (versions[j] == evidence.sourceVersion) { versionFound = true; break; }
            }
            if (!versionFound) { versions[uniqueVersions] = evidence.sourceVersion; uniqueVersions++; }
            
            bool batchFound = false;
            for (uint256 j = 0; j < uniqueBatches; j++) {
                if (batches[j] == evidence.cacheBatch) { batchFound = true; break; }
            }
            if (!batchFound) { batches[uniqueBatches] = evidence.cacheBatch; uniqueBatches++; }
            
            if (evidence.timestamp < minTime) minTime = evidence.timestamp;
            if (evidence.timestamp > maxTime) maxTime = evidence.timestamp;
        }
        
        if (uniqueVersions < config.minUniqueVersions) {
            reason = "Insufficient unique versions";
            emit DiversityCheckFailed(agent, reason);
            return (false, reason);
        }
        
        if (uniqueBatches < config.minUniqueBatches) {
            reason = "Insufficient unique batches";
            emit DiversityCheckFailed(agent, reason);
            return (false, reason);
        }
        
        if (maxTime - minTime < config.minTimeWindow) {
            reason = "Time window too short";
            emit DiversityCheckFailed(agent, reason);
            return (false, reason);
        }
        
        emit DiversityCheckPassed(agent, evidenceIds);
        return (true, "");
    }
    
    function setDiversityConfig(
        address agent,
        uint256 minUniqueVersions,
        uint256 minUniqueBatches,
        uint256 minTimeWindow,
        uint256 minSampleCount
    ) external {
        diversityConfigs[agent] = DiversityConfig({
            minUniqueVersions: minUniqueVersions,
            minUniqueBatches: minUniqueBatches,
            minTimeWindow: minTimeWindow,
            minSampleCount: minSampleCount
        });
    }
    
    // ============ View Functions ============
    
    function getEvidence(bytes32 evidenceId) external view returns (Evidence memory) {
        return evidences[evidenceId];
    }
    
    function getAgentEvidences(address agent) external view returns (bytes32[] memory) {
        return agentEvidences[agent];
    }
}