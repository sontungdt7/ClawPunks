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
        assertEq(clawPunks.PREMINT_BATCH_SIZE(), 2000);

        clawPunks.premintBatch(to);
        assertEq(clawPunks.balanceOf(to), 2000);
        assertEq(clawPunks.ownerOf(0), to);
        assertEq(clawPunks.ownerOf(1999), to);

        clawPunks.premintBatch(to);
        assertEq(clawPunks.balanceOf(to), 4000);

        for (uint256 i = 0; i < 3; i++) {
            clawPunks.premintBatch(to);
        }
        assertEq(clawPunks.balanceOf(to), 10_000);
        assertEq(clawPunks.ownerOf(9999), to);

        vm.expectRevert("Already fully minted");
        clawPunks.premintBatch(to);
    }

    function test_RoyaltyInfo() public {
        clawPunks.premint(address(0x1), 1);
        (address receiver, uint256 amount) = clawPunks.royaltyInfo(0, 1 ether);
        assertEq(receiver, clawPunks.owner());
        assertEq(amount, 0.05 ether); // 5% of 1 ether
    }

    function test_SetRoyaltyReceiver() public {
        address newReceiver = address(0x42);
        clawPunks.setRoyaltyReceiver(newReceiver);
        clawPunks.premint(address(0x1), 1);
        (address receiver, uint256 amount) = clawPunks.royaltyInfo(0, 1 ether);
        assertEq(receiver, newReceiver);
        assertEq(amount, 0.05 ether); // fee unchanged at 5%
    }

    /// @notice All 10,000 NFTs have valid traits (indices 0-22) and unique color combinations.
    function test_All10000HaveValidAndUniqueTraits() public {
        uint256 maxSupply = clawPunks.MAX_SUPPLY();
        assertEq(maxSupply, 10_000);

        for (uint256 tokenId = 0; tokenId < maxSupply; tokenId++) {
            (uint256 bgIdx, uint256 bodyIdx, uint256 eyeIdx) =
                clawPunks.getTraits(tokenId);

            // Rule: each trait index must be 0-22 (valid palette index)
            assertLe(bgIdx, 22, "bgIdx out of range");
            assertLe(bodyIdx, 22, "bodyIdx out of range");
            assertLe(eyeIdx, 22, "eyeIdx out of range");

            // Rule: bg, body, eye must all be distinct
            assertTrue(bgIdx != bodyIdx, "bg must not match body");
            assertTrue(bgIdx != eyeIdx, "bg must not match eye");
            assertTrue(bodyIdx != eyeIdx, "body must not match eye");

            bytes32 key = keccak256(abi.encodePacked(bgIdx, bodyIdx, eyeIdx));
            assertFalse(_seenTraitCombo[key], "Duplicate trait combination");
            _seenTraitCombo[key] = true;
        }
    }

}
