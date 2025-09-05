// SPDX-License-Identifier: MIT
/*
 _                        _      _         __                _  _  _____ 
| |__   _   _  _ __ ___  | |__  | |  ___  / _|  ___    ___  | |/ ||___ / 
| '_ \ | | | || '_ ` _ \ | '_ \ | | / _ \| |_  / _ \  / _ \ | || |  |_ \ 
| | | || |_| || | | | | || |_) || ||  __/|  _|| (_) || (_) || || | ___) |
|_| |_| \__,_||_| |_| |_||_.__/ |_| \___||_|   \___/  \___/ |_||_||____/ 
                                                                         
https://t.me/humblefool13    
                                                                  
*/

pragma solidity ^0.8.20;

/**
 * @title SVGLibrary
 * @notice Generates SVG images for domain NFTs
 * @dev Deployed once and shared across all TLD contracts
 */
contract SVGLibrary {
    /**
     * @notice Generates SVG for a domain NFT
     * @param name Domain name
     * @param tld Top-level domain
     * @return SVG markup string
     */
    function generateSVG(
        string memory name,
        string memory tld
    ) external pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '<svg id="katman_1" xmlns="http://www.w3.org/2000/svg" version="1.1" viewBox="0 0 270 270">',
                    "<defs>",
                    '<linearGradient id="xd_degrade_11" data-name="xd degrade 11" x1="217" y1="-17.9" x2="-37.5" y2="456.6" gradientTransform="matrix(1 0 0 -1 0 269.9)" gradientUnits="userSpaceOnUse">',
                    '<stop offset="0" stop-color="#00d870"/>',
                    '<stop offset=".4" stop-color="#00c767"/>',
                    '<stop offset="1" stop-color="#00a757"/>',
                    "</linearGradient>",
                    "<style>",
                    ".st1{fill:#1a0f0e}.st6{fill:#e67e59}.st7{fill:#5c222f}.st12{fill:#99493e}",
                    "</style>",
                    "</defs>",
                    '<path style="fill:url(#xd_degrade_11)" d="M0 0h270v270H0z"/>',
                    '<text transform="translate(32.5 200)" style="fill:#1a0f0e;font-family:Arial-BoldMT,Arial;font-size:32px;font-weight:700;isolation:isolate"><tspan x="0" y="0">',
                    name,
                    "</tspan></text>",
                    '<path class="st1" d="M63.4 73.7h5.2v2.6h-5.2z"/>',
                    '<path style="fill:#ee3d5f" d="M66.1 71.1v-2.6h-2.7v5.2h5.3v-2.6z"/>',
                    '<path class="st1" d="M39.9 71.1h5.2v2.6h-5.2zm34-2.6h5.2v2.6h-5.2zm-5.2 0h2.6v5.2h-2.6z"/>',
                    '<path style="fill:#f27a6e" d="M66.1 68.5h2.6v2.6h-2.6z"/>',
                    '<path class="st1" d="M63.4 68.5h-7.8v2.6h5.2v2.6h2.6zm-18.3 0h2.6v2.6h-2.6zm-7.9 0h2.6v2.6h-2.6zm34.1-2.7h2.6v2.6h-2.6z"/>',
                    '<path class="st12" d="M68.7 65.8h2.6v2.6h-2.6z"/>',
                    '<path style="fill:#85203a" d="M60.8 65.8H66v2.6h-5.2z"/>',
                    '<path class="st6" d="M60.8 68.5v-5.3h7.9v2.6h2.6v-2.6h2.6v-7.8h-2.6V58h-2.6v2.6h-7.9V58h-5.2v2.6H53v5.2h2.6v2.7z"/>',
                    '<path class="st1" d="M53 65.8h2.6v2.6H53z"/>',
                    '<path class="st12" d="M71.3 63.2h2.6v2.6h-2.6z"/>',
                    '<path class="st1" d="M60.8 63.2v2.6h5.3v2.7h2.6v-5.3z"/>',
                    '<path class="st7" d="M50.3 63.2h2.6v2.6h-2.6z"/>',
                    '<path class="st1" d="M47.7 63.2h2.6v5.2h-2.6z"/>',
                    '<path class="st12" d="M47.7 63.2h-7.8V58h-2.7V47.5h-2.6v15.7h2.6v5.3h2.7v2.6h5.2v-2.6h2.6z"/>',
                    '<path class="st1" d="M34.6 63.2h2.6v5.2h-2.6z"/>',
                    '<path class="st7" d="M47.7 60.6h2.6v2.6h-2.6z"/>',
                    '<path class="st1" d="M32 47.5h2.6v15.7H32z"/>',
                    '<path class="st12" d="M76.5 65.8h-2.6v2.7h5.3V58h-2.7z"/>',
                    '<path class="st1" d="M45.1 58h2.6v5.2h-2.6z"/>',
                    '<path class="st12" d="M68.7 55.4h2.6V58h-2.6z"/>',
                    '<path class="st7" d="M66.1 55.4h2.6V58h-2.6z"/>',
                    '<path class="st1" d="M66.1 55.4h-5.3v5.2h7.9V58h-2.6z"/>',
                    '<path style="fill:#f9b082" d="M60.8 52.7H66v2.6h-5.2z"/>',
                    '<path class="st1" d="M42.5 44.9h2.6V58h-2.6zm31.4 2.6h2.6v18.3h-2.6z"/>',
                    '<path d="M66.1 47.5h2.6v5.2h-2.6zm-13.1 0h2.6v5.2H53z" style="fill:#fff"/>',
                    '<path class="st1" d="M79.2 47.5h2.6v21h-2.6z"/>',
                    '<path class="st6" d="M76.5 47.5h2.6V58h-2.6z"/>',
                    '<path class="st12" d="M71.3 47.5h2.6v7.9h-2.6z"/>',
                    '<path class="st1" d="M68.7 52.7h-2.6v2.7h5.2v-7.9h2.6v-5.2h-2.6v2.6h-5.2v2.6h2.6z"/>',
                    '<path class="st7" d="M50.3 47.5h2.6v5.2h-2.6z"/>',
                    '<path class="st1" d="M76.5 42.3h2.6v5.2h-2.6zm-20.9 5.2v5.2H53v2.7h5.2V44.9H53v2.6z"/>',
                    '<path class="st6" d="M37.2 58h2.7v5.2h5.2V58h-2.6V44.9h2.6v-5.3h-5.2v2.7h-2.7z"/>',
                    '<path class="st1" d="M34.6 42.3h2.6v5.2h-2.6z"/>',
                    '<path class="st12" d="M73.9 42.3h2.6v5.2h-2.6z"/>',
                    '<path class="st1" d="M45.1 42.3h2.6v2.6h-2.6zm28.8-2.7h2.6v2.6h-2.6z"/>',
                    '<path class="st12" d="M71.3 39.6h2.6v2.6h-2.6z"/>',
                    '<path class="st1" d="M68.7 39.6h2.6v2.6h-2.6z"/>',
                    '<path class="st12" d="M60.8 37h2.6v5.2h-2.6z"/>',
                    '<path class="st7" d="M47.7 39.6h2.6v2.6h-2.6z"/>',
                    '<path class="st1" d="M37.2 39.6h2.6v2.6h-2.6zM71.3 37h2.6v2.6h-2.6z"/>',
                    '<path class="st12" d="M45.1 39.6v2.7h2.6v-2.7h2.6v2.7h-2.6v2.6h-2.6V58h2.6v2.6h2.6v2.6H53v-2.6h2.6V58h5.2v-5.3h5.3v-5.2h-7.9v7.9H53v-2.7h-2.7v-5.2H53v-7.9h2.6V37h2.6v-2.6H47.7V37h-5.2v2.6z"/>',
                    '<path class="st1" d="M39.9 37h2.6v2.6h-2.6zm26.2-2.6h5.2V37h-5.2z"/>',
                    '<path class="st6" d="M60.8 34.4V37h2.6v5.3h-2.6V37h-5.2v2.6H53v5.3h5.2v2.6h7.9v-2.6h5.2v-2.6h-2.6v-2.7h2.6V37h-5.2v-2.6z"/>',
                    '<path class="st7" d="M58.2 34.4h2.6V37h-2.6z"/>',
                    '<path class="st1" d="M42.5 34.4h5.2V37h-5.2zm5.2-2.6H66v2.6H47.7z"/>',
                    '<text transform="translate(33.3 237.9)" style="font-family:Arial-BoldMT,Arial;font-size:32px;font-weight:700;isolation:isolate;fill:#fff"><tspan x="0" y="0">.',
                    tld,
                    "</tspan></text>",
                    '<path d="m225.9 61.5 9.6 9.6-4.5 4.5-9.6-9.6c-.8-.8-1.9-1.3-3.1-1.3s-2.2.4-3.1 1.3l-9.6 9.6-4.5-4.5 9.6-9.6h15.1Zm1.6-2.8 13.1 3.5 1.6-6.2-13.1-3.5c-1.1-.3-2-1-2.6-2s-.7-2.2-.4-3.3l3.5-13.1-6.1-1.6-3.5 13.1zm-18.3 0-13.1 3.5-1.6-6.2 13.1-3.5c1.1-.3 2-1 2.6-2s.7-2.2.4-3.3l-3.5-13.1 6.1-1.6 3.5 13.1z" style="fill:#f7f9f3"/>',
                    "</svg>"
                )
            );
    }
}
