// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {OwnableBasic} from "@limitbreak/creator-token-standards/src/access/OwnableBasic.sol";
import {ERC721C} from "@limitbreak/creator-token-standards/src/erc721c/ERC721C.sol";
import {BasicRoyalties} from "@limitbreak/creator-token-standards/src/programmable-royalties/BasicRoyalties.sol";
import {ERC721OpenZeppelin} from "@limitbreak/creator-token-standards/src/token/erc721/ERC721OpenZeppelin.sol";

/// @title ClawPunks
/// @notice Fully onchain 20x20 pixel art NFT. Art matches index.html preview. ERC721C with 5% royalty (EIP-2981).
/// @dev Pixel map: 0=background, 1=body, 2=eye. 7 colors per part.
contract ClawPunks is OwnableBasic, ERC721C, BasicRoyalties {
    using Strings for uint256;

    uint256 public constant MAX_SUPPLY = 844;
    uint256 public constant GRID_SIZE = 20;
    uint256 public constant PIXEL = 20;
    uint256 public constant BATCH_SIZE = 210;

    uint256 private _nextTokenId;

    // Pixel maps: 0=background, 1=body, 2=eye. 20 rows x 20 cols, row-major.
    // Token 0-209: SEEKER, 210-419: BUILDER, 420-629: LEADER, 630-839: SAGE
    // Token 840-843: Raw numbers (SEEKER, BUILDER, LEADER, SAGE)
    string private constant PIXEL_MAP_SEEKER =
        "00000000000000000000"
        "00000000000000000000"
        "00000000100100000000"
        "00100000011000000100"
        "00101002211220010100"
        "00111001111110011100"
        "00111111111111111100"
        "00000011111111000000"
        "00000000111100000000"
        "00000000111100000000"
        "00000000111100000000"
        "00000000111100000000"
        "00000000111100000000"
        "00000000111100000000"
        "00000001111110000000"
        "00000001111110000000"
        "00000000111100000000"
        "00000000011000000000"
        "00000000000000000000"
        "00000000000000000000";

    string private constant PIXEL_MAP_BUILDER =
        "00000000000000000000"
        "00000011000011000000"
        "01000000100100000010"
        "01100000011000000110"
        "01101002211220010110"
        "01111001111110011110"
        "01111111111111111110"
        "00000011111111000000"
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

    string private constant PIXEL_MAP_LEADER =
        "00000000000000000000"
        "00001111000011110000"
        "01000000100100000010"
        "01100000011000000110"
        "01101002211220010110"
        "01111001111110011110"
        "01111111111111111110"
        "00111011111111011100"
        "00000011111111000000"
        "00000000111100000000"
        "00000001111110000000"
        "00000000111100000000"
        "00000001111110000000"
        "00000000111100000000"
        "00000001111110000000"
        "00000011111111000000"
        "00000001111110000000"
        "00000000111100000000"
        "00000000011000000000"
        "00000000000000000000";

    string private constant PIXEL_MAP_SAGE =
        "00000000000000000000"
        "01111111000011111110"
        "00000000100100000000"
        "00100000011000000100"
        "00101002211220010100"
        "00111002211220011100"
        "00111111111111111100"
        "00111011111111011100"
        "00000011111111000000"
        "00000000111100000000"
        "00000001111110000000"
        "00000000111100000000"
        "00000001111110000000"
        "00000000111100000000"
        "00000001111110000000"
        "00000011111111000000"
        "00000001111110000000"
        "00000000111100000000"
        "00000000011000000000"
        "00000000000000000000";

    // 7 colors (matches index.html)
    string[7] private PALETTE = [
        "#000000", // Black
        "#FFFFFF", // White
        "#E10600", // Red
        "#FFB000", // Yellow
        "#00A000", // Green
        "#0047FF", // Blue
        "#8B5A2B"  // Brown
    ];

    string[7] private PALETTE_NAMES = [
        "Black", "White", "Red", "Yellow", "Green", "Blue", "Brown"
    ];

    uint256 public constant ROYALTY_BPS = 500; // 5%

    constructor()
        ERC721OpenZeppelin("ClawPunks", "CLAWPUNKS")
        BasicRoyalties(msg.sender, uint96(ROYALTY_BPS))
    {}

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721C, ERC2981) returns (bool) {
        return ERC721C.supportsInterface(interfaceId) || ERC2981.supportsInterface(interfaceId);
    }

    /// @notice Set royalty receiver (owner only). Fee remains fixed at 5%.
    function setRoyaltyReceiver(address receiver) external onlyOwner {
        _setDefaultRoyalty(receiver, uint96(ROYALTY_BPS));
    }

    uint256 public constant PREMINT_BATCH_SIZE = 210;

    /// @notice Premint tokens to an address (owner only).
    function premint(address to, uint256 quantity) external onlyOwner {
        require(_nextTokenId + quantity <= MAX_SUPPLY, "Exceeds max supply");
        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = _nextTokenId;
            _nextTokenId++;
            _safeMint(to, tokenId);
        }
    }

    /// @notice Premint one batch (210 or remaining) to an address. Call 4 times to mint all 844 (owner only).
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

    /// @notice Derive trait indices from tokenId (0-6 each). Background, body, eyes.
    /// @dev Uses batch offset (tokenId % 210) so each batch has distinct combos. 7*6*5 = 210.
    function _getTraits(uint256 tokenId) internal pure returns (
        uint256 bgIdx, uint256 bodyIdx, uint256 eyeIdx
    ) {
        uint256 offset = tokenId % BATCH_SIZE;
        bgIdx = offset % 7;
        // Body: pick from 6 colors excluding bg
        uint256 bodySlot = (offset / 7) % 6;
        uint256 count = 0;
        for (uint256 c = 0; c < 7; c++) {
            if (c != bgIdx) {
                if (count == bodySlot) {
                    bodyIdx = c;
                    break;
                }
                count++;
            }
        }
        // Eye: pick from 5 colors excluding bg and body
        uint256 eyeSlot = (offset / 42) % 5; // 7*6 = 42
        count = 0;
        for (uint256 c = 0; c < 7; c++) {
            if (c != bgIdx && c != bodyIdx) {
                if (count == eyeSlot) {
                    eyeIdx = c;
                    break;
                }
                count++;
            }
        }
    }

    /// @notice Get stage name for tokenId. 0-209 Seeker, 210-419 Builder, 420-629 Leader, 630-839 Sage, 840-843 Raw.
    function _getStage(uint256 tokenId) internal pure returns (string memory) {
        if (tokenId >= 840) {
            if (tokenId == 840) return "Seeker";
            if (tokenId == 841) return "Builder";
            if (tokenId == 842) return "Leader";
            return "Sage";
        }
        uint256 batch = tokenId / BATCH_SIZE;
        if (batch == 0) return "Seeker";
        if (batch == 1) return "Builder";
        if (batch == 2) return "Leader";
        return "Sage";
    }

    /// @notice Get pixel map for tokenId. 0-209 SEEKER, 210-419 BUILDER, 420-629 LEADER, 630-839 SAGE, 840-843 raw maps.
    function _getPixelMap(uint256 tokenId) internal pure returns (string memory) {
        if (tokenId == 840) return PIXEL_MAP_SEEKER;
        if (tokenId == 841) return PIXEL_MAP_BUILDER;
        if (tokenId == 842) return PIXEL_MAP_LEADER;
        if (tokenId == 843) return PIXEL_MAP_SAGE;
        uint256 batch = tokenId / BATCH_SIZE;
        if (batch == 0) return PIXEL_MAP_SEEKER;
        if (batch == 1) return PIXEL_MAP_BUILDER;
        if (batch == 2) return PIXEL_MAP_LEADER;
        return PIXEL_MAP_SAGE;
    }

    /// @notice True if tokenId is one of the 4 raw-number tokens (840-843).
    function _isRawNumberToken(uint256 tokenId) internal pure returns (bool) {
        return tokenId >= 840;
    }

    /// @notice Get color for a pixel type. 0=background, 1=body, 2=eye.
    function _getColor(uint8 pixelType, uint256 tokenId) internal view returns (string memory) {
        (uint256 bgIdx, uint256 bodyIdx, uint256 eyeIdx) = _getTraits(tokenId);
        if (pixelType == 0) return PALETTE[bgIdx];
        if (pixelType == 1) return PALETTE[bodyIdx];
        if (pixelType == 2) return PALETTE[eyeIdx];
        return PALETTE[bgIdx];
    }

    /// @notice Build SVG: colored squares for 0-839, raw digits for 840-843.
    function _buildSVG(uint256 tokenId) internal view returns (string memory) {
        if (_isRawNumberToken(tokenId)) {
            return _buildSVGAsNumbers(_getPixelMap(tokenId));
        }
        return _buildSVGColored(tokenId);
    }

    /// @notice Build SVG with colored squares (matches color-picker).
    function _buildSVGColored(uint256 tokenId) internal view returns (string memory) {
        bytes memory map = bytes(_getPixelMap(tokenId));
        uint256 w = GRID_SIZE * PIXEL;
        uint256 h = GRID_SIZE * PIXEL;

        string memory rects;
        for (uint256 y = 0; y < GRID_SIZE; y++) {
            for (uint256 x = 0; x < GRID_SIZE; x++) {
                uint256 idx = y * GRID_SIZE + x;
                uint8 c = uint8(map[idx]) - 48;
                string memory fill = _getColor(c, tokenId);
                uint256 px = x * PIXEL;
                uint256 py = y * PIXEL;
                rects = string(abi.encodePacked(
                    rects,
                    '<rect x="', px.toString(), '" y="', py.toString(),
                    '" width="', PIXEL.toString(), '" height="', PIXEL.toString(),
                    '" fill="', fill, '" stroke="#cccccc" stroke-width="0.5"/>'
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

    /// @notice Build SVG with digits 0,1,2 as text (no color modification). For tokens 840-843.
    function _buildSVGAsNumbers(string memory pixelMap) internal pure returns (string memory) {
        bytes memory map = bytes(pixelMap);
        uint256 w = GRID_SIZE * PIXEL;
        uint256 h = GRID_SIZE * PIXEL;

        string memory texts;
        for (uint256 y = 0; y < GRID_SIZE; y++) {
            for (uint256 x = 0; x < GRID_SIZE; x++) {
                uint256 idx = y * GRID_SIZE + x;
                uint8 c = uint8(map[idx]) - 48;
                uint256 px = x * PIXEL + (PIXEL / 2);
                uint256 py = y * PIXEL + (PIXEL * 3 / 4);
                string memory char = c == 0 ? "0" : (c == 1 ? "1" : "2");
                texts = string(abi.encodePacked(
                    texts,
                    '<text x="', px.toString(), '" y="', py.toString(),
                    '" font-family="monospace" font-size="14" fill="#000000" text-anchor="middle">', char, '</text>'
                ));
            }
        }

        return string(abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" width="', w.toString(), '" height="', h.toString(),
            '" viewBox="0 0 ', w.toString(), ' ', h.toString(), '">',
            '<rect width="', w.toString(), '" height="', h.toString(), '" fill="#ffffff"/>',
            texts,
            '</svg>'
        ));
    }

    /// @notice Returns base64-encoded data URI with fully onchain SVG.
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        ownerOf(tokenId); // reverts if token does not exist

        string memory svg = _buildSVG(tokenId);
        string memory imageBase64 = Base64.encode(bytes(svg));
        string memory attrs;
        if (_isRawNumberToken(tokenId)) {
            attrs = string(abi.encodePacked(
                '{"trait_type":"Background","value":"Raw"}',
                ',{"trait_type":"Body","value":"Raw"}',
                ',{"trait_type":"Eyes","value":"Raw"}',
                ',{"trait_type":"Stage","value":"', _getStage(tokenId), '"}'
            ));
        } else {
            (uint256 bgIdx, uint256 bodyIdx, uint256 eyeIdx) = _getTraits(tokenId);
            attrs = string(abi.encodePacked(
                '{"trait_type":"Background","value":"', PALETTE_NAMES[bgIdx], '"}',
                ',{"trait_type":"Body","value":"', PALETTE_NAMES[bodyIdx], '"}',
                ',{"trait_type":"Eyes","value":"', PALETTE_NAMES[eyeIdx], '"}',
                ',{"trait_type":"Stage","value":"', _getStage(tokenId), '"}'
            ));
        }
        string memory json = Base64.encode(bytes(string(abi.encodePacked(
            '{"name":"ClawPunk #', tokenId.toString(),
            '","description":"The First Agent NFT."',
            ',"image":"data:image/svg+xml;base64,', imageBase64, '"',
            ',"attributes":[', attrs, ']}'
        ))));

        return string(abi.encodePacked("data:application/json;base64,", json));
    }
}
