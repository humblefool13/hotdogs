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
     * @param svg SVG string
     * @param expiration Domain expiration timestamp
     * @param registrationDate Domain registration timestamp
     * @param renewalCount Number of renewals
     * @return Base64 encoded token URI
     */
    function buildTokenURI(
        string memory name,
        string memory tld,
        string memory svg,
        uint256 expiration,
        uint256 registrationDate,
        uint256 renewalCount
    ) external pure returns (string memory) {
        string memory fullDomain = string(abi.encodePacked(name, ".", tld));

        string memory imageData = Base64.encode(bytes(svg));

        // Build metadata JSON
        string memory json = Base64.encode(
            bytes(
                string(
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
                )
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    function _toUpper(
        string memory input
    ) internal pure returns (string memory) {
        bytes memory b = bytes(input);
        for (uint i = 0; i < b.length; i++) {
            bytes1 char = b[i];
            if (char >= 0x61 && char <= 0x7A) {
                b[i] = bytes1(uint8(char) - 32);
            }
        }
        return string(b);
    }

    function _toLower(
        string memory input
    ) internal pure returns (string memory) {
        bytes memory b = bytes(input);
        for (uint i = 0; i < b.length; i++) {
            bytes1 char = b[i];
            if (char >= 0x41 && char <= 0x5A) {
                b[i] = bytes1(uint8(char) + 32);
            }
        }
        return string(b);
    }
}
