// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title DomainUtils
 * @dev Library for domain validation and parsing utilities
 */
library DomainUtils {
    /// @notice Minimum domain name length
    uint256 public constant MIN_DOMAIN_LENGTH = 3;
    /// @notice Maximum domain name length
    uint256 public constant MAX_DOMAIN_LENGTH = 20;

    /// @notice Custom error for invalid domain structure
    error InvalidDomainStructure();

    /// @notice Validates domain format and characters
    function isValidDomainName(
        string memory _fullDomain
    ) internal pure returns (bool) {
        bytes memory domainBytes = bytes(_fullDomain);

        for (uint256 i = 0; i < domainBytes.length; i++) {
            bytes1 char = domainBytes[i];

            if (
                !(char >= 0x30 && char <= 0x39) && // 0-9
                !(char >= 0x41 && char <= 0x5A) && // A-Z
                !(char >= 0x61 && char <= 0x7A) && // a-z
                char != 0x2D && // hyphen
                char != 0x2E
            ) {
                return false;
            }
        }

        return true;
    }

    /// @notice Splits a domain into name and TLD parts
    function splitDomain(
        string memory _fullDomain
    ) internal pure returns (string[] memory) {
        bytes memory domainBytes = bytes(_fullDomain);
        uint256 dotCount = 0;

        // Count dots
        for (uint256 i = 0; i < domainBytes.length; i++) {
            if (domainBytes[i] == 0x2E) {
                // 0x2E is the dot character
                dotCount++;
            }
        }

        // Ensure exactly one dot (two parts)
        if (dotCount != 1) revert InvalidDomainStructure();

        string[] memory parts = new string[](2);
        uint256 dotIndex = 0;

        // Find the dot position
        for (uint256 i = 0; i < domainBytes.length; i++) {
            if (domainBytes[i] == 0x2E) {
                dotIndex = i;
                break;
            }
        }

        // Extract the two parts
        parts[0] = substring(_fullDomain, 0, dotIndex);
        parts[1] = substring(_fullDomain, dotIndex + 1, domainBytes.length);

        // Validate that neither part is empty
        if (bytes(parts[0]).length == 0 || bytes(parts[1]).length == 0) {
            revert InvalidDomainStructure();
        }

        return parts;
    }

    /// @notice Gets the length of the domain name part (before the dot)
    function getDomainNameLength(
        string memory _fullDomain
    ) internal pure returns (uint256) {
        bytes memory domainBytes = bytes(_fullDomain);
        for (uint256 i = 0; i < domainBytes.length; i++) {
            if (domainBytes[i] == 0x2E) {
                // 0x2E is the dot character
                return i;
            }
        }
        return domainBytes.length;
    }

    /// @notice Extracts a substring from a string
    function substring(
        string memory str,
        uint256 startIndex,
        uint256 endIndex
    ) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);

        // Bounds checking
        if (
            startIndex >= strBytes.length ||
            endIndex > strBytes.length ||
            startIndex >= endIndex
        ) {
            revert InvalidDomainStructure();
        }

        bytes memory result = new bytes(endIndex - startIndex);

        for (uint256 i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }

        return string(result);
    }

    /// @notice Converts string to lowercase for case-insensitive domain handling
    function toLowerCase(
        string memory _str
    ) internal pure returns (string memory) {
        bytes memory strBytes = bytes(_str);
        bytes memory result = new bytes(strBytes.length);

        for (uint256 i = 0; i < strBytes.length; i++) {
            bytes1 char = strBytes[i];
            if (char >= 0x41 && char <= 0x5A) {
                // A-Z
                result[i] = bytes1(uint8(char) + 32); // Convert to lowercase
            } else {
                result[i] = char;
            }
        }

        return string(result);
    }

    /// @notice Validates domain format and structure
    function validateDomainFormat(
        string memory _fullDomain
    ) internal pure returns (bool) {
        if (bytes(_fullDomain).length == 0) return false;

        // Validate domain format and characters
        if (!isValidDomainName(_fullDomain)) return false;

        string[] memory parts = splitDomain(_fullDomain);
        if (parts.length != 2) return false;

        uint256 nameLength = bytes(parts[0]).length;
        if (nameLength < MIN_DOMAIN_LENGTH || nameLength > MAX_DOMAIN_LENGTH)
            return false;

        return true;
    }
}
