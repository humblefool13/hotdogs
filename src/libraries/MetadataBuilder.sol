// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./DomainUtils.sol";

/**
 * @title MetadataBuilder
 * @dev Library for building JSON metadata for domain NFTs
 */
library MetadataBuilder {
    using DomainUtils for string;
    using Strings for uint256;

    /// @notice Builds the complete JSON metadata for a domain NFT
    function buildMetadata(
        string memory fullDomain,
        string memory statusText,
        uint256 expiration,
        string memory svg
    ) internal pure returns (string memory) {
        uint256 nameLength = DomainUtils.getDomainNameLength(fullDomain);

        return
            Base64.encode(
                bytes(
                    abi.encodePacked(
                        '{"name":"',
                        fullDomain,
                        '", "description":"HotDogs Domain Name Service - Decentralized domain ownership on Abstract Chain", ',
                        '"image":"data:image/svg+xml;base64,',
                        Base64.encode(bytes(svg)),
                        '", "attributes":[',
                        '{"trait_type":"Domain","value":"',
                        fullDomain,
                        '"},',
                        '{"trait_type":"Status","value":"',
                        statusText,
                        '"},',
                        '{"trait_type":"Expiration","value":"',
                        expiration.toString(),
                        '"},',
                        '{"trait_type":"Length","value":"',
                        nameLength.toString(),
                        ' characters"}]}'
                    )
                )
            );
    }
}
