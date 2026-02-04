// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/ClawPunks.sol";

/// @notice Simulate deploy, premint, and print tokenURI for token 0. For local preview.
/// Usage: forge script script/PreviewTokenURI.s.sol
contract PreviewTokenURI is Script {
    function run() external {
        vm.startBroadcast();
        ClawPunks cp = new ClawPunks();
        cp.premint(address(0x1), 1);
        vm.stopBroadcast();

        string memory uri = cp.tokenURI(0);
        console.log("tokenURI (first 200 chars):");
        console.log(_substring(uri, 0, 200));
    }

    function _substring(string memory s, uint256 start, uint256 len) internal pure returns (string memory) {
        bytes memory b = bytes(s);
        if (start + len > b.length) len = b.length - start;
        bytes memory out = new bytes(len);
        for (uint256 i = 0; i < len; i++) out[i] = b[start + i];
        return string(out);
    }
}
