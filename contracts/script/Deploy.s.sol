// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/ClawPunks.sol";

contract DeployClawPunks is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0));
        if (deployerPrivateKey == 0) {
            deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        }

        vm.startBroadcast(deployerPrivateKey);

        ClawPunks clawPunks = new ClawPunks();

        console.log("ClawPunks deployed at:", address(clawPunks));

        vm.stopBroadcast();
    }
}
