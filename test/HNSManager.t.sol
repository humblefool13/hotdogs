// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/HNSManager.sol";
import "../src/NameService.sol";

contract HNSManagerTest is Test {
    HNSManager public manager;
    address public owner = address(this);
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public user3 = address(0x3);

    string public constant TLD1 = "hotdogs";
    string public constant TLD2 = "rise";
    string public constant TLD3 = "test";

    // Event definitions for testing
    event TLDAdded(string indexed tld, address indexed tldContract);
    event FundsWithdrawn(address indexed recipient, uint256 amount);

    function setUp() public {
        manager = new HNSManager();
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);
    }

    function _price(
        string memory name,
        uint256 years_
    ) internal pure returns (uint256) {
        uint256 len = bytes(name).length;
        uint256 base;
        if (len == 3) base = 0.012 ether;
        else if (len == 4) base = 0.01 ether;
        else if (len == 5) base = 0.008 ether;
        else if (len == 6) base = 0.006 ether;
        else base = 0.004 ether;
        return base * years_;
    }

    // ============ CONSTRUCTOR TESTS ============

    function testConstructor() public {
        assertEq(manager.owner(), owner);
        assertTrue(manager.svgLibrary() != address(0));
        uint256 size;
        address svgLib = manager.svgLibrary();
        assembly {
            size := extcodesize(svgLib)
        }
        assertGt(size, 0);
    }

    function testConstructor_SVGLibraryDeployed() public {
        address svgLib = manager.svgLibrary();
        assertTrue(svgLib != address(0));

        // Verify it's a valid contract
        uint256 size;
        assembly {
            size := extcodesize(svgLib)
        }
        assertTrue(size > 0);
    }

    // ============ ADD TLD TESTS ============

    function testAddTLD_Basic() public {
        manager.addTLD(TLD1);

        address ns = manager.tldContracts(TLD1);
        assertTrue(ns != address(0));
        assertTrue(manager.validNSAddress(ns));

        NameService nameService = NameService(ns);
        assertEq(nameService.tld(), TLD1);
        assertEq(nameService.hnsManager(), address(manager));
        assertEq(nameService.svgLibrary(), manager.svgLibrary());
    }

    function testAddTLD_MultipleTLDs() public {
        manager.addTLD(TLD1);
        manager.addTLD(TLD2);
        manager.addTLD(TLD3);

        assertTrue(manager.tldContracts(TLD1) != address(0));
        assertTrue(manager.tldContracts(TLD2) != address(0));
        assertTrue(manager.tldContracts(TLD3) != address(0));

        assertTrue(manager.validNSAddress(manager.tldContracts(TLD1)));
        assertTrue(manager.validNSAddress(manager.tldContracts(TLD2)));
        assertTrue(manager.validNSAddress(manager.tldContracts(TLD3)));
    }

    function testAddTLD_InvalidEmpty() public {
        vm.expectRevert(abi.encodeWithSelector(HNSManager.InvalidTLD.selector));
        manager.addTLD("");
    }

    function testAddTLD_InvalidTooShort() public {
        vm.expectRevert(abi.encodeWithSelector(HNSManager.InvalidTLD.selector));
        manager.addTLD("ab");
    }

    function testAddTLD_InvalidTooLong() public {
        vm.expectRevert(abi.encodeWithSelector(HNSManager.InvalidTLD.selector));
        manager.addTLD("thisiswaytoo");
    }

    function testAddTLD_InvalidUppercase() public {
        vm.expectRevert(abi.encodeWithSelector(HNSManager.InvalidTLD.selector));
        manager.addTLD("ETH");
    }

    function testAddTLD_InvalidNumbers() public {
        vm.expectRevert(abi.encodeWithSelector(HNSManager.InvalidTLD.selector));
        manager.addTLD("123");
    }

    function testAddTLD_InvalidSpecialChars() public {
        vm.expectRevert(abi.encodeWithSelector(HNSManager.InvalidTLD.selector));
        manager.addTLD("eth-");
    }

    function testAddTLD_AlreadyExists() public {
        manager.addTLD(TLD1);
        vm.expectRevert(abi.encodeWithSelector(HNSManager.TLDExists.selector));
        manager.addTLD(TLD1);
    }

    function testAddTLD_OnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        manager.addTLD(TLD1);
    }

    function testAddTLD_RegisteredTLDsArray() public {
        manager.addTLD(TLD1);
        manager.addTLD(TLD2);
        manager.addTLD(TLD3);

        assertEq(manager.registeredTLDs(0), TLD1);
        assertEq(manager.registeredTLDs(1), TLD2);
        assertEq(manager.registeredTLDs(2), TLD3);
    }

    // ============ WITHDRAW FUNDS TESTS ============

    function testWithdrawFunds_Basic() public {
        vm.deal(address(manager), 1 ether);
        uint256 beforeBal = owner.balance;
        vm.expectEmit(true, false, false, true);
        emit FundsWithdrawn(owner, 1 ether);
        manager.withdrawFunds();
        assertEq(owner.balance, beforeBal + 1 ether);
        assertEq(address(manager).balance, 0);
    }

    function testWithdrawFunds_NoFunds() public {
        vm.expectRevert(abi.encodeWithSelector(HNSManager.NoFunds.selector));
        manager.withdrawFunds();
    }

    function testWithdrawFunds_OnlyOwner() public {
        vm.deal(address(manager), 1 ether);
        vm.prank(user1);
        vm.expectRevert();
        manager.withdrawFunds();
    }

    function testWithdrawFunds_LargeAmount() public {
        vm.deal(address(manager), 1000 ether);
        uint256 beforeBal = owner.balance;
        manager.withdrawFunds();
        assertEq(owner.balance, beforeBal + 1000 ether);
        assertEq(address(manager).balance, 0);
    }

    function testWithdrawFunds_EventEmitted() public {
        vm.deal(address(manager), 0.5 ether);
        vm.expectEmit(true, false, false, true);
        emit FundsWithdrawn(owner, 0.5 ether);
        manager.withdrawFunds();
    }

    // ============ SET MAIN DOMAIN TESTS ============

    function testSetMainDomain_Basic() public {
        manager.addTLD(TLD1);
        NameService ns = NameService(manager.tldContracts(TLD1));

        vm.startPrank(user1);
        ns.register{value: _price("test", 1)}("test", 1);
        vm.stopPrank();

        vm.prank(user1);
        manager.setMainDomain("test", "hotdogs");
        assertEq(manager.mainDomain(user1), "test.hotdogs");
    }

    function testSetMainDomain_InvalidTLD() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(HNSManager.InvalidTLD.selector));
        manager.setMainDomain("test", "unknown");
    }

    function testSetMainDomain_InvalidDomainName() public {
        manager.addTLD(TLD1);
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(HNSManager.InvalidTLD.selector));
        manager.setMainDomain("test-", "hotdogs");
    }

    function testSetMainDomain_DomainNotFound() public {
        manager.addTLD(TLD1);
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(HNSManager.NoDomain.selector));
        manager.setMainDomain("test", "hotdogs");
    }

    function testSetMainDomain_NotOwner() public {
        manager.addTLD(TLD1);
        NameService ns = NameService(manager.tldContracts(TLD1));

        vm.startPrank(user1);
        ns.register{value: _price("test", 1)}("test", 1);
        vm.stopPrank();

        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSelector(HNSManager.NoDomain.selector));
        manager.setMainDomain("test", "hotdogs");
    }

    function testSetMainDomain_Overwrite() public {
        manager.addTLD(TLD1);
        NameService ns = NameService(manager.tldContracts(TLD1));

        vm.startPrank(user1);
        ns.register{value: _price("test1", 1)}("test1", 1);
        ns.register{value: _price("test2", 1)}("test2", 1);
        vm.stopPrank();

        vm.prank(user1);
        manager.setMainDomain("test1", "hotdogs");
        assertEq(manager.mainDomain(user1), "test1.hotdogs");

        vm.prank(user1);
        manager.setMainDomain("test2", "hotdogs");
        assertEq(manager.mainDomain(user1), "test2.hotdogs");
    }

    function testSetMainDomain_MultipleTLDs() public {
        manager.addTLD(TLD1);
        manager.addTLD(TLD2);
        NameService ns1 = NameService(manager.tldContracts(TLD1));
        NameService ns2 = NameService(manager.tldContracts(TLD2));

        vm.startPrank(user1);
        ns1.register{value: _price("test1", 1)}("test1", 1);
        ns2.register{value: _price("test2", 1)}("test2", 1);
        vm.stopPrank();

        vm.prank(user1);
        manager.setMainDomain("test1", "hotdogs");
        assertEq(manager.mainDomain(user1), "test1.hotdogs");

        vm.prank(user1);
        manager.setMainDomain("test2", "rise");
        assertEq(manager.mainDomain(user1), "test2.rise");
    }

    // ============ REVERSE LOOKUP TESTS ============

    function testReverseLookup_WithMainDomain() public {
        manager.addTLD(TLD1);
        NameService ns = NameService(manager.tldContracts(TLD1));

        vm.startPrank(user1);
        ns.register{value: _price("test1", 1)}("test1", 1);
        ns.register{value: _price("test2", 1)}("test2", 1);
        vm.stopPrank();

        vm.prank(user1);
        manager.setMainDomain("test2", "hotdogs");

        assertEq(manager.reverseLookup(user1), "test2.hotdogs");
    }

    function testReverseLookup_NoMainDomain() public {
        manager.addTLD(TLD1);
        NameService ns = NameService(manager.tldContracts(TLD1));

        vm.prank(user1);
        ns.register{value: _price("test", 1)}("test", 1);

        // No main domain set, should return first domain
        assertEq(manager.reverseLookup(user1), "test.hotdogs");
    }

    function testReverseLookup_NoDomains() public {
        assertEq(manager.reverseLookup(user1), "");
    }

    function testReverseLookup_MultipleDomains() public {
        manager.addTLD(TLD1);
        manager.addTLD(TLD2);
        NameService ns1 = NameService(manager.tldContracts(TLD1));
        NameService ns2 = NameService(manager.tldContracts(TLD2));

        vm.startPrank(user1);
        ns1.register{value: _price("test1", 1)}("test1", 1);
        ns2.register{value: _price("test2", 1)}("test2", 1);
        vm.stopPrank();

        // Should return first domain when no main is set
        assertEq(manager.reverseLookup(user1), "test1.hotdogs");
    }

    function testReverseLookup_AfterMainDomainRemoval() public {
        manager.addTLD(TLD1);
        NameService ns = NameService(manager.tldContracts(TLD1));

        vm.startPrank(user1);
        ns.register{value: _price("test1", 1)}("test1", 1);
        ns.register{value: _price("test2", 5)}("test2", 5);
        vm.stopPrank();

        vm.prank(user1);
        manager.setMainDomain("test1", "hotdogs");

        // Simulate domain expiration and cleanup
        vm.warp(block.timestamp + 2 * 365 days);
        ns.cleanupExpiredDomains(2);

        // Should return remaining domain
        assertEq(manager.reverseLookup(user1), "test2.hotdogs");
    }

    // ============ RESOLVE TESTS ============

    function testResolve_Basic() public {
        manager.addTLD(TLD1);
        NameService ns = NameService(manager.tldContracts(TLD1));

        vm.prank(user1);
        ns.register{value: _price("test", 1)}("test", 1);

        (address owner_, uint256 exp, address nft, uint256 tokenId) = manager
            .resolve("test", TLD1);
        assertEq(owner_, user1);
        assertEq(nft, address(ns));
        assertGt(exp, block.timestamp);
        assertGt(tokenId, 0);
    }

    function testResolve_TLDNotFound() public {
        vm.expectRevert(abi.encodeWithSelector(HNSManager.InvalidTLD.selector));
        manager.resolve("test", "unknown");
    }

    function testResolve_DomainNotFound() public {
        manager.addTLD(TLD1);
        (address owner_, uint256 exp, address nft, uint256 tokenId) = manager
            .resolve("nonexistent", TLD1);
        assertEq(owner_, address(0));
        assertEq(exp, 0);
        assertEq(nft, address(0));
        assertEq(tokenId, 0);
    }

    function testResolve_ExpiredDomain() public {
        manager.addTLD(TLD1);
        NameService ns = NameService(manager.tldContracts(TLD1));

        vm.prank(user1);
        ns.register{value: _price("test", 1)}("test", 1);

        // Fast forward past expiration
        vm.warp(block.timestamp + 2 * 365 days);

        (address owner_, uint256 exp, address nft, uint256 tokenId) = manager
            .resolve("test", TLD1);
        assertEq(owner_, address(0));
        assertEq(exp, 0);
        assertEq(nft, address(0));
        assertEq(tokenId, 0);
    }

    function testResolve_MultipleTLDs() public {
        manager.addTLD(TLD1);
        manager.addTLD(TLD2);
        NameService ns1 = NameService(manager.tldContracts(TLD1));
        NameService ns2 = NameService(manager.tldContracts(TLD2));

        vm.startPrank(user1);
        ns1.register{value: _price("test", 1)}("test", 1);
        ns2.register{value: _price("test", 1)}("test", 1);
        vm.stopPrank();

        (address owner1, uint256 exp1, address nft1, uint256 tokenId1) = manager
            .resolve("test", TLD1);
        (address owner2, uint256 exp2, address nft2, uint256 tokenId2) = manager
            .resolve("test", TLD2);

        assertEq(owner1, user1);
        assertEq(owner2, user1);
        assertEq(nft1, address(ns1));
        assertEq(nft2, address(ns2));
        assertGt(exp1, block.timestamp);
        assertGt(exp2, block.timestamp);
        assertGt(tokenId1, 0);
        assertGt(tokenId2, 0);
    }

    // ============ ADD DOMAIN TO ADDRESS TESTS ============

    function testAddDomainToAddress_Basic() public {
        manager.addTLD(TLD1);
        NameService ns = NameService(manager.tldContracts(TLD1));

        vm.startPrank(user1);
        ns.register{value: _price("test", 1)}("test", 1);
        vm.stopPrank();

        // Check that domain can be resolved
        (
            address owner_,
            uint256 expiration,
            address nftAddress,
            uint256 tokenId
        ) = manager.resolve("test", TLD1);
        assertEq(owner_, user1);
        assertTrue(expiration > block.timestamp);
        assertEq(nftAddress, address(ns));
        assertTrue(tokenId > 0);
    }

    function testAddDomainToAddress_MultipleDomains() public {
        manager.addTLD(TLD1);
        NameService ns = NameService(manager.tldContracts(TLD1));

        vm.startPrank(user1);
        ns.register{value: _price("test1", 1)}("test1", 1);
        ns.register{value: _price("test2", 1)}("test2", 1);
        ns.register{value: _price("test3", 1)}("test3", 1);
        vm.stopPrank();

        // Check that domains can be resolved
        (
            address owner1,
            uint256 expiration1,
            address nftAddress1,
            uint256 tokenId1
        ) = manager.resolve("test1", TLD1);
        (
            address owner2,
            uint256 expiration2,
            address nftAddress2,
            uint256 tokenId2
        ) = manager.resolve("test2", TLD1);
        (
            address owner3,
            uint256 expiration3,
            address nftAddress3,
            uint256 tokenId3
        ) = manager.resolve("test3", TLD1);

        assertEq(owner1, user1);
        assertEq(owner2, user1);
        assertEq(owner3, user1);
        assertTrue(expiration1 > block.timestamp);
        assertTrue(expiration2 > block.timestamp);
        assertTrue(expiration3 > block.timestamp);
        assertEq(nftAddress1, address(ns));
        assertEq(nftAddress2, address(ns));
        assertEq(nftAddress3, address(ns));
        assertTrue(tokenId1 > 0);
        assertTrue(tokenId2 > 0);
        assertTrue(tokenId3 > 0);
    }

    function testAddDomainToAddress_AutoMainDomain() public {
        manager.addTLD(TLD1);
        NameService ns = NameService(manager.tldContracts(TLD1));

        vm.startPrank(user1);
        ns.register{value: _price("test", 1)}("test", 1);
        vm.stopPrank();

        // First domain should be auto-set as main
        assertEq(manager.mainDomain(user1), "test.hotdogs");
    }

    function testAddDomainToAddress_OnlyNS() public {
        vm.expectRevert(abi.encodeWithSelector(HNSManager.UnAuth.selector));
        manager.addDomainToAddress(user1, "test.hotdogs");
    }

    // ============ REMOVE DOMAIN FROM ADDRESS TESTS ============

    function testRemoveDomainFromAddress_Basic() public {
        manager.addTLD(TLD1);
        NameService ns = NameService(manager.tldContracts(TLD1));

        vm.startPrank(user1);
        ns.register{value: _price("test1", 1)}("test1", 1);
        ns.register{value: _price("test2", 5)}("test2", 5);
        vm.stopPrank();

        // Simulate domain expiration
        vm.warp(block.timestamp + 2 * 365 days);
        ns.cleanupExpiredDomains(2);

        // Check that only the non-expired domain can be resolved
        (
            address owner1,
            uint256 expiration1,
            address nftAddress1,
            uint256 tokenId1
        ) = manager.resolve("test1", TLD1);
        (
            address owner2,
            uint256 expiration2,
            address nftAddress2,
            uint256 tokenId2
        ) = manager.resolve("test2", TLD1);

        // test1 should be expired (not resolvable)
        assertEq(owner1, address(0));
        assertEq(expiration1, 0);
        assertEq(nftAddress1, address(0));
        assertEq(tokenId1, 0);

        // test2 should still be valid
        assertEq(owner2, user1);
        assertTrue(expiration2 > block.timestamp);
        assertEq(nftAddress2, address(ns));
        assertTrue(tokenId2 > 0);
    }

    function testRemoveDomainFromAddress_MainDomainRemoval() public {
        manager.addTLD(TLD1);
        NameService ns = NameService(manager.tldContracts(TLD1));

        vm.startPrank(user1);
        ns.register{value: _price("test1", 1)}("test1", 1);
        ns.register{value: _price("test2", 5)}("test2", 5);
        vm.stopPrank();

        vm.prank(user1);
        manager.setMainDomain("test1", "hotdogs");

        // Simulate main domain expiration
        vm.warp(block.timestamp + 2 * 365 days);
        ns.cleanupExpiredDomains(2);

        // Main domain should be updated to remaining domain
        assertEq(manager.mainDomain(user1), "test2.hotdogs");
    }

    function testRemoveDomainFromAddress_AllDomainsRemoved() public {
        manager.addTLD(TLD1);
        NameService ns = NameService(manager.tldContracts(TLD1));

        vm.startPrank(user1);
        ns.register{value: _price("test", 1)}("test", 1);
        vm.stopPrank();

        vm.prank(user1);
        manager.setMainDomain("test", "hotdogs");

        // Simulate domain expiration
        vm.warp(block.timestamp + 2 * 365 days);
        ns.cleanupExpiredDomains(5);

        // All domains removed, main should be empty
        assertEq(manager.mainDomain(user1), "");

        // Domain should not be resolvable
        (
            address owner_,
            uint256 expiration,
            address nftAddress,
            uint256 tokenId
        ) = manager.resolve("test", TLD1);
        assertEq(owner_, address(0));
        assertEq(expiration, 0);
        assertEq(nftAddress, address(0));
        assertEq(tokenId, 0);
    }

    function testRemoveDomainFromAddress_OnlyNS() public {
        vm.expectRevert(abi.encodeWithSelector(HNSManager.UnAuth.selector));
        manager.removeDomainFromAddress(user1, "test.hotdogs");
    }

    // ============ RECEIVE FUNCTION TESTS ============

    function testReceive() public {
        uint256 amount = 1 ether;
        vm.deal(address(this), amount);

        (bool success, ) = address(manager).call{value: amount}("");
        assertTrue(success);
        assertEq(address(manager).balance, amount);
    }

    function testReceive_LargeAmount() public {
        uint256 amount = 1000 ether;
        vm.deal(address(this), amount);

        (bool success, ) = address(manager).call{value: amount}("");
        assertTrue(success);
        assertEq(address(manager).balance, amount);
    }

    // ============ EDGE CASES AND STRESS TESTS ============

    function testManyTLDs() public {
        // Add many TLDs
        string memory mstr = "tld";
        for (uint i = 0; i < 5; i++) {
            manager.addTLD(mstr);
            assertTrue(manager.tldContracts(mstr) != address(0));
            mstr = string(abi.encodePacked(mstr, "a"));
        }
    }

    function testManyDomainsPerUser() public {
        manager.addTLD(TLD1);
        NameService ns = NameService(manager.tldContracts(TLD1));

        vm.startPrank(user1);
        // Register many domains
        for (uint i = 0; i < 5; i++) {
            string memory name = string(
                abi.encodePacked("test", vm.toString(i))
            );
            ns.register{value: _price(name, 1)}(name, 1);
        }
        vm.stopPrank();

        // Check that all domains can be resolved
        for (uint i = 0; i < 5; i++) {
            string memory name = string(
                abi.encodePacked("test", vm.toString(i))
            );
            (
                address owner_,
                uint256 expiration,
                address nftAddress,
                uint256 tokenId
            ) = manager.resolve(name, TLD1);
            assertEq(owner_, user1);
            assertTrue(expiration > block.timestamp);
            assertEq(nftAddress, address(ns));
            assertTrue(tokenId > 0);
        }
    }

    function testComplexWorkflow() public {
        // Add multiple TLDs
        manager.addTLD(TLD1);
        manager.addTLD(TLD2);
        NameService ns1 = NameService(manager.tldContracts(TLD1));
        NameService ns2 = NameService(manager.tldContracts(TLD2));

        // Register domains in both TLDs
        vm.startPrank(user1);
        ns1.register{value: _price("test1", 1)}("test1", 1);
        ns2.register{value: _price("test2", 1)}("test2", 1);
        vm.stopPrank();

        // Set main domain
        vm.prank(user1);
        manager.setMainDomain("test1", "hotdogs");

        // Verify reverse lookup
        assertEq(manager.reverseLookup(user1), "test1.hotdogs");

        // Verify resolution
        (address owner_, uint256 exp, address nft, uint256 tokenId) = manager
            .resolve("test1", TLD1);
        assertEq(owner_, user1);
        assertEq(nft, address(ns1));
        assertGt(exp, block.timestamp);
        assertGt(tokenId, 0);

        // Change main domain
        vm.prank(user1);
        manager.setMainDomain("test2", "rise");

        // Verify new main domain
        assertEq(manager.reverseLookup(user1), "test2.rise");
    }

    function testGasOptimization() public {
        manager.addTLD(TLD1);
        NameService ns = NameService(manager.tldContracts(TLD1));

        // Test gas usage for multiple operations
        vm.startPrank(user1);
        for (uint i = 0; i < 3; i++) {
            string memory name = string(
                abi.encodePacked("test", vm.toString(i))
            );
            ns.register{value: _price(name, 1)}(name, 1);
        }
        vm.stopPrank();

        // All operations should succeed - check that domains can be resolved
        for (uint i = 0; i < 3; i++) {
            string memory name = string(
                abi.encodePacked("test", vm.toString(i))
            );
            (
                address owner_,
                uint256 expiration,
                address nftAddress,
                uint256 tokenId
            ) = manager.resolve(name, TLD1);
            assertEq(owner_, user1);
            assertTrue(expiration > block.timestamp);
            assertEq(nftAddress, address(ns));
            assertTrue(tokenId > 0);
        }
    }

    receive() external payable {}
}
