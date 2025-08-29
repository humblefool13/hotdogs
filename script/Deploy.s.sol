// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/HNSManager.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy HNSManager
        HNSManager manager = new HNSManager();

        console.log("HNSManager deployed at:", address(manager));
        console.log("SVG Library deployed at:", manager.svgLibrary());

        // Add default TLDs
        manager.addTLD("hotdogs");
        manager.addTLD("rise");

        console.log("Default TLDs added: hotdogs, rise");

        vm.stopBroadcast();
    }
}
