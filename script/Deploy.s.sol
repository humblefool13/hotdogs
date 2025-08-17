// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/HotDogs.sol";

/**
 * @title HotDogsRegistry Deployment Script
 * @dev Deploys HotDogsRegistry contract to testnet
 */
contract DeployScript is Script {
    function run() external {
        vm.createSelectFork("sepolia");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy HotDogsRegistry
        HotDogsRegistry registry = new HotDogsRegistry();

        // Register a test domain for verification (optional)
        string memory testDomain = "deployment-test.hotdogs";
        uint256 price = registry.getDomainPrice(testDomain);

        if (deployer.balance >= price) {
            registry.registerDomain{value: price}(testDomain, 1);
        }

        vm.stopBroadcast();
    }
}
