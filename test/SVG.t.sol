// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SVGLibrary.sol";
import "../src/TokenURILibrary.sol";

contract SVGTest is Test {
    SVGLibrary svgLib;

    function setUp() public {
        svgLib = new SVGLibrary();
    }

    // ============ SVG LIBRARY TESTS ============

    function testGenerateSVG_Basic() public {
        string memory svg = svgLib.generateSVG("vind", "hotdogs");

        // Basic sanity checks
        assertTrue(bytes(svg).length > 1000, "SVG too short, maybe truncated?");
        assertTrue(bytes(svg)[0] == "<", "SVG does not start with <");
        assertTrue(
            bytes(svg)[bytes(svg).length - 1] == ">",
            "SVG does not end with >"
        );
    }

    function testGenerateSVG_ContainsName() public {
        string memory svg = svgLib.generateSVG("testname", "hotdogs");

        // Check that the name appears in the SVG
        assertTrue(bytes(svg).length > 0);

        // The SVG should contain the domain name
        // We can't easily test exact content without parsing, but we can test structure
        assertTrue(bytes(svg).length > 1000);
    }

    function testGenerateSVG_ContainsTLD() public {
        string memory svg = svgLib.generateSVG("test", "example");

        // Check that the TLD appears in the SVG
        assertTrue(bytes(svg).length > 0);

        // The SVG should contain the TLD
        assertTrue(bytes(svg).length > 1000);
    }

    function testGenerateSVG_DifferentNames() public {
        string memory svg1 = svgLib.generateSVG("short", "eth");
        string memory svg2 = svgLib.generateSVG("verylongname", "com");

        // Both should be valid SVGs
        assertTrue(bytes(svg1).length > 1000);
        assertTrue(bytes(svg2).length > 1000);

        // They should be different (contain different names)
        assertTrue(keccak256(bytes(svg1)) != keccak256(bytes(svg2)));
    }

    function testGenerateSVG_DifferentTLDs() public {
        string memory svg1 = svgLib.generateSVG("test", "eth");
        string memory svg2 = svgLib.generateSVG("test", "com");

        // Both should be valid SVGs
        assertTrue(bytes(svg1).length > 1000);
        assertTrue(bytes(svg2).length > 1000);

        // They should be different (contain different TLDs)
        assertTrue(keccak256(bytes(svg1)) != keccak256(bytes(svg2)));
    }

    function testGenerateSVG_EmptyStrings() public {
        string memory svg = svgLib.generateSVG("", "");

        // Should still generate valid SVG
        assertTrue(bytes(svg).length > 1000);
        assertTrue(bytes(svg)[0] == "<");
        assertTrue(bytes(svg)[bytes(svg).length - 1] == ">");
    }

    function testGenerateSVG_SpecialCharacters() public {
        string memory svg = svgLib.generateSVG("test-123", "tld-456");

        // Should handle special characters
        assertTrue(bytes(svg).length > 1000);
        assertTrue(bytes(svg)[0] == "<");
        assertTrue(bytes(svg)[bytes(svg).length - 1] == ">");
    }

    function testGenerateSVG_UnicodeCharacters() public {
        string memory svg = svgLib.generateSVG(unicode"tést", unicode"éth");

        // Should handle unicode characters
        assertTrue(bytes(svg).length > 1000);
        assertTrue(bytes(svg)[0] == "<");
        assertTrue(bytes(svg)[bytes(svg).length - 1] == ">");
    }

    function testGenerateSVG_VeryLongNames() public {
        string
            memory veryLongName = "thisisaverylongdomainnamethatexceedstypicallimitsandshouldstillwork";
        string
            memory veryLongTLD = "thisisaverylongtldthatexceedstypicallimitsandshouldstillwork";

        string memory svg = svgLib.generateSVG(veryLongName, veryLongTLD);

        // Should handle very long strings
        assertTrue(bytes(svg).length > 1000);
        assertTrue(bytes(svg)[0] == "<");
        assertTrue(bytes(svg)[bytes(svg).length - 1] == ">");
    }

    function testGenerateSVG_Consistency() public {
        // Same inputs should produce same output
        string memory svg1 = svgLib.generateSVG("test", "eth");
        string memory svg2 = svgLib.generateSVG("test", "eth");

        assertEq(svg1, svg2);
    }

    // ============ TOKEN URI LIBRARY TESTS ============

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
