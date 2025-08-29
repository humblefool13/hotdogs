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

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "./SVGLibrary.sol";

/**
 * @title TokenURILibrary
 * @notice Generates token URIs for domain NFTs
 * @dev Library contract to reduce main contract size
 */
library TokenURILibrary {
    using Strings for uint256;

    /**
     * @notice Generates token URI for a domain NFT
     * @param name Domain name (without TLD)
     * @param tld Top-level domain
     * @param svgLibrary Address of SVG library contract
     * @param expiration Domain expiration timestamp
     * @param registrationDate Domain registration timestamp
     * @param renewalCount Number of renewals
     * @return Base64 encoded token URI
     */
    function buildTokenURI(
        string memory name,
        string memory tld,
        address svgLibrary,
        uint256 expiration,
        uint256 registrationDate,
        uint256 renewalCount
    ) external pure returns (string memory) {
        string memory fullDomain = string(abi.encodePacked(name, ".", tld));

        // Generate SVG and encode to base64
        string memory svg = SVGLibrary(svgLibrary).generateSVG(name, tld);
        string memory imageData = Base64.encode(bytes(svg));

        // Build metadata JSON
        string memory json = string(
            abi.encodePacked(
                '{"name":"',
                fullDomain,
                '",',
                '"description":"A domain on the HotDogs Naming Service.",',
                '"image":"data:image/svg+xml;base64,',
                imageData,
                '",',
                '"external_url":"https://hotdogs.wtf",',
                '"attributes":[',
                '{"trait_type":"TLD","value":"',
                tld,
                '"},',
                '{"trait_type":"Name Length","value":"',
                bytes(name).length.toString(),
                '"},',
                '{"display_type":"date","trait_type":"Registration Date","value":',
                registrationDate.toString(),
                "},",
                '{"display_type":"date","trait_type":"Expiration Date","value":',
                expiration.toString(),
                "},",
                '{"display_type":"number","trait_type":"Renewal Count","value":',
                renewalCount.toString(),
                "}",
                "]",
                "}"
            )
        );

        return json;
    }
}
