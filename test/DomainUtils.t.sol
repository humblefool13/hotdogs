// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/DomainUtils.sol";

contract DomainUtilsTest is Test {
    // ============ IS VALID TLD TESTS ============

    function testIsValidTLD_ValidCases() public pure {
        assertTrue(DomainUtils.isValidTLD("eth"));
        assertTrue(DomainUtils.isValidTLD("com"));
        assertTrue(DomainUtils.isValidTLD("hotdogs"));
        assertTrue(DomainUtils.isValidTLD("abcdefghij")); // 10 chars
        assertTrue(DomainUtils.isValidTLD("abc")); // 3 chars
    }

    function testIsValidTLD_InvalidLength() public pure {
        // Too short
        assertFalse(DomainUtils.isValidTLD("ab")); // 2 chars
        assertFalse(DomainUtils.isValidTLD("a")); // 1 char
        assertFalse(DomainUtils.isValidTLD("")); // empty

        // Too long
        assertFalse(DomainUtils.isValidTLD("abcdefghijk")); // 11 chars
        assertFalse(DomainUtils.isValidTLD("thisiswaytoolong")); // 16 chars
    }

    function testIsValidTLD_InvalidCharacters() public pure {
        // Uppercase letters
        assertFalse(DomainUtils.isValidTLD("ETH"));
        assertFalse(DomainUtils.isValidTLD("Com"));
        assertFalse(DomainUtils.isValidTLD("HotDogs"));

        // Numbers
        assertFalse(DomainUtils.isValidTLD("123"));
        assertFalse(DomainUtils.isValidTLD("eth123"));
        assertFalse(DomainUtils.isValidTLD("123eth"));

        // Special characters
        assertFalse(DomainUtils.isValidTLD("eth-"));
        assertFalse(DomainUtils.isValidTLD("eth_"));
        assertFalse(DomainUtils.isValidTLD("eth."));
        assertFalse(DomainUtils.isValidTLD("eth@"));
        assertFalse(DomainUtils.isValidTLD("eth#"));
        assertFalse(DomainUtils.isValidTLD("eth$"));
        assertFalse(DomainUtils.isValidTLD("eth%"));
        assertFalse(DomainUtils.isValidTLD("eth&"));
        assertFalse(DomainUtils.isValidTLD("eth*"));
        assertFalse(DomainUtils.isValidTLD("eth+"));
        assertFalse(DomainUtils.isValidTLD("eth="));
        assertFalse(DomainUtils.isValidTLD("eth!"));
        assertFalse(DomainUtils.isValidTLD("eth?"));
        assertFalse(DomainUtils.isValidTLD("eth/"));
        assertFalse(DomainUtils.isValidTLD("eth\\"));
        assertFalse(DomainUtils.isValidTLD("eth|"));
        assertFalse(DomainUtils.isValidTLD("eth<"));
        assertFalse(DomainUtils.isValidTLD("eth>"));
        assertFalse(DomainUtils.isValidTLD("eth,"));
        assertFalse(DomainUtils.isValidTLD("eth;"));
        assertFalse(DomainUtils.isValidTLD("eth:"));
        assertFalse(DomainUtils.isValidTLD("eth'"));
        assertFalse(DomainUtils.isValidTLD('eth"'));
        assertFalse(DomainUtils.isValidTLD("eth("));
        assertFalse(DomainUtils.isValidTLD("eth)"));
        assertFalse(DomainUtils.isValidTLD("eth["));
        assertFalse(DomainUtils.isValidTLD("eth]"));
        assertFalse(DomainUtils.isValidTLD("eth{"));
        assertFalse(DomainUtils.isValidTLD("eth}"));
        assertFalse(DomainUtils.isValidTLD("eth~"));
        assertFalse(DomainUtils.isValidTLD("eth`"));
        assertFalse(DomainUtils.isValidTLD("eth "));
        assertFalse(DomainUtils.isValidTLD(" eth"));
        assertFalse(DomainUtils.isValidTLD("eth\t"));
        assertFalse(DomainUtils.isValidTLD("eth\n"));
        assertFalse(DomainUtils.isValidTLD("eth\r"));
    }

    function testIsValidTLD_EdgeCases() public pure {
        // Mixed case
        assertFalse(DomainUtils.isValidTLD("eTh"));
        assertFalse(DomainUtils.isValidTLD("EtH"));

        // Spaces
        assertFalse(DomainUtils.isValidTLD("eth "));
        assertFalse(DomainUtils.isValidTLD(" eth"));
        assertFalse(DomainUtils.isValidTLD("e th"));

        // Unicode characters
        assertFalse(DomainUtils.isValidTLD(unicode"éth"));
        assertFalse(DomainUtils.isValidTLD(unicode"ethé"));
        assertFalse(DomainUtils.isValidTLD(unicode"éthé"));
    }

    // ============ IS VALID DOMAIN NAME TESTS ============

    function testIsValidDomainName_ValidCases() public pure {
        // Basic valid names
        assertTrue(DomainUtils.isValidDomainName("abc"));
        assertTrue(DomainUtils.isValidDomainName("test"));
        assertTrue(DomainUtils.isValidDomainName("domain"));
        assertTrue(DomainUtils.isValidDomainName("abcdefghij")); // 10 chars
        assertTrue(DomainUtils.isValidDomainName("abc")); // 3 chars

        // With numbers
        assertTrue(DomainUtils.isValidDomainName("test123"));
        assertTrue(DomainUtils.isValidDomainName("123test"));
        assertTrue(DomainUtils.isValidDomainName("test13test"));
        assertTrue(DomainUtils.isValidDomainName("1a2b3c"));

        // With hyphens (valid positions)
        assertTrue(DomainUtils.isValidDomainName("test-name"));
        assertTrue(DomainUtils.isValidDomainName("a-bc"));
        assertTrue(DomainUtils.isValidDomainName("testname-3"));
        assertTrue(DomainUtils.isValidDomainName("abcd-e"));
    }

    function testIsValidDomainName_InvalidLength() public pure {
        // Too short
        assertFalse(DomainUtils.isValidDomainName("ab")); // 2 chars
        assertFalse(DomainUtils.isValidDomainName("a")); // 1 char
        assertFalse(DomainUtils.isValidDomainName("")); // empty

        // Too long
        assertFalse(DomainUtils.isValidDomainName("abcdefghijk")); // 11 chars
        assertFalse(DomainUtils.isValidDomainName("thisiswaytoolong")); // 16 chars
    }

    function testIsValidDomainName_InvalidHyphens() public pure {
        // Leading hyphen
        assertFalse(DomainUtils.isValidDomainName("-test"));
        assertFalse(DomainUtils.isValidDomainName("-abc"));
        assertFalse(DomainUtils.isValidDomainName("-123"));

        // Trailing hyphen
        assertFalse(DomainUtils.isValidDomainName("test-"));
        assertFalse(DomainUtils.isValidDomainName("abc-"));
        assertFalse(DomainUtils.isValidDomainName("123-"));

        // Consecutive hyphens
        assertFalse(DomainUtils.isValidDomainName("test--name"));
        assertFalse(DomainUtils.isValidDomainName("a--b"));
        assertFalse(DomainUtils.isValidDomainName("test---name"));
        assertFalse(DomainUtils.isValidDomainName("a---b"));

        // Only hyphens
        assertFalse(DomainUtils.isValidDomainName("---"));
        assertFalse(DomainUtils.isValidDomainName("--"));
        assertFalse(DomainUtils.isValidDomainName("-"));

        // Multiple hyphens
        assertFalse(DomainUtils.isValidDomainName("t-est-name"));
        assertFalse(DomainUtils.isValidDomainName("a-b-c"));
        assertFalse(DomainUtils.isValidDomainName("e-t-n-m"));
        assertFalse(DomainUtils.isValidDomainName("a-d-f-b"));
    }

    function testIsValidDomainName_InvalidCharacters() public pure {
        // Uppercase letters
        assertFalse(DomainUtils.isValidDomainName("Test"));
        assertFalse(DomainUtils.isValidDomainName("TEST"));
        assertFalse(DomainUtils.isValidDomainName("tEsT"));

        // Special characters
        assertFalse(DomainUtils.isValidDomainName("test.name"));
        assertFalse(DomainUtils.isValidDomainName("test@name"));
        assertFalse(DomainUtils.isValidDomainName("test#name"));
        assertFalse(DomainUtils.isValidDomainName("test$name"));
        assertFalse(DomainUtils.isValidDomainName("test%name"));
        assertFalse(DomainUtils.isValidDomainName("test&name"));
        assertFalse(DomainUtils.isValidDomainName("test*name"));
        assertFalse(DomainUtils.isValidDomainName("test+name"));
        assertFalse(DomainUtils.isValidDomainName("test=name"));
        assertFalse(DomainUtils.isValidDomainName("test!name"));
        assertFalse(DomainUtils.isValidDomainName("test?name"));
        assertFalse(DomainUtils.isValidDomainName("test/name"));
        assertFalse(DomainUtils.isValidDomainName("test\\name"));
        assertFalse(DomainUtils.isValidDomainName("test|name"));
        assertFalse(DomainUtils.isValidDomainName("test<name"));
        assertFalse(DomainUtils.isValidDomainName("test>name"));
        assertFalse(DomainUtils.isValidDomainName("test,name"));
        assertFalse(DomainUtils.isValidDomainName("test;name"));
        assertFalse(DomainUtils.isValidDomainName("test:name"));
        assertFalse(DomainUtils.isValidDomainName("test'name"));
        assertFalse(DomainUtils.isValidDomainName('test"name'));
        assertFalse(DomainUtils.isValidDomainName("test(name"));
        assertFalse(DomainUtils.isValidDomainName("test)name"));
        assertFalse(DomainUtils.isValidDomainName("test[name"));
        assertFalse(DomainUtils.isValidDomainName("test]name"));
        assertFalse(DomainUtils.isValidDomainName("test{name"));
        assertFalse(DomainUtils.isValidDomainName("test}name"));
        assertFalse(DomainUtils.isValidDomainName("test~name"));
        assertFalse(DomainUtils.isValidDomainName("test`name"));
        assertFalse(DomainUtils.isValidDomainName("test name"));
        assertFalse(DomainUtils.isValidDomainName("test\tname"));
        assertFalse(DomainUtils.isValidDomainName("test\nname"));
        assertFalse(DomainUtils.isValidDomainName("test\rname"));

        // Underscores
        assertFalse(DomainUtils.isValidDomainName("test_name"));
        assertFalse(DomainUtils.isValidDomainName("_test"));
        assertFalse(DomainUtils.isValidDomainName("test_"));
    }

    function testIsValidDomainName_EdgeCases() public pure {
        // Mixed valid/invalid
        assertFalse(DomainUtils.isValidDomainName("test-name-"));
        assertFalse(DomainUtils.isValidDomainName("-test-name"));
        assertFalse(DomainUtils.isValidDomainName("test--name"));

        // Unicode characters
        assertFalse(DomainUtils.isValidDomainName(unicode"tést"));
        assertFalse(DomainUtils.isValidDomainName(unicode"testé"));
        assertFalse(DomainUtils.isValidDomainName(unicode"tésté"));

        // Spaces
        assertFalse(DomainUtils.isValidDomainName("test name"));
        assertFalse(DomainUtils.isValidDomainName(" test"));
        assertFalse(DomainUtils.isValidDomainName("test "));
    }
}
