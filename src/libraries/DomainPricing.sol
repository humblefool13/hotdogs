// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./DomainUtils.sol";

/**
 * @title DomainPricing
 * @dev Library for domain pricing calculations
 */
library DomainPricing {
    using DomainUtils for string;

    /// @notice Domain pricing tiers based on name length - shorter names cost more
    uint256 public constant PRICE_3_CHAR = 0.012 ether; // Premium pricing for rare 3-char domains
    uint256 public constant PRICE_4_CHAR = 0.01 ether; // Standard pricing for 4-char domains
    uint256 public constant PRICE_5_CHAR = 0.008 ether; // Reduced pricing for 5-char domains
    uint256 public constant PRICE_6_CHAR = 0.006 ether; // Budget pricing for 6-char domains
    uint256 public constant PRICE_7_PLUS = 0.004 ether; // Economy pricing for longer domains

    /// @notice Maximum registration period
    uint256 public constant MAX_REGISTRATION_YEARS = 10;

    /// @notice Gets the price for a domain based on its name length
    function getDomainPrice(
        string memory _fullDomain
    ) internal pure returns (uint256) {
        string[] memory parts = DomainUtils.splitDomain(_fullDomain);
        if (parts.length != 2) revert("InvalidDomainFormat");

        uint256 nameLength = bytes(parts[0]).length;
        if (nameLength < DomainUtils.MIN_DOMAIN_LENGTH)
            revert("DomainNameTooShort");

        if (nameLength == 3) return PRICE_3_CHAR;
        if (nameLength == 4) return PRICE_4_CHAR;
        if (nameLength == 5) return PRICE_5_CHAR;
        if (nameLength == 6) return PRICE_6_CHAR;
        return PRICE_7_PLUS;
    }

    /// @notice Calculates the total price for domain registration
    function calculateTotalPrice(
        string memory _fullDomain,
        uint256 _years
    ) internal pure returns (uint256) {
        if (_years == 0 || _years > MAX_REGISTRATION_YEARS) {
            revert("InvalidRegistrationPeriod");
        }
        return getDomainPrice(_fullDomain) * _years;
    }
}
