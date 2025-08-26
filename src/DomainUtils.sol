//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

library DomainUtils {
    /**
     * @notice Extract TLD from full domain
     * @param domain Full domain (name.tld)
     * @return TLD string
     */
    function extractTLD(
        string memory domain
    ) external pure returns (string memory) {
        bytes memory domainBytes = bytes(domain);
        for (uint i = domainBytes.length - 1; i > 0; i--) {
            if (domainBytes[i] == 0x2E) {
                // dot character
                bytes memory tld = new bytes(domainBytes.length - i - 1);
                for (uint j = 0; j < tld.length; j++) {
                    tld[j] = domainBytes[i + j + 1];
                }
                return string(tld);
            }
        }
        return "";
    }

    /**
     * @notice Extract name from full domain
     * @param domain Full domain (name.tld)
     * @return Name string
     */
    function extractName(
        string memory domain
    ) external pure returns (string memory) {
        bytes memory domainBytes = bytes(domain);
        for (uint i = 0; i < domainBytes.length; i++) {
            if (domainBytes[i] == 0x2E) {
                // dot character
                bytes memory name = new bytes(i);
                for (uint j = 0; j < i; j++) {
                    name[j] = domainBytes[j];
                }
                return string(name);
            }
        }
        return "";
    }
}
