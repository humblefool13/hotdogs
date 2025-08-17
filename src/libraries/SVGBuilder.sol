// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./DomainUtils.sol";

/**
 * @title SVGBuilder
 * @dev Library for building SVG graphics for domain NFTs
 */
library SVGBuilder {
    using DomainUtils for string;

    /// @notice Builds the complete SVG for a domain NFT
    function buildSVG(
        string memory fullDomain
    ) internal pure returns (string memory) {
        // Split domain into name and TLD
        string[] memory parts = DomainUtils.splitDomain(fullDomain);
        string memory domainName = parts[0];
        string memory tld = parts[1];

        return
            string(
                abi.encodePacked(
                    '<?xml version="1.0" encoding="UTF-8"?>',
                    '<svg id="katman_1" xmlns="http://www.w3.org/2000/svg" version="1.1" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 270 270">',
                    "<!-- Generator: Adobe Illustrator 29.5.1, SVG Export Plug-In . SVG Version: 2.1.0 Build 141)  -->",
                    "<defs>",
                    "<style>",
                    ".st0, .st1 { fill: #1a0f0e; }",
                    ".st0, .st2 { font-family: Arial-BoldMT, Arial; font-size: 32px; font-weight: 700; isolation: isolate; }",
                    ".st3 { fill: #ee3d5f; }",
                    ".st4, .st2 { fill: #fff; }",
                    ".st5 { fill: #85203a; }",
                    ".st6 { fill: #e67e59; }",
                    ".st7 { fill: #5c222f; }",
                    ".st8 { fill: url(#Adsiz_degrade_11); }",
                    ".st9 { fill: #f9b082; }",
                    ".st10 { fill: #f27a6e; }",
                    ".st11 { fill: #f7f9f3; }",
                    ".st12 { fill: #99493e; }",
                    "</style>",
                    '<linearGradient id="Adsiz_degrade_11" data-name="Adsiz degrade 11" x1="217" y1="-17.9" x2="-37.5" y2="456.6" gradientTransform="translate(0 269.9) scale(1 -1)" gradientUnits="userSpaceOnUse">',
                    '<stop offset="0" stop-color="#00d870"/>',
                    '<stop offset=".4" stop-color="#00c767"/>',
                    '<stop offset="1" stop-color="#00a757"/>',
                    "</linearGradient>",
                    "</defs>",
                    '<rect class="st8" y="0" width="270" height="270"/>',
                    '<text class="st0" transform="translate(32.5 200)"><tspan x="0" y="0">',
                    domainName,
                    "</tspan></text>",
                    "<g>",
                    '<rect class="st1" x="63.4" y="73.7" width="5.2" height="2.6"/>',
                    '<polygon class="st3" points="66.1 71.1 66.1 68.5 63.4 68.5 63.4 73.7 68.7 73.7 68.7 71.1 66.1 71.1"/>',
                    '<rect class="st1" x="39.9" y="71.1" width="5.2" height="2.6"/>',
                    '<rect class="st1" x="73.9" y="68.5" width="5.2" height="2.6"/>',
                    '<rect class="st1" x="68.7" y="68.5" width="2.6" height="5.2"/>',
                    '<rect class="st10" x="66.1" y="68.5" width="2.6" height="2.6"/>',
                    '<polygon class="st1" points="63.4 68.5 55.6 68.5 55.6 71.1 60.8 71.1 60.8 73.7 63.4 73.7 63.4 68.5"/>',
                    '<rect class="st1" x="45.1" y="68.5" width="2.6" height="2.6"/>',
                    '<rect class="st1" x="37.2" y="68.5" width="2.6" height="2.6"/>',
                    '<rect class="st1" x="71.3" y="65.8" width="2.6" height="2.6"/>',
                    '<rect class="st12" x="68.7" y="65.8" width="2.6" height="2.6"/>',
                    '<rect class="st5" x="60.8" y="65.8" width="5.2" height="2.6"/>',
                    '<polygon class="st6" points="60.8 68.5 60.8 63.2 68.7 63.2 68.7 65.8 71.3 65.8 71.3 63.2 73.9 63.2 73.9 55.4 71.3 55.4 71.3 58 68.7 58 68.7 60.6 60.8 60.6 60.8 58 55.6 58 55.6 60.6 53 60.6 53 65.8 55.6 65.8 55.6 68.5 60.8 68.5"/>',
                    '<rect class="st1" x="53" y="65.8" width="2.6" height="2.6"/>',
                    '<rect class="st12" x="71.3" y="63.2" width="2.6" height="2.6"/>',
                    '<polygon class="st1" points="60.8 63.2 60.8 65.8 66.1 65.8 66.1 68.5 68.7 68.5 68.7 63.2 60.8 63.2"/>',
                    '<rect class="st7" x="50.3" y="63.2" width="2.6" height="2.6"/>',
                    '<rect class="st1" x="47.7" y="63.2" width="2.6" height="5.2"/>',
                    '<polygon class="st12" points="47.7 63.2 39.9 63.2 39.9 58 37.2 58 37.2 47.5 34.6 47.5 34.6 63.2 37.2 63.2 37.2 68.5 39.9 68.5 39.9 71.1 45.1 71.1 45.1 68.5 47.7 68.5 47.7 63.2"/>',
                    '<rect class="st1" x="34.6" y="63.2" width="2.6" height="5.2"/>',
                    '<rect class="st7" x="47.7" y="60.6" width="2.6" height="2.6"/>',
                    '<rect class="st1" x="32" y="47.5" width="2.6" height="15.7"/>',
                    '<polygon class="st12" points="76.5 65.8 73.9 65.8 73.9 68.5 79.2 68.5 79.2 58 76.5 58 76.5 65.8"/>',
                    '<rect class="st1" x="45.1" y="58" width="2.6" height="5.2"/>',
                    '<rect class="st12" x="68.7" y="55.4" width="2.6" height="2.6"/>',
                    '<rect class="st7" x="66.1" y="55.4" width="2.6" height="2.6"/>',
                    '<polygon class="st1" points="66.1 55.4 60.8 55.4 60.8 60.6 68.7 60.6 68.7 58 66.1 58 66.1 55.4"/>',
                    '<rect class="st9" x="60.8" y="52.7" width="5.2" height="2.6"/>',
                    '<rect class="st1" x="42.5" y="44.9" width="2.6" height="13.1"/>',
                    '<rect class="st1" x="73.9" y="47.5" width="2.6" height="18.3"/>',
                    '<rect class="st4" x="66.1" y="47.5" width="2.6" height="5.2"/>',
                    '<rect class="st4" x="53" y="47.5" width="2.6" height="5.2"/>',
                    '<rect class="st1" x="79.2" y="47.5" width="2.6" height="21"/>',
                    '<rect class="st6" x="76.5" y="47.5" width="2.6" height="10.5"/>',
                    '<rect class="st12" x="71.3" y="47.5" width="2.6" height="7.9"/>',
                    '<polygon class="st1" points="68.7 52.7 66.1 52.7 66.1 55.4 71.3 55.4 71.3 47.5 73.9 47.5 73.9 42.3 71.3 42.3 71.3 44.9 66.1 44.9 66.1 47.5 68.7 47.5 68.7 52.7"/>',
                    '<rect class="st7" x="50.3" y="47.5" width="2.6" height="5.2"/>',
                    '<rect class="st1" x="76.5" y="42.3" width="2.6" height="5.2"/>',
                    '<polygon class="st1" points="55.6 47.5 55.6 52.7 53 52.7 53 55.4 58.2 55.4 58.2 44.9 53 44.9 53 47.5 55.6 47.5"/>',
                    '<polygon class="st6" points="37.2 58 39.9 58 39.9 63.2 45.1 63.2 45.1 58 42.5 58 42.5 44.9 45.1 44.9 45.1 39.6 39.9 39.6 39.9 42.3 37.2 42.3 37.2 58"/>',
                    '<rect class="st1" x="34.6" y="42.3" width="2.6" height="5.2"/>',
                    '<rect class="st12" x="73.9" y="42.3" width="2.6" height="2.6"/>',
                    '<rect class="st1" x="45.1" y="42.3" width="2.6" height="2.6"/>',
                    '<rect class="st1" x="73.9" y="39.6" width="2.6" height="2.6"/>',
                    '<rect class="st12" x="71.3" y="39.6" width="2.6" height="2.6"/>',
                    '<rect class="st1" x="68.7" y="39.6" width="2.6" height="2.6"/>',
                    '<rect class="st12" x="60.8" y="37" width="2.6" height="5.2"/>',
                    '<rect class="st7" x="47.7" y="39.6" width="2.6" height="2.6"/>',
                    '<rect class="st1" x="37.2" y="39.6" width="2.6" height="2.6"/>',
                    '<rect class="st1" x="71.3" y="37" width="2.6" height="2.6"/>',
                    '<polygon class="st12" points="45.1 39.6 45.1 42.3 47.7 42.3 47.7 39.6 50.3 39.6 50.3 42.3 47.7 42.3 47.7 44.9 45.1 44.9 45.1 58 47.7 58 47.7 60.6 50.3 60.6 50.3 63.2 53 63.2 53 60.6 55.6 60.6 55.6 58 60.8 58 60.8 52.7 66.1 52.7 66.1 47.5 58.2 47.5 58.2 55.4 53 55.4 53 52.7 50.3 52.7 50.3 47.5 53 47.5 53 39.6 55.6 39.6 55.6 37 58.2 37 58.2 34.4 47.7 34.4 47.7 37 42.5 37 42.5 39.6 45.1 39.6"/>',
                    '<rect class="st1" x="39.9" y="37" width="2.6" height="2.6"/>',
                    '<rect class="st1" x="66.1" y="34.4" width="5.2" height="2.6"/>',
                    '<polygon class="st6" points="60.8 34.4 60.8 37 63.4 37 63.4 42.3 60.8 42.3 60.8 37 55.6 37 55.6 39.6 53 39.6 53 44.9 58.2 44.9 58.2 47.5 66.1 47.5 66.1 44.9 71.3 44.9 71.3 42.3 68.7 42.3 68.7 39.6 71.3 39.6 71.3 37 66.1 37 66.1 34.4 60.8 34.4"/>',
                    '<rect class="st7" x="58.2" y="34.4" width="2.6" height="2.6"/>',
                    '<rect class="st1" x="42.5" y="34.4" width="5.2" height="2.6"/>',
                    '<rect class="st1" x="47.7" y="31.8" width="18.3" height="2.6"/>',
                    "</g>",
                    '<text class="st2" transform="translate(33.3 237.9)"><tspan x="0" y="0">.',
                    tld,
                    "</tspan></text>",
                    "<g>",
                    '<path class="st11" d="M225.9,61.5l9.6,9.6-4.5,4.5-9.6-9.6c-.8-.8-1.9-1.3-3.1-1.3s-2.2.4-3.1,1.3l-9.6,9.6-4.5-4.5,9.6-9.6h15.1Z"/>',
                    '<path class="st11" d="M227.5,58.7l13.1,3.5,1.6-6.2-13.1-3.5c-1.1-.3-2-1-2.6-2-.6-1-.7-2.2-.4-3.3l3.5-13.1-6.1-1.6-3.5,13.1,7.5,13.1h0Z"/>',
                    '<path class="st11" d="M209.2,58.7l-13.1,3.5-1.6-6.2,13.1-3.5c1.1-.3,2-1,2.6-2,.6-1,.7-2.2.4-3.3l-3.5-13.1,6.1-1.6,3.5,13.1-7.5,13.1h0Z"/>',
                    "</g>",
                    "</svg>"
                )
            );
    }
}
