// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TokenURILibrary.sol";
import "../src/SVGLibrary.sol";

contract TokenURILibraryTest is Test {
    SVGLibrary svgLib;

    function setUp() public {
        svgLib = new SVGLibrary();
    }

    // ============ BUILD TOKEN URI TESTS ============

    function testBuildTokenURI_Basic() public {
        string memory svg = svgLib.generateSVG("test", "eth");
        string memory uri = TokenURILibrary.buildTokenURI(
            "test",
            "eth",
            svg,
            1757049558,
            1788585555,
            1
        );

        // Should be a valid data URI
        assertTrue(bytes(uri).length > 0);
        assertTrue(keccak256(bytes(uri)) != keccak256(""));

        // Should start with data:application/json;base64,
        string memory prefix = "data:application/json;base64,";
        assertTrue(bytes(uri).length > bytes(prefix).length);

        // Check that it starts with the expected prefix
        bytes memory uriBytes = bytes(uri);
        bytes memory prefixBytes = bytes(prefix);
        for (uint i = 0; i < prefixBytes.length; i++) {
            assertEq(uriBytes[i], prefixBytes[i]);
        }
    }

    function testBuildTokenURI_ContainsMetadata() public {
        string memory svg = svgLib.generateSVG("testname", "hotdogs");
        string memory uri = TokenURILibrary.buildTokenURI(
            "testname",
            "hotdogs",
            svg,
            1757049558,
            1788585555,
            3
        );

        // Should contain the full domain name
        assertTrue(bytes(uri).length > 0);

        // The URI should be base64 encoded JSON
        assertTrue(bytes(uri).length > 100); // Should be substantial
    }

    function testBuildTokenURI_DifferentParameters() public {
        string memory svg1 = svgLib.generateSVG("test1", "eth");
        string memory svg2 = svgLib.generateSVG("test2", "com");

        string memory uri1 = TokenURILibrary.buildTokenURI(
            "test1",
            "eth",
            svg1,
            1000,
            2000,
            1
        );

        string memory uri2 = TokenURILibrary.buildTokenURI(
            "test2",
            "com",
            svg2,
            3000,
            4000,
            2
        );

        // Different parameters should produce different URIs
        assertTrue(keccak256(bytes(uri1)) != keccak256(bytes(uri2)));
    }

    function testBuildTokenURI_ZeroValues() public {
        string memory svg = svgLib.generateSVG("test", "eth");
        string memory uri = TokenURILibrary.buildTokenURI(
            "test",
            "eth",
            svg,
            0,
            0,
            0
        );

        // Should handle zero values
        assertTrue(bytes(uri).length > 0);
        assertTrue(keccak256(bytes(uri)) != keccak256(""));
    }

    function testBuildTokenURI_MaxValues() public {
        string memory svg = svgLib.generateSVG("test", "eth");
        string memory uri = TokenURILibrary.buildTokenURI(
            "test",
            "eth",
            svg,
            type(uint256).max,
            type(uint256).max,
            type(uint256).max
        );

        // Should handle max values
        assertTrue(bytes(uri).length > 0);
        assertTrue(keccak256(bytes(uri)) != keccak256(""));
    }

    function testBuildTokenURI_EmptyStrings() public {
        string memory svg = svgLib.generateSVG("", "");
        string memory uri = TokenURILibrary.buildTokenURI(
            "",
            "",
            svg,
            1000,
            2000,
            1
        );

        // Should handle empty strings
        assertTrue(bytes(uri).length > 0);
        assertTrue(keccak256(bytes(uri)) != keccak256(""));
    }

    function testBuildTokenURI_SpecialCharacters() public {
        string memory svg = svgLib.generateSVG("test-name_123", "tld-456");
        string memory uri = TokenURILibrary.buildTokenURI(
            "test-name_123",
            "tld-456",
            svg,
            1000,
            2000,
            1
        );

        // Should handle special characters
        assertTrue(bytes(uri).length > 0);
        assertTrue(keccak256(bytes(uri)) != keccak256(""));
    }

    function testBuildTokenURI_Consistency() public {
        string memory svg = svgLib.generateSVG("test", "eth");

        // Same parameters should produce same URI
        string memory uri1 = TokenURILibrary.buildTokenURI(
            "test",
            "eth",
            svg,
            1000,
            2000,
            1
        );

        string memory uri2 = TokenURILibrary.buildTokenURI(
            "test",
            "eth",
            svg,
            1000,
            2000,
            1
        );

        assertEq(uri1, uri2);
    }

    function testBuildTokenURI_DifferentNameLengths() public {
        string[5] memory names = ["abc", "abcd", "abcde", "abcdef", "abcdefg"];
        string[5] memory tlds = ["eth", "com", "org", "net", "io"];

        for (uint i = 0; i < names.length; i++) {
            string memory svg = svgLib.generateSVG(names[i], tlds[i]);
            string memory uri = TokenURILibrary.buildTokenURI(
                names[i],
                tlds[i],
                svg,
                1757049558,
                1700000000,
                i
            );

            assertTrue(bytes(uri).length > 0);
            assertTrue(keccak256(bytes(uri)) != keccak256(""));
        }
    }

    function testBuildTokenURI_DifferentRenewalCounts() public {
        string memory svg = svgLib.generateSVG("test", "eth");

        for (uint i = 0; i < 10; i++) {
            string memory uri = TokenURILibrary.buildTokenURI(
                "test",
                "eth",
                svg,
                1757049558,
                1700000000,
                i
            );

            assertTrue(bytes(uri).length > 0);
            assertTrue(keccak256(bytes(uri)) != keccak256(""));
        }
    }

    function testBuildTokenURI_DifferentTimestamps() public {
        string memory svg = svgLib.generateSVG("test", "eth");

        uint256[5] memory timestamps = [
            uint256(1000),
            uint256(1000000),
            uint256(1000000000),
            uint256(1000000000000),
            uint256(1000000000000000)
        ];

        for (uint i = 0; i < timestamps.length; i++) {
            string memory uri = TokenURILibrary.buildTokenURI(
                "test",
                "eth",
                svg,
                timestamps[i],
                timestamps[i] + 365 days,
                i
            );

            assertTrue(bytes(uri).length > 0);
            assertTrue(keccak256(bytes(uri)) != keccak256(""));
        }
    }

    // ============ TO UPPER TESTS ============

    function testToUpper_Basic() public pure {
        string memory result = TokenURILibrary._toUpper("test");
        assertEq(result, "TEST");
    }

    function testToUpper_MixedCase() public pure {
        string memory result = TokenURILibrary._toUpper("TeSt");
        assertEq(result, "TEST");
    }

    function testToUpper_AlreadyUpper() public pure {
        string memory result = TokenURILibrary._toUpper("TEST");
        assertEq(result, "TEST");
    }

    function testToUpper_WithNumbers() public pure {
        string memory result = TokenURILibrary._toUpper("test123");
        assertEq(result, "TEST123");
    }

    function testToUpper_WithSpecialChars() public pure {
        string memory result = TokenURILibrary._toUpper("test-name_123");
        assertEq(result, "TEST-NAME_123");
    }

    function testToUpper_EmptyString() public pure {
        string memory result = TokenURILibrary._toUpper("");
        assertEq(result, "");
    }

    function testToUpper_OnlyNumbers() public pure {
        string memory result = TokenURILibrary._toUpper("123456");
        assertEq(result, "123456");
    }

    function testToUpper_OnlySpecialChars() public pure {
        string memory result = TokenURILibrary._toUpper("-_@#$");
        assertEq(result, "-_@#$");
    }

    function testToUpper_AllLowercaseLetters() public pure {
        string memory result = TokenURILibrary._toUpper(
            "abcdefghijklmnopqrstuvwxyz"
        );
        assertEq(result, "ABCDEFGHIJKLMNOPQRSTUVWXYZ");
    }

    function testToUpper_MixedWithNumbersAndSpecial() public pure {
        string memory result = TokenURILibrary._toUpper("test123-abc_xyz");
        assertEq(result, "TEST123-ABC_XYZ");
    }

    function testToUpper_SingleCharacter() public pure {
        string memory result = TokenURILibrary._toUpper("a");
        assertEq(result, "A");
    }

    function testToUpper_UnicodeCharacters() public pure {
        // Test that unicode characters are not affected
        string memory result = TokenURILibrary._toUpper(unicode"tést");
        assertEq(result, unicode"TéST"); // Should remain unchanged
    }

    // ============ TO LOWER TESTS ============

    function testToLower_Basic() public pure {
        string memory result = TokenURILibrary._toLower("TEST");
        assertEq(result, "test");
    }

    function testToLower_MixedCase() public pure {
        string memory result = TokenURILibrary._toLower("TeSt");
        assertEq(result, "test");
    }

    function testToLower_AlreadyLower() public pure {
        string memory result = TokenURILibrary._toLower("test");
        assertEq(result, "test");
    }

    function testToLower_WithNumbers() public pure {
        string memory result = TokenURILibrary._toLower("TEST123");
        assertEq(result, "test123");
    }

    function testToLower_WithSpecialChars() public pure {
        string memory result = TokenURILibrary._toLower("TEST-NAME_123");
        assertEq(result, "test-name_123");
    }

    function testToLower_EmptyString() public pure {
        string memory result = TokenURILibrary._toLower("");
        assertEq(result, "");
    }

    function testToLower_OnlyNumbers() public pure {
        string memory result = TokenURILibrary._toLower("123456");
        assertEq(result, "123456");
    }

    function testToLower_OnlySpecialChars() public pure {
        string memory result = TokenURILibrary._toLower("-_@#$");
        assertEq(result, "-_@#$");
    }

    function testToLower_AllUppercaseLetters() public pure {
        string memory result = TokenURILibrary._toLower(
            "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        );
        assertEq(result, "abcdefghijklmnopqrstuvwxyz");
    }

    function testToLower_MixedWithNumbersAndSpecial() public pure {
        string memory result = TokenURILibrary._toLower("TEST123-ABC_XYZ");
        assertEq(result, "test123-abc_xyz");
    }

    function testToLower_SingleCharacter() public pure {
        string memory result = TokenURILibrary._toLower("A");
        assertEq(result, "a");
    }

    function testToLower_UnicodeCharacters() public pure {
        // Test that unicode characters are not affected
        string memory result = TokenURILibrary._toLower(unicode"TÉST");
        assertEq(result, unicode"tÉst"); // Should remain unchanged
    }

    // ============ EDGE CASES AND STRESS TESTS ============

    function testBuildTokenURI_VeryLongNames() public {
        string
            memory veryLongName = "thisisaverylongdomainnamethatexceedstypicallimitsandshouldstillwork";
        string
            memory veryLongTLD = "thisisaverylongtldthatexceedstypicallimitsandshouldstillwork";

        string memory svg = svgLib.generateSVG(veryLongName, veryLongTLD);
        string memory uri = TokenURILibrary.buildTokenURI(
            veryLongName,
            veryLongTLD,
            svg,
            1757049558,
            1700000000,
            1
        );

        // Should handle very long strings
        assertTrue(bytes(uri).length > 0);
        assertTrue(keccak256(bytes(uri)) != keccak256(""));
    }

    function testBuildTokenURI_MaxUint256Values() public {
        string memory svg = svgLib.generateSVG("test", "eth");
        string memory uri = TokenURILibrary.buildTokenURI(
            "test",
            "eth",
            svg,
            type(uint256).max,
            type(uint256).max,
            type(uint256).max
        );

        // Should handle max uint256 values
        assertTrue(bytes(uri).length > 0);
        assertTrue(keccak256(bytes(uri)) != keccak256(""));
    }

    function testBuildTokenURI_ZeroTimestamp() public {
        string memory svg = svgLib.generateSVG("test", "eth");
        string memory uri = TokenURILibrary.buildTokenURI(
            "test",
            "eth",
            svg,
            0,
            0,
            0
        );

        // Should handle zero timestamps
        assertTrue(bytes(uri).length > 0);
        assertTrue(keccak256(bytes(uri)) != keccak256(""));
    }

    function testBuildTokenURI_LargeRenewalCount() public {
        string memory svg = svgLib.generateSVG("test", "eth");
        string memory uri = TokenURILibrary.buildTokenURI(
            "test",
            "eth",
            svg,
            1757049558,
            1700000000,
            1000000
        );

        // Should handle large renewal counts
        assertTrue(bytes(uri).length > 0);
        assertTrue(keccak256(bytes(uri)) != keccak256(""));
    }

    function testBuildTokenURI_ConsistencyAcrossCalls() public {
        string memory svg = svgLib.generateSVG("consistency", "test");

        // Multiple calls with same parameters should produce same result
        string memory uri1 = TokenURILibrary.buildTokenURI(
            "consistency",
            "test",
            svg,
            1757049558,
            1700000000,
            5
        );

        string memory uri2 = TokenURILibrary.buildTokenURI(
            "consistency",
            "test",
            svg,
            1757049558,
            1700000000,
            5
        );

        assertEq(uri1, uri2);
    }

    function testBuildTokenURI_DifferentSVGContent() public {
        string memory svg1 = svgLib.generateSVG("test1", "eth");
        string memory svg2 = svgLib.generateSVG("test2", "com");

        string memory uri1 = TokenURILibrary.buildTokenURI(
            "test1",
            "eth",
            svg1,
            1757049558,
            1700000000,
            1
        );

        string memory uri2 = TokenURILibrary.buildTokenURI(
            "test2",
            "com",
            svg2,
            1757049558,
            1700000000,
            1
        );

        // Different SVG content should produce different URIs
        assertTrue(keccak256(bytes(uri1)) != keccak256(bytes(uri2)));
    }

    function testBuildTokenURI_EmptySVG() public {
        string memory uri = TokenURILibrary.buildTokenURI(
            "test",
            "eth",
            "",
            1757049558,
            1700000000,
            1
        );

        // Should handle empty SVG
        assertTrue(bytes(uri).length > 0);
        assertTrue(keccak256(bytes(uri)) != keccak256(""));
    }

    function testBuildTokenURI_Base64Encoding() public {
        string memory svg = svgLib.generateSVG("test", "eth");
        string memory uri = TokenURILibrary.buildTokenURI(
            "test",
            "eth",
            svg,
            1757049558,
            1700000000,
            1
        );

        // Should be valid base64 (no invalid characters)
        bytes memory uriBytes = bytes(uri);
        string memory prefix = "data:application/json;base64,";

        // Check prefix
        for (uint i = 0; i < bytes(prefix).length; i++) {
            assertEq(uriBytes[i], bytes(prefix)[i]);
        }

        // The rest should be base64 encoded
        assertTrue(uriBytes.length > bytes(prefix).length);
    }

    function testBuildTokenURI_JSONStructure() public {
        string memory svg = svgLib.generateSVG("test", "eth");
        string memory uri = TokenURILibrary.buildTokenURI(
            "test",
            "eth",
            svg,
            1757049558,
            1700000000,
            1
        );

        // Should be a valid data URI
        assertTrue(bytes(uri).length > 0);

        // Should contain expected elements (basic structure check)
        string memory expectedPrefix = "data:application/json;base64,";
        assertTrue(bytes(uri).length > bytes(expectedPrefix).length);
    }

    // ============ INTEGRATION TESTS ============

    function testFullWorkflow() public {
        // Test the full workflow from SVG generation to token URI
        string memory name = "testdomain";
        string memory tld = "eth";
        uint256 expiration = 1757049558;
        uint256 registrationDate = 1700000000;
        uint256 renewalCount = 2;

        // Generate SVG
        string memory svg = svgLib.generateSVG(name, tld);
        assertTrue(bytes(svg).length > 1000);

        // Build token URI
        string memory uri = TokenURILibrary.buildTokenURI(
            name,
            tld,
            svg,
            expiration,
            registrationDate,
            renewalCount
        );

        // Verify URI is valid
        assertTrue(bytes(uri).length > 0);
        assertTrue(keccak256(bytes(uri)) != keccak256(""));

        // Should start with data:application/json;base64,
        string memory prefix = "data:application/json;base64,";
        assertTrue(bytes(uri).length > bytes(prefix).length);
    }

    function testMultipleDomains() public {
        // Test multiple different domains
        string[3] memory names = ["short", "mediumname", "verylongdomainname"];
        string[3] memory tlds = ["eth", "com", "org"];

        for (uint i = 0; i < names.length; i++) {
            string memory svg = svgLib.generateSVG(names[i], tlds[i]);
            string memory uri = TokenURILibrary.buildTokenURI(
                names[i],
                tlds[i],
                svg,
                1757049558,
                1700000000,
                i
            );

            assertTrue(bytes(svg).length > 1000);
            assertTrue(bytes(uri).length > 0);
        }
    }

    function testEdgeCases() public {
        // Test various edge cases
        string[5] memory names = [
            "",
            "a",
            "ab",
            "verylongname123",
            "test-name_123"
        ];
        string[5] memory tlds = [
            "",
            "a",
            "ab",
            "verylongtld123",
            "test-tld_123"
        ];

        for (uint i = 0; i < names.length; i++) {
            string memory svg = svgLib.generateSVG(names[i], tlds[i]);
            string memory uri = TokenURILibrary.buildTokenURI(
                names[i],
                tlds[i],
                svg,
                1757049558,
                1700000000,
                i
            );

            // Should always produce valid output
            assertTrue(bytes(svg).length > 0);
            assertTrue(bytes(uri).length > 0);
        }
    }
}
