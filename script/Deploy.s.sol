// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/AuthorityState.sol";
import "../contracts/EvidenceStore.sol";

contract Deploy is Script {
    function run() external {
        string memory privateKeyStr = vm.envString("PRIVATE_KEY");
        uint256 deployerPrivateKey = vm.parseUint(string.concat("0x", privateKeyStr));
        vm.startBroadcast(deployerPrivateKey);

        AuthorityState authority = new AuthorityState();
        EvidenceStore evidence = new EvidenceStore(address(authority));

        console.log("AuthorityState deployed at:", address(authority));
        console.log("EvidenceStore deployed at:", address(evidence));

        vm.stopBroadcast();
    }
}