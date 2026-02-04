// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/ClawPunks.sol";

/// @notice Script to fetch tokenURI for a tokenId. Run after deploying and preminting.
/// Usage: forge script script/GetTokenURI.s.sol --sig "run(uint256)" 0 --rpc-url $RPC
contract GetTokenURI is Script {
    function run(uint256 tokenId) external view {
        address contractAddr = vm.envAddress("CLAWPUNKS_ADDRESS");
        ClawPunks cp = ClawPunks(contractAddr);
        string memory uri = cp.tokenURI(tokenId);
        console.log("tokenURI:", uri);
    }
}
