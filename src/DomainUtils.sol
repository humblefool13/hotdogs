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

library DomainUtils {
    /**
     * @notice Validates if TLD is valid (3-10 lowercase letters only)
     * @param tld TLD to validate
     * @return True if valid TLD
     */
    function isValidTLD(string memory tld) external pure returns (bool) {
        bytes memory tldBytes = bytes(tld);
        if (tldBytes.length < 3 || tldBytes.length > 10) {
            return false;
        }

        for (uint i = 0; i < tldBytes.length; i++) {
            bytes1 char = tldBytes[i];
            // Only allow lowercase letters (a-z)
            if (!(char >= 0x61 && char <= 0x7A)) {
                return false;
            }
        }
        return true;
    }

    /**
     * @notice Validates if domain name is valid (3-10 lowercase letters, numbers, hyphens with restrictions)
     * @param name Domain name to validate
     * @return True if valid domain name
     */
    function isValidDomainName(
        string memory name
    ) external pure returns (bool) {
        bytes memory nameBytes = bytes(name);
        if (nameBytes.length < 3 || nameBytes.length > 10) {
            return false;
        }
        bool hyphen = false;
        for (uint i = 0; i < nameBytes.length; i++) {
            bytes1 char = nameBytes[i];

            // Check for leading hyphen
            if (i == 0 && char == 0x2D) return false;
            // Check for trailing hyphen
            if (i == nameBytes.length - 1 && char == 0x2D) return false;
            // Check for multiple hyphens
            if (char == 0x2D) {
                if (hyphen) return false;
                hyphen = true;
            } else if (
                // Allow lowercase letters (a-z)
                !(char >= 0x61 && char <= 0x7A) &&
                // Allow numbers (0-9)
                !(char >= 0x30 && char <= 0x39)
            ) {
                return false;
            }
        }
        return true;
    }
}
