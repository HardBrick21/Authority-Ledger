// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/AuthorityState.sol";
import "../contracts/EvidenceStore.sol";

contract AuthorityStateTest is Test {
    AuthorityState public authority;
    EvidenceStore public evidence;
    
    address public owner = address(0x1);
    address public agent = address(0x2);
    address public other = address(0x3);
    
    function setUp() public {
        vm.startPrank(owner);
        authority = new AuthorityState();
        evidence = new EvidenceStore(address(authority));
        vm.stopPrank();
    }
    
    function testRegisterAgent() public {
        vm.prank(owner);
        authority.registerAgent(agent);
        
        AuthorityState.AuthorityStateInfo memory state = authority.getAuthorityState(agent);
        assertEq(uint8(state.level), uint8(AuthorityState.AuthorityLevel.OBSERVE));
        assertTrue(state.isActive);
    }
    
    function testGrantAuthority() public {
        vm.startPrank(owner);
        authority.registerAgent(agent);
        
        bytes32 scope = bytes32(uint256(1));
        uint256 duration = 1 days;
        
        bytes32 transitionId = authority.grantAuthority(
            agent,
            AuthorityState.AuthorityLevel.EXECUTE,
            scope,
            duration
        );
        
        AuthorityState.AuthorityStateInfo memory state = authority.getAuthorityState(agent);
        assertEq(uint8(state.level), uint8(AuthorityState.AuthorityLevel.EXECUTE));
        assertGt(state.expiresAt, 0);
        
        vm.stopPrank();
    }
    
    function testDecayAuthority() public {
        vm.startPrank(owner);
        authority.registerAgent(agent);
        authority.grantAuthority(
            agent,
            AuthorityState.AuthorityLevel.EXECUTE,
            bytes32(0),
            1 hours
        );
        
        vm.warp(block.timestamp + 2 hours);
        
        authority.decayAuthority(agent, AuthorityState.DecayReason.SESSION_EXPIRY);
        
        AuthorityState.AuthorityStateInfo memory state = authority.getAuthorityState(agent);
        assertEq(uint8(state.level), uint8(AuthorityState.AuthorityLevel.SUGGEST));
        
        vm.stopPrank();
    }
    
    function testRevokeAuthority() public {
        vm.startPrank(owner);
        authority.registerAgent(agent);
        authority.grantAuthority(
            agent,
            AuthorityState.AuthorityLevel.EXECUTE,
            bytes32(0),
            0
        );
        
        bytes32 evidenceRef = keccak256("test_evidence");
        authority.revokeAuthority(
            agent,
            AuthorityState.RevokeReason.DRIFT_DETECTED,
            evidenceRef
        );
        
        AuthorityState.AuthorityStateInfo memory state = authority.getAuthorityState(agent);
        assertEq(uint8(state.level), uint8(AuthorityState.AuthorityLevel.OBSERVE));
        
        vm.stopPrank();
    }
    
    function testRecoverAuthority() public {
        vm.startPrank(owner);
        authority.registerAgent(agent);
        
        authority.grantAuthority(agent, AuthorityState.AuthorityLevel.EXECUTE, bytes32(0), 0);
        authority.revokeAuthority(agent, AuthorityState.RevokeReason.DRIFT_DETECTED, bytes32(0));
        
        bytes32 evidenceRef = keccak256("recovery_evidence");
        authority.recoverAuthority(
            agent,
            AuthorityState.AuthorityLevel.SUGGEST,
            AuthorityState.RecoveryReason.DIVERSITY_GATE,
            evidenceRef
        );
        
        AuthorityState.AuthorityStateInfo memory state = authority.getAuthorityState(agent);
        assertEq(uint8(state.level), uint8(AuthorityState.AuthorityLevel.SUGGEST));
        
        vm.stopPrank();
    }
    
    function testCheckAuthority() public {
        vm.startPrank(owner);
        authority.registerAgent(agent);
        bytes32 scope = bytes32(uint256(1));
        authority.grantAuthority(agent, AuthorityState.AuthorityLevel.SUGGEST, scope, 0);
        
        (bool hasAuthority, AuthorityState.AuthorityLevel currentLevel) = authority.checkAuthority(
            agent,
            AuthorityState.AuthorityLevel.OBSERVE
        );
        assertTrue(hasAuthority);
        assertEq(uint8(currentLevel), uint8(AuthorityState.AuthorityLevel.SUGGEST));
        
        (hasAuthority, ) = authority.checkAuthority(
            agent,
            AuthorityState.AuthorityLevel.EXECUTE
        );
        assertFalse(hasAuthority);
        
        vm.stopPrank();
    }
    
    function testGetAgentHistory() public {
        vm.startPrank(owner);
        authority.registerAgent(agent);
        
        bytes32 scope = bytes32(uint256(1));
        authority.grantAuthority(agent, AuthorityState.AuthorityLevel.SUGGEST, scope, 0);
        authority.grantAuthority(agent, AuthorityState.AuthorityLevel.EXECUTE, scope, 0);
        
        bytes32[] memory history = authority.getAgentHistory(agent);
        assertEq(history.length, 2);
        
        vm.stopPrank();
    }
}

contract EvidenceStoreTest is Test {
    AuthorityState public authority;
    EvidenceStore public evidence;
    
    address public owner = address(0x1);
    address public agent = address(0x2);
    
    function setUp() public {
        vm.prank(owner);
        authority = new AuthorityState();
        evidence = new EvidenceStore(address(authority));
    }
    
    function testSubmitEvidence() public {
        bytes32 evidenceId = evidence.submitEvidence(
            agent,
            EvidenceStore.EvidenceType.DIVERSITY_CHECK,
            keccak256("test_data"),
            "ipfs://test",
            keccak256("v1.0"),
            keccak256("batch1")
        );
        
        EvidenceStore.Evidence memory e = evidence.getEvidence(evidenceId);
        assertEq(e.id, evidenceId);
        assertEq(e.agent, agent);
        assertEq(uint8(e.eType), uint8(EvidenceStore.EvidenceType.DIVERSITY_CHECK));
    }
    
    function testValidateEvidence() public {
        bytes32 evidenceId = evidence.submitEvidence(
            agent,
            EvidenceStore.EvidenceType.CONTRACT_CHECK,
            keccak256("test"),
            "",
            keccak256("v1.0"),
            keccak256("batch1")
        );
        
        evidence.validateEvidence(evidenceId, true);
        
        EvidenceStore.Evidence memory e = evidence.getEvidence(evidenceId);
        assertEq(uint8(e.status), uint8(EvidenceStore.EvidenceStatus.VALID));
    }
    
    function testDiversityCheck() public {
        for (uint256 i = 0; i < 5; i++) {
            // Spread evidence over time (500 seconds apart, total 2000s > 1800s window)
            vm.warp(1 + i * 500);
            
            bytes32 evidenceId = evidence.submitEvidence(
                agent,
                EvidenceStore.EvidenceType.DIVERSITY_CHECK,
                keccak256(abi.encode("data", i)),
                "",
                keccak256(abi.encode("v", i % 3)),
                keccak256(abi.encode("batch", i % 2))
            );
            evidence.validateEvidence(evidenceId, true);
        }
        
        bytes32[] memory allEvidence = evidence.getAgentEvidences(agent);
        (bool passed, ) = evidence.checkDiversity(agent, allEvidence);
        assertTrue(passed);
    }
    
    function testDiversityCheckFailsInsufficientSamples() public {
        for (uint256 i = 0; i < 3; i++) {
            bytes32 evidenceId = evidence.submitEvidence(
                agent,
                EvidenceStore.EvidenceType.DIVERSITY_CHECK,
                keccak256(abi.encode("data", i)),
                "",
                keccak256("v1.0"),
                keccak256("batch1")
            );
            evidence.validateEvidence(evidenceId, true);
        }
        
        bytes32[] memory allEvidence = evidence.getAgentEvidences(agent);
        (bool passed, ) = evidence.checkDiversity(agent, allEvidence);
        assertFalse(passed);
    }
}