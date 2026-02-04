// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/// @title ClawPunks
/// @notice Fully onchain 20x20 pixel art NFT. Art matches index.html preview.
/// @dev Pixel map: 0=background, 1=body, 2=eye. 23 colors per part.
contract ClawPunks is ERC721, Ownable {
    using Strings for uint256;

    uint256 public constant MAX_SUPPLY = 10_000;
    uint256 public constant GRID_SIZE = 20;
    uint256 public constant PIXEL = 20;

    uint256 private _nextTokenId;

    // Pixel map: 0=background, 1=body, 2=eye (matches index.html)
    // 20 rows x 20 cols, row-major
    string private constant PIXEL_MAP =
        "00000000000000000000"
        "00000000000000000000"
        "01000000000000000010"
        "01100000011000000110"
        "01101000211200010110"
        "01111001111110011110"
        "01111111111111111110"
        "00111011111111011100"
        "00000011111111000000"
        "00000000111100000000"
        "00000000111100000000"
        "00000000111100000000"
        "00000000111100000000"
        "00000000111100000000"
        "00000001111110000000"
        "00000011111111000000"
        "00000001111110000000"
        "00000000111100000000"
        "00000000011000000000"
        "00000000000000000000";

    // 23 colors (matches index.html)
    string[23] private PALETTE = [
        "#000000", "#FFFFFF", "#D32F2F", "#FF6A00", "#FFD100",
        "#9AFF00", "#00B894", "#0B5D1E", "#00E5FF", "#42A5F5",
        "#0033A0", "#2E0066", "#7C3AED", "#FF2F92", "#FF8A80",
        "#6D1B1B", "#5A0000", "#C46210", "#7A8B00", "#6B7C8F",
        "#263238", "#F3E2B3", "#00FF9C"
    ];

    constructor() ERC721("ClawPunks", "CLAW") Ownable(msg.sender) {}

    uint256 public constant PREMINT_BATCH_SIZE = 2000;

    /// @notice Premint tokens to an address (owner only).
    function premint(address to, uint256 quantity) external onlyOwner {
        require(_nextTokenId + quantity <= MAX_SUPPLY, "Exceeds max supply");
        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = _nextTokenId;
            _nextTokenId++;
            _safeMint(to, tokenId);
        }
    }

    /// @notice Premint one batch (2000 or remaining) to an address. Call 5 times to mint all 10,000 (owner only).
    function premintBatch(address to) external onlyOwner {
        uint256 remaining = MAX_SUPPLY - _nextTokenId;
        require(remaining > 0, "Already fully minted");
        uint256 quantity = remaining >= PREMINT_BATCH_SIZE ? PREMINT_BATCH_SIZE : remaining;
        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = _nextTokenId;
            _nextTokenId++;
            _safeMint(to, tokenId);
        }
    }

    /// @notice Get trait indices for a tokenId (for testing, indexers). Pure, no ownership check.
    function getTraits(uint256 tokenId) external pure returns (
        uint256 bgIdx, uint256 bodyIdx, uint256 eyeIdx
    ) {
        return _getTraits(tokenId);
    }

    /// @notice Derive trait indices from tokenId (0-22 each). Background, body, eyes.
    /// @dev All three must be distinct (bg != body != eye). 23*22*21 = 10,626 combos for 10k tokens.
    function _getTraits(uint256 tokenId) internal pure returns (
        uint256 bgIdx, uint256 bodyIdx, uint256 eyeIdx
    ) {
        bgIdx = tokenId % 23;
        // Body: pick from 22 colors excluding bg
        uint256 bodySlot = (tokenId / 23) % 22;
        uint256 count = 0;
        for (uint256 c = 0; c < 23; c++) {
            if (c != bgIdx) {
                if (count == bodySlot) {
                    bodyIdx = c;
                    break;
                }
                count++;
            }
        }
        // Eye: pick from 21 colors excluding bg and body
        uint256 eyeSlot = (tokenId / 506) % 21; // 23*22 = 506
        count = 0;
        for (uint256 c = 0; c < 23; c++) {
            if (c != bgIdx && c != bodyIdx) {
                if (count == eyeSlot) {
                    eyeIdx = c;
                    break;
                }
                count++;
            }
        }
    }

    /// @notice Get color for a pixel type. 0=background, 1=body, 2=eye.
    function _getColor(uint8 pixelType, uint256 tokenId) internal view returns (string memory) {
        (uint256 bgIdx, uint256 bodyIdx, uint256 eyeIdx) = _getTraits(tokenId);
        if (pixelType == 0) return PALETTE[bgIdx];
        if (pixelType == 1) return PALETTE[bodyIdx];
        if (pixelType == 2) return PALETTE[eyeIdx];
        return PALETTE[bgIdx];
    }

    /// @notice Build SVG from pixel map and token traits.
    function _buildSVG(uint256 tokenId) internal view returns (string memory) {
        bytes memory map = bytes(PIXEL_MAP);
        uint256 w = GRID_SIZE * PIXEL;
        uint256 h = GRID_SIZE * PIXEL;

        string memory rects;
        for (uint256 y = 0; y < GRID_SIZE; y++) {
            for (uint256 x = 0; x < GRID_SIZE; x++) {
                uint256 idx = y * GRID_SIZE + x;
                uint8 c = uint8(map[idx]) - 48; // '0'->0, '1'->1, etc.
                string memory fill = _getColor(c, tokenId);
                uint256 px = x * PIXEL;
                uint256 py = y * PIXEL;
                rects = string(abi.encodePacked(
                    rects,
                    '<rect x="', px.toString(), '" y="', py.toString(),
                    '" width="', PIXEL.toString(), '" height="', PIXEL.toString(),
                    '" fill="', fill, '"/>'
                ));
            }
        }

        return string(abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" width="', w.toString(), '" height="', h.toString(),
            '" viewBox="0 0 ', w.toString(), ' ', h.toString(), '" shape-rendering="crispEdges">',
            rects,
            '</svg>'
        ));
    }

    /// @notice Returns base64-encoded data URI with fully onchain SVG.
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);

        string memory svg = _buildSVG(tokenId);
        string memory imageBase64 = Base64.encode(bytes(svg));
        string memory json = Base64.encode(bytes(string(abi.encodePacked(
            '{"name":"ClawPunk #', tokenId.toString(),
            '","description":"Fully onchain ClawPunk. 20x20 pixel art."',
            ',"image":"data:image/svg+xml;base64,', imageBase64, '"}'
        ))));

        return string(abi.encodePacked("data:application/json;base64,", json));
    }
}
