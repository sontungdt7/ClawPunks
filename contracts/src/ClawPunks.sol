// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/// @title ClawPunks
/// @notice Fully onchain 20x20 pixel art NFT. Art matches generate_grid_svg.py.
/// @dev Pixel map: 0=bg, 1=claw, 2=eyes, 3=torso, 4=body. Each can have same or different colors.
contract ClawPunks is ERC721, Ownable {
    using Strings for uint256;

    uint256 public constant MAX_SUPPLY = 10_000;
    uint256 public constant GRID_SIZE = 20;
    uint256 public constant PIXEL = 20;

    uint256 private _nextTokenId;

    // Pixel map from generate_grid_svg.py (0=bg, 1=claw, 2=eyes, 3=torso, 4=body)
    // 20 rows x 20 cols, row-major
    string private constant PIXEL_MAP =
        "00000000000000000000"
        "00000000000000000000"
        "01000000000000000010"
        "01100000044000000110"
        "01101000244200010110"
        "01111004444440011110"
        "01111144444444111110"
        "00111044444444011100"
        "00000044444444000000"
        "00000000433400000000"
        "00000000433400000000"
        "00000000433400000000"
        "00000000433400000000"
        "00000000433400000000"
        "00000004444440000000"
        "00000044444444000000"
        "00000004444440000000"
        "00000000444400000000"
        "00000000044000000000"
        "00000000000000000000";

    // 7 colors: black, white, red, yellow, teal, blue, violet
    string[7] private PALETTE = [
        "#000000", "#ffffff", "#e53935", "#ffeb3b", "#00897b", "#2196f3", "#8e24aa"
    ];

    constructor() ERC721("ClawPunks", "CLAW") Ownable(msg.sender) {}

    uint256 public constant PREMINT_BATCH_SIZE = 200;

    /// @notice Premint tokens to an address (owner only).
    function premint(address to, uint256 quantity) external onlyOwner {
        require(_nextTokenId + quantity <= MAX_SUPPLY, "Exceeds max supply");
        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = _nextTokenId;
            _nextTokenId++;
            _safeMint(to, tokenId);
        }
    }

    /// @notice Premint one batch (200 or remaining) to an address. Call 50 times to mint all 10,000 (owner only).
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
        uint256 bgIdx, uint256 bodyIdx, uint256 torsoIdx, uint256 clawIdx, uint256 eyeIdx
    ) {
        return _getTraits(tokenId);
    }

    /// @notice Derive trait indices from tokenId (0-6 each). Body, torso, claw can be same or different.
    function _getTraits(uint256 tokenId) internal pure returns (
        uint256 bgIdx, uint256 bodyIdx, uint256 torsoIdx, uint256 clawIdx, uint256 eyeIdx
    ) {
        bgIdx = tokenId % 7;
        bodyIdx = (tokenId / 7) % 7;
        torsoIdx = (tokenId / 49) % 7;
        clawIdx = (tokenId / 343) % 7;
        eyeIdx = (tokenId / 2401) % 7;
    }

    /// @notice Get color for a pixel type. Body, torso, claw each have independent colors.
    function _getColor(uint8 pixelType, uint256 tokenId) internal view returns (string memory) {
        (uint256 bgIdx, uint256 bodyIdx, uint256 torsoIdx, uint256 clawIdx, uint256 eyeIdx) = _getTraits(tokenId);
        if (pixelType == 0) return PALETTE[bgIdx];
        if (pixelType == 1) return PALETTE[clawIdx];
        if (pixelType == 2) return PALETTE[eyeIdx];
        if (pixelType == 3) return PALETTE[torsoIdx];
        if (pixelType == 4) return PALETTE[bodyIdx];
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
