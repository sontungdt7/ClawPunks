// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ClawPunks.sol";

contract ClawPunksTest is Test {
    ClawPunks public clawPunks;
    mapping(bytes32 => bool) private _seenTraitCombo;

    function setUp() public {
        clawPunks = new ClawPunks();
    }

    function test_Premint() public {
        address to = address(0x1);
        clawPunks.premint(to, 10);

        assertEq(clawPunks.ownerOf(0), to);
        assertEq(clawPunks.ownerOf(9), to);
        assertEq(clawPunks.balanceOf(to), 10);
    }

    function test_TokenURI() public {
        address owner = address(0x1);
        clawPunks.premint(owner, 1);

        string memory uri = clawPunks.tokenURI(0);
        assertTrue(bytes(uri).length > 1000);
        assertTrue(_startsWith(uri, "data:application/json;base64,"));
    }

    function _startsWith(string memory a, string memory b) internal pure returns (bool) {
        bytes memory aa = bytes(a);
        bytes memory bb = bytes(b);
        if (aa.length < bb.length) return false;
        for (uint256 i = 0; i < bb.length; i++) {
            if (aa[i] != bb[i]) return false;
        }
        return true;
    }

    function test_RevertExceedsMaxSupply() public {
        vm.expectRevert("Exceeds max supply");
        clawPunks.premint(address(this), 10_001);
    }

    function test_OnlyOwnerCanPremint() public {
        vm.prank(address(0x999));
        vm.expectRevert();
        clawPunks.premint(address(0x999), 1);
    }

    function test_PremintBatch() public {
        address to = address(0x1);
        assertEq(clawPunks.PREMINT_BATCH_SIZE(), 200);

        clawPunks.premintBatch(to);
        assertEq(clawPunks.balanceOf(to), 200);
        assertEq(clawPunks.ownerOf(0), to);
        assertEq(clawPunks.ownerOf(199), to);

        clawPunks.premintBatch(to);
        assertEq(clawPunks.balanceOf(to), 400);

        for (uint256 i = 0; i < 48; i++) {
            clawPunks.premintBatch(to);
        }
        assertEq(clawPunks.balanceOf(to), 10_000);
        assertEq(clawPunks.ownerOf(9999), to);

        vm.expectRevert("Already fully minted");
        clawPunks.premintBatch(to);
    }

    /// @notice All 10,000 NFTs have valid traits (indices 0-6) and unique color combinations.
    function test_All10000HaveValidAndUniqueTraits() public {
        uint256 maxSupply = clawPunks.MAX_SUPPLY();
        assertEq(maxSupply, 10_000);

        for (uint256 tokenId = 0; tokenId < maxSupply; tokenId++) {
            (uint256 bgIdx, uint256 bodyIdx, uint256 torsoIdx, uint256 clawIdx, uint256 eyeIdx) =
                clawPunks.getTraits(tokenId);

            // Rule: each trait index must be 0-6 (valid palette index)
            assertLe(bgIdx, 6, "bgIdx out of range");
            assertLe(bodyIdx, 6, "bodyIdx out of range");
            assertLe(torsoIdx, 6, "torsoIdx out of range");
            assertLe(clawIdx, 6, "clawIdx out of range");
            assertLe(eyeIdx, 6, "eyeIdx out of range");

            bytes32 key = keccak256(abi.encodePacked(bgIdx, bodyIdx, torsoIdx, clawIdx, eyeIdx));
            assertFalse(_seenTraitCombo[key], "Duplicate trait combination");
            _seenTraitCombo[key] = true;
        }
    }

}
