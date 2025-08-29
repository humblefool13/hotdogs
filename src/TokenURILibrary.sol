// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "./SVGLibrary.sol";

/**
 * @title TokenURILibrary
 * @notice Library for generating token URIs for domain NFTs
 * @dev Helps reduce contract size by moving metadata generation logic to a library
 */
library TokenURILibrary {
    using Strings for uint256;

    /**
     * @notice Build token URI for a domain NFT
     * @param name Domain name
     * @param tld Top-level domain
     * @param svgLibrary SVG library contract address
     * @param expiration Domain expiration timestamp
     * @param registrationDate Domain registration timestamp
     * @param renewalCount Number of times domain was renewed
     * @return Token URI string
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

        // Generate SVG using the library
        string memory svg = SVGLibrary(svgLibrary).generateSVG(name, tld);
        string memory imageData = Base64.encode(bytes(svg));

        // Build concise metadata without redundant name repetitions
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
}
