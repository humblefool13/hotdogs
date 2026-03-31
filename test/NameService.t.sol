// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/NameService.sol";
import "../src/HNSManager.sol";

contract NameServiceTest is Test {
    NameService public nameService;
    HNSManager public manager;
    address public user = address(0x123);
    address public user2 = address(0x456);
    address public user3 = address(0x789);
    string public constant TLD = "hotdogs";

    // Event definitions for testing (must match NameService contract exactly)
    event DomainRegistered(
        uint256 indexed tokenId,
        address indexed owner,
        uint256 expiration
    );
    event DomainRenewed(
        uint256 indexed tokenId,
        address indexed owner,
        uint256 newExpiration
    );
    event DomainTransferred(
        uint256 indexed tokenId,
        address indexed from,
        address indexed to
    );
    event DomainExpired(uint256 indexed tokenId, address indexed previousOwner);
    event ExpiredDomainsProcessed(uint256 cleaned);

    function setUp() public {
        manager = new HNSManager();
        manager.addTLD(TLD);
        nameService = NameService(manager.tldContracts(TLD));
        vm.deal(user, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);
    }

    function _price(
        string memory name,
        uint256 years_
    ) internal pure returns (uint256) {
        uint256 len = bytes(name).length;
        uint256 base;
        if (len == 3) base = 0.0049 ether;
        else if (len == 4) base = 0.0034 ether;
        else if (len == 5) base = 0.0024 ether;
        else base = 0.0015 ether;
        return base * years_;
    }

    // ============ CONSTRUCTOR TESTS ============

    function testConstructor() public {
        assertEq(nameService.tld(), TLD);
        assertEq(nameService.hnsManager(), address(manager));
        assertEq(nameService.svgLibrary(), manager.svgLibrary());
    }

    // ============ REGISTER TESTS ============

    function testRegister_Basic() public {
        vm.startPrank(user);
        uint256 price = _price("test", 1);
        vm.expectEmit(true, true, false, false);
        emit DomainRegistered(1, user, 0);
        nameService.register{value: price}("test", 1);
        vm.stopPrank();

        assertEq(nameService.getDomainOwner("test"), user);
        assertGt(nameService.getDomainExpiration("test"), block.timestamp);
        assertEq(nameService.ownerOf(1), user);
        assertEq(nameService.domainToToken("test"), 1);
        assertEq(nameService.tokenToDomain(1), "test");
    }

    function testRegister_InvalidName() public {
        // Too short
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(NameService.InvalidName.selector, "ab")
        );
        nameService.register{value: 1 ether}("ab", 1);

        // Too long
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                NameService.InvalidName.selector,
                "verylongname"
            )
        );
        nameService.register{value: 1 ether}("verylongname", 1);

        // Invalid characters
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(NameService.InvalidName.selector, "test-")
        );
        nameService.register{value: 1 ether}("test-", 1);

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(NameService.InvalidName.selector, "-test")
        );
        nameService.register{value: 1 ether}("-test", 1);

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                NameService.InvalidName.selector,
                "test--name"
            )
        );
        nameService.register{value: 1 ether}("test--name", 1);

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                NameService.InvalidName.selector,
                "test.name"
            )
        );
        nameService.register{value: 1 ether}("test.name", 1);

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(NameService.InvalidName.selector, "TEST")
        );
        nameService.register{value: 1 ether}("TEST", 1);
    }

    function testRegister_InvalidPeriod() public {
        // Zero years
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                NameService.InvalidRegistrationPeriod.selector
            )
        );
        nameService.register{value: 1 ether}("test", 0);

        // Too many years
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                NameService.InvalidRegistrationPeriod.selector
            )
        );
        nameService.register{value: 1 ether}("test", 11);
    }

    function testRegister_InsufficientPayment() public {
        vm.prank(user);
        uint256 price = _price("test", 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                NameService.InsufficientPaymentAmount.selector,
                price,
                price - 1
            )
        );
        nameService.register{value: price - 1}("test", 1);
    }

    function testRegister_AlreadyRegistered() public {
        vm.prank(user);
        uint256 price = _price("test", 1);
        nameService.register{value: price}("test", 1);

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                NameService.DomainAlreadyRegistered.selector,
                "test"
            )
        );
        nameService.register{value: price}("test", 1);
    }

    function testRegister_ReuseExpired() public {
        vm.prank(user);
        uint256 price = _price("test", 1);
        nameService.register{value: price}("test", 1);

        // Fast forward past expiration
        vm.warp(block.timestamp + 2 * 365 days);
        nameService.cleanupExpiredDomains(1);

        // Can re-register
        vm.prank(user2);
        nameService.register{value: price}("test", 1);
        assertEq(nameService.getDomainOwner("test"), user2);
    }

    function testRegister_EventEmitted() public {
        vm.startPrank(user);
        uint256 price = _price("test", 1);
        vm.expectEmit(true, true, false, false);
        emit DomainRegistered(1, user, 0);
        nameService.register{value: price}("test", 1);
        vm.stopPrank();
    }

    function testRegister_MultipleYears() public {
        vm.prank(user);
        uint256 price = _price("test", 5);
        nameService.register{value: price}("test", 5);

        uint256 expiration = nameService.getDomainExpiration("test");
        assertGt(expiration, block.timestamp + 4 * 365 days);
        assertLt(expiration, block.timestamp + 6 * 365 days);
    }

    function testRegister_AllDomainsArray() public {
        vm.startPrank(user);
        nameService.register{value: _price("test1", 1)}("test1", 1);
        nameService.register{value: _price("test2", 1)}("test2", 1);
        nameService.register{value: _price("test3", 1)}("test3", 1);
        vm.stopPrank();

        string[] memory allDomains = nameService.getAllDomains();
        assertEq(allDomains.length, 3);
        assertEq(allDomains[0], "test1");
        assertEq(allDomains[1], "test2");
        assertEq(allDomains[2], "test3");
    }

    function testRegister_DomainInfo() public {
        vm.prank(user);
        uint256 price = _price("test", 1);
        nameService.register{value: price}("test", 1);

        (
            address owner_,
            uint256 expiration,
            uint256 registrationDate,
            uint256 renewalCount
        ) = nameService.getDomainInfo("test");
        assertEq(owner_, user);
        assertGt(expiration, block.timestamp);
        assertEq(registrationDate, block.timestamp);
        assertEq(renewalCount, 0);
    }

    // ============ RENEW TESTS ============

    function testRenew_Basic() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 beforeExp = nameService.getDomainExpiration("test");

        vm.prank(user);
        vm.expectEmit(true, true, false, true);
        emit DomainRenewed(1, user, beforeExp + 365 days);
        nameService.renew{value: _price("test", 1)}("test", 1);

        uint256 afterExp = nameService.getDomainExpiration("test");
        assertGt(afterExp, beforeExp);
        assertEq(afterExp, beforeExp + 365 days);
    }

    function testRenew_MultipleYears() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 beforeExp = nameService.getDomainExpiration("test");

        vm.prank(user);
        nameService.renew{value: _price("test", 3)}("test", 3);

        uint256 afterExp = nameService.getDomainExpiration("test");
        assertGt(afterExp, beforeExp + 2 * 365 days);
        assertLt(afterExp, beforeExp + 4 * 365 days);
    }

    function testRenew_InvalidName() public {
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(NameService.InvalidName.selector, "ab")
        );
        nameService.renew{value: 1 ether}("ab", 1);
    }

    function testRenew_DomainNotFound() public {
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(NameService.DomainNotFound.selector, "test")
        );
        nameService.renew{value: _price("test", 1)}("test", 1);
    }

    function testRenew_Unauthorized() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(NameService.Unauthorized.selector)
        );
        nameService.renew{value: _price("test", 1)}("test", 1);
    }

    function testRenew_Expired() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);

        // After expiry, the domain is swept/burned on next interaction, so owner becomes address(0)
        vm.warp(block.timestamp + 2 * 365 days);
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(NameService.DomainNotFound.selector, "test")
        );
        nameService.renew{value: _price("test", 1)}("test", 1);
    }

    function testRenew_InvalidPeriod() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                NameService.InvalidRegistrationPeriod.selector
            )
        );
        nameService.renew{value: 1 ether}("test", 0);

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                NameService.InvalidRegistrationPeriod.selector
            )
        );
        nameService.renew{value: 1 ether}("test", 11);
    }

    function testRenew_InsufficientPayment() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);

        vm.prank(user);
        uint256 price = _price("test", 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                NameService.InsufficientPaymentAmount.selector,
                price,
                price - 1
            )
        );
        nameService.renew{value: price - 1}("test", 1);
    }

    function testRenew_RenewalCount() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);

        vm.prank(user);
        nameService.renew{value: _price("test", 1)}("test", 1);

        (, , , uint256 renewalCount) = nameService.getDomainInfo("test");
        assertEq(renewalCount, 1);

        vm.prank(user);
        nameService.renew{value: _price("test", 1)}("test", 1);

        (, , , renewalCount) = nameService.getDomainInfo("test");
        assertEq(renewalCount, 2);
    }

    // ============ TRANSFER DOMAIN TESTS ============

    function testTransferDomain_Basic() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit DomainTransferred(tokenId, user, user2);
        nameService.transferDomain("test", user2);

        assertEq(nameService.ownerOf(tokenId), user2);
        assertEq(nameService.getDomainOwner("test"), user2);
    }

    function testTransferDomain_DomainNotFound() public {
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(NameService.DomainNotFound.selector, "test")
        );
        nameService.transferDomain("test", user2);
    }

    function testTransferDomain_Expired() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);

        vm.warp(block.timestamp + 2 * 365 days);
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(NameService.DomainNotFound.selector, "test")
        );
        nameService.transferDomain("test", user2);
    }

    function testTransferDomain_Unauthorized() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(NameService.Unauthorized.selector)
        );
        nameService.transferDomain("test", user3);
    }

    function testTransferDomain_ZeroAddress() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(NameService.ZeroAddr.selector));
        nameService.transferDomain("test", address(0));
    }

    function testTransferDomain_EventEmitted() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        vm.prank(user);
        vm.expectEmit(true, true, true, false);
        emit DomainTransferred(tokenId, user, user2);
        nameService.transferDomain("test", user2);
    }

    // ============ AVAILABILITY AND RESOLUTION TESTS ============

    function testIsDomainAvailable_Available() public {
        assertTrue(nameService.isDomainAvailable("test"));
    }

    function testIsDomainAvailable_Registered() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        assertFalse(nameService.isDomainAvailable("test"));
    }

    function testIsDomainAvailable_Expired() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);

        vm.warp(block.timestamp + 2 * 365 days);
        assertTrue(nameService.isDomainAvailable("test"));
    }

    function testIsDomainAvailable_InvalidName() public {
        assertFalse(nameService.isDomainAvailable("ab"));
        assertFalse(nameService.isDomainAvailable("verylongname"));
        assertFalse(nameService.isDomainAvailable("test-"));
        assertFalse(nameService.isDomainAvailable("-test"));
        assertFalse(nameService.isDomainAvailable("test--name"));
    }

    function testResolveDomain_Registered() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);

        (
            address owner_,
            uint256 expiration,
            address nft,
            uint256 tokenId
        ) = nameService.resolveDomain("test");
        assertEq(owner_, user);
        assertEq(nft, address(nameService));
        assertGt(expiration, block.timestamp);
        assertGt(tokenId, 0);
    }

    function testResolveDomain_NotFound() public {
        (
            address owner_,
            uint256 expiration,
            address nft,
            uint256 tokenId
        ) = nameService.resolveDomain("test");
        assertEq(owner_, address(0));
        assertEq(expiration, 0);
        assertEq(nft, address(0));
        assertEq(tokenId, 0);
    }

    function testResolveDomain_Expired() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);

        vm.warp(block.timestamp + 2 * 365 days);
        (
            address owner_,
            uint256 expiration,
            address nft,
            uint256 tokenId
        ) = nameService.resolveDomain("test");
        assertEq(owner_, address(0));
        assertEq(expiration, 0);
        assertEq(nft, address(0));
        assertEq(tokenId, 0);
    }

    // ============ EXPIRATION AND CLEANUP TESTS ============

    function testcleanupExpiredDomains_Basic() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);

        vm.warp(block.timestamp + 2 * 365 days);
        nameService.cleanupExpiredDomains(1);

        assertEq(nameService.getDomainOwner("test"), address(0));
        assertTrue(nameService.isDomainAvailable("test"));
    }

    function testcleanupExpiredDomains_Multiple() public {
        vm.startPrank(user);
        nameService.register{value: _price("test1", 1)}("test1", 1);
        nameService.register{value: _price("test2", 1)}("test2", 1);
        nameService.register{value: _price("test3", 1)}("test3", 1);
        vm.stopPrank();

        vm.warp(block.timestamp + 2 * 365 days);
        nameService.cleanupExpiredDomains(3);

        assertEq(nameService.getDomainOwner("test1"), address(0));
        assertEq(nameService.getDomainOwner("test2"), address(0));
        assertEq(nameService.getDomainOwner("test3"), address(0));
    }

    function testCleanupExpiredDomains_InvalidBatch() public {
        vm.expectRevert(abi.encodeWithSelector(NameService.BadBatch.selector));
        nameService.cleanupExpiredDomains(0);

        vm.expectRevert(abi.encodeWithSelector(NameService.BadBatch.selector));
        nameService.cleanupExpiredDomains(21);
    }

    function testCleanupExpiredDomains_BatchLimit() public {
        // Register many domains
        vm.startPrank(user);
        for (uint i = 0; i < 25; i++) {
            string memory name = string(
                abi.encodePacked("test", vm.toString(i))
            );
            nameService.register{value: _price(name, 1)}(name, 1);
        }
        vm.stopPrank();

        vm.warp(block.timestamp + 2 * 365 days);

        // Should only process 20 domains
        vm.expectEmit(true, true, false, true);
        emit ExpiredDomainsProcessed(20);
        nameService.cleanupExpiredDomains(20);

        // Some domains should still be expired
        assertTrue(nameService.isDomainAvailable("test0"));
        assertTrue(nameService.isDomainAvailable("test19"));
    }

    function testCleanupExpiredDomains_NoExpired() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);

        // No domains expired yet
        vm.expectEmit(true, true, false, true);
        emit ExpiredDomainsProcessed(0);
        nameService.cleanupExpiredDomains(20);

        assertEq(nameService.getDomainOwner("test"), user);
    }

    // ============ NFT TRANSFER TESTS ============

    function testTransferFrom_Basic() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        vm.prank(user);
        nameService.transferFrom(user, user2, tokenId);

        assertEq(nameService.ownerOf(tokenId), user2);
        assertEq(nameService.getDomainOwner("test"), user2);
    }

    function testSafeTransferFrom_Basic() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        vm.prank(user);
        nameService.safeTransferFrom(user, user2, tokenId, "");

        assertEq(nameService.ownerOf(tokenId), user2);
        assertEq(nameService.getDomainOwner("test"), user2);
    }

    function testTransferFrom_Expired() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        vm.warp(block.timestamp + 2 * 365 days);
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(NameService.DomainIsExpired.selector, "test")
        );
        nameService.transferFrom(user, user2, tokenId);
    }

    // ============ PRICING TESTS ============

    function testCalculatePrice_3Chars() public {
        uint256 price = nameService._calculatePrice("abc", 1);
        assertEq(price, 0.0049 ether);
    }

    function testCalculatePrice_4Chars() public {
        uint256 price = nameService._calculatePrice("abcd", 1);
        assertEq(price, 0.0034 ether);
    }

    function testCalculatePrice_5Chars() public {
        uint256 price = nameService._calculatePrice("abcde", 1);
        assertEq(price, 0.0024 ether);
    }

    function testCalculatePrice_6Chars() public {
        uint256 price = nameService._calculatePrice("abcdef", 1);
        assertEq(price, 0.0015 ether);
    }

    function testCalculatePrice_7PlusChars() public {
        uint256 price = nameService._calculatePrice("abcdefg", 1);
        assertEq(price, 0.0015 ether);
    }

    function testCalculatePrice_MultipleYears() public {
        uint256 price = nameService._calculatePrice("test", 5);
        assertEq(price, 0.0034 ether * 5);
    }

    // ============ VALIDATION TESTS ============

    function testIsValidName_Valid() public {
        // Test valid names by trying to register them
        vm.startPrank(user);
        nameService.register{value: _price("abc", 1)}("abc", 1);
        nameService.register{value: _price("test", 1)}("test", 1);
        nameService.register{value: _price("test123", 1)}("test123", 1);
        nameService.register{value: _price("test-name", 1)}("test-name", 1);
        vm.stopPrank();

        // All should be registered successfully
        assertEq(nameService.getDomainOwner("abc"), user);
        assertEq(nameService.getDomainOwner("test"), user);
        assertEq(nameService.getDomainOwner("test123"), user);
        assertEq(nameService.getDomainOwner("test-name"), user);
    }

    function testIsValidName_Invalid() public {
        // Test invalid names by trying to register them (should revert)
        vm.startPrank(user);

        // These should revert due to invalid names
        vm.expectRevert();
        nameService.register{value: _price("ab", 1)}("ab", 1);

        vm.expectRevert();
        nameService.register{value: _price("verylongname", 1)}(
            "verylongname",
            1
        );

        vm.expectRevert();
        nameService.register{value: _price("test-", 1)}("test-", 1);

        vm.expectRevert();
        nameService.register{value: _price("-test", 1)}("-test", 1);

        vm.expectRevert();
        nameService.register{value: _price("test--name", 1)}("test--name", 1);

        vm.expectRevert();
        nameService.register{value: _price("test.name", 1)}("test.name", 1);

        vm.expectRevert();
        nameService.register{value: _price("TEST", 1)}("TEST", 1);

        // Multiple hyphens not allowed
        vm.expectRevert();
        nameService.register{value: _price("a-b-c", 1)}("a-b-c", 1);

        vm.stopPrank();
    }

    // ============ ROYALTY TESTS ============

    function testSupportsInterface() public {
        // IERC2981
        assertTrue(nameService.supportsInterface(0x2a55205a));
        // ERC721
        assertTrue(nameService.supportsInterface(0x80ac58cd));
        // ERC721Metadata
        assertTrue(nameService.supportsInterface(0x5b5e139f));
        // ERC165
        assertTrue(nameService.supportsInterface(0x01ffc9a7));
    }

    function testRoyaltyInfo_Basic() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        (address receiver, uint256 royaltyAmount) = nameService.royaltyInfo(
            tokenId,
            1 ether
        );
        assertEq(receiver, address(manager));
        assertEq(royaltyAmount, (1 ether * 250) / 10000);
    }

    function testRoyaltyInfo_NoToken() public {
        vm.expectRevert(abi.encodeWithSelector(NameService.NoToken.selector));
        nameService.royaltyInfo(999999, 1 ether);
    }

    function testRoyaltyInfo_DifferentPrices() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        (address receiver, uint256 royaltyAmount) = nameService.royaltyInfo(
            tokenId,
            2 ether
        );
        assertEq(receiver, address(manager));
        assertEq(royaltyAmount, (2 ether * 250) / 10000);
    }

    // ============ GETTER TESTS ============

    function testGetAllDomains() public {
        vm.startPrank(user);
        nameService.register{value: _price("test1", 1)}("test1", 1);
        nameService.register{value: _price("test2", 1)}("test2", 1);
        nameService.register{value: _price("test3", 1)}("test3", 1);
        vm.stopPrank();

        string[] memory domains = nameService.getAllDomains();
        assertEq(domains.length, 3);
    }

    function testGetTotalDomainCount() public {
        assertEq(nameService.getTotalDomainCount(), 0);

        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        assertEq(nameService.getTotalDomainCount(), 1);
    }

    function testGetDomainExpiration() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);

        uint256 expiration = nameService.getDomainExpiration("test");
        assertGt(expiration, block.timestamp);
        assertLt(expiration, block.timestamp + 2 * 365 days);
    }

    // ============ EDGE CASES AND STRESS TESTS ============

    function testManyDomains() public {
        vm.startPrank(user);
        for (uint i = 0; i < 10; i++) {
            string memory name = string(
                abi.encodePacked("test", vm.toString(i))
            );
            nameService.register{value: _price(name, 1)}(name, 1);
        }
        vm.stopPrank();

        assertEq(nameService.getTotalDomainCount(), 10);
    }

    function testComplexWorkflow() public {
        // Register domain
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);

        // Renew domain
        vm.prank(user);
        nameService.renew{value: _price("test", 2)}("test", 2);

        // Transfer domain
        vm.prank(user);
        nameService.transferDomain("test", user2);

        // Verify new owner
        assertEq(nameService.getDomainOwner("test"), user2);

        // Renew as new owner
        vm.prank(user2);
        nameService.renew{value: _price("test", 1)}("test", 1);

        // Verify still owned by user2
        assertEq(nameService.getDomainOwner("test"), user2);
    }

    function testGasOptimization() public {
        vm.startPrank(user);
        // Register multiple domains to test gas usage
        for (uint i = 0; i < 5; i++) {
            string memory name = string(
                abi.encodePacked("test", vm.toString(i))
            );
            nameService.register{value: _price(name, 1)}(name, 1);
        }
        vm.stopPrank();

        // All operations should succeed
        assertEq(nameService.getTotalDomainCount(), 5);
    }
}
