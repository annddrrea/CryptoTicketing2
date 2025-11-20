// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../contracts/Ticket.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy Ticket contract
        Ticket ticket = new Ticket("CryptoTicketing Event Ticket", "TICKET");

        console.log("Ticket contract deployed at:", address(ticket));

        vm.stopBroadcast();
    }
}