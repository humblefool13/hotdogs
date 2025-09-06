// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/HNSManager.sol";
import "../src/NameService.sol";
import "../src/DomainUtils.sol";
import "../src/MinHeap.sol";
import "../src/SVGLibrary.sol";
import "../src/TokenURILibrary.sol";

contract HNSTest is Test {
    HNSManager public manager;
    NameService public nameService1;
    NameService public nameService2;
    NameService public nameService3;

    address public owner = address(this);
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public user3 = address(0x3);
    address public user4 = address(0x4);
    address public user5 = address(0x5);
    address public devFeeRecipient = 0x4E08fF4CE98523F7B1299AAE51F515BA64BAf679;

    string public constant TLD1 = "hotdogs";
    string public constant TLD2 = "rise";
    string public constant TLD3 = "test";

    uint256 public constant YEAR = 365 days;

    // Event definitions for testing
    event DomainRegistered(
        string indexed name,
        address indexed owner,
        uint256 tokenId,
        uint256 expiration
    );
    event DomainRenewed(
        string indexed name,
        address indexed owner,
        uint256 newExpiration
    );
    event DomainTransferred(
        string indexed name,
        address indexed from,
        address indexed to
    );

    // Mirror events for expectEmit
    event TLDAdded(string indexed tld, address indexed tldContract);
    event FundsWithdrawn(address indexed recipient, uint256 amount);

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

    function setUp() public {
        manager = new HNSManager();

        // Add TLDs
        manager.addTLD(TLD1);
        manager.addTLD(TLD2);
        manager.addTLD(TLD3);

        // Get deployed NameService contracts
        nameService1 = NameService(manager.tldContracts(TLD1));
        nameService2 = NameService(manager.tldContracts(TLD2));
        nameService3 = NameService(manager.tldContracts(TLD3));

        // Fund users
        vm.deal(user1, 1000 ether);
        vm.deal(user2, 1000 ether);
        vm.deal(user3, 1000 ether);
        vm.deal(user4, 1000 ether);
        vm.deal(user5, 1000 ether);
    }

    // ============ CONSTRUCTOR TESTS ============

    function testConstructor() public {
        assertEq(manager.owner(), owner);
        assertTrue(manager.svgLibrary() != address(0));
        assertEq(manager.registeredTLDs(0), TLD1);
        assertEq(manager.registeredTLDs(1), TLD2);
        assertEq(manager.registeredTLDs(2), TLD3);
    }

    function testConstructorSVGLibraryDeployed() public {
        address svgLib = manager.svgLibrary();
        assertTrue(svgLib != address(0));

        // Verify it's a valid contract
        uint256 size;
        assembly {
            size := extcodesize(svgLib)
        }
        assertTrue(size > 0);
    }

    // ============ TLD MANAGEMENT TESTS ============

    function testAddTLD() public {
        string memory newTLD = "newtld";
        manager.addTLD(newTLD);

        assertTrue(manager.validNSAddress(manager.tldContracts(newTLD)));
        NameService nameService = NameService(manager.tldContracts(newTLD));
        assertEq(nameService.tld(), newTLD);
        assertEq(nameService.hnsManager(), address(manager));
        assertEq(nameService.svgLibrary(), manager.svgLibrary());
    }

    function testAddTLDAlreadyExists() public {
        vm.expectRevert(abi.encodeWithSelector(HNSManager.TLDExists.selector));
        manager.addTLD(TLD1);
    }

    function testAddTLDInvalidEmpty() public {
        vm.expectRevert(abi.encodeWithSelector(HNSManager.InvalidTLD.selector));
        manager.addTLD("");
    }

    function testAddTLDInvalidTooLong() public {
        string memory longTLD = "thisiswaytoolongforatld";
        vm.expectRevert(abi.encodeWithSelector(HNSManager.InvalidTLD.selector));
        manager.addTLD(longTLD);
    }

    function testRegisteredTLDsAndMappings() public {
        // Verify mapping presence for initial TLDs
        assertTrue(manager.tldContracts(TLD1) != address(0));
        assertTrue(manager.tldContracts(TLD2) != address(0));
        assertTrue(manager.tldContracts(TLD3) != address(0));

        // Verify registeredTLDs indices hold the same values
        assertEq(manager.registeredTLDs(0), TLD1);
        assertEq(manager.registeredTLDs(1), TLD2);
        assertEq(manager.registeredTLDs(2), TLD3);
    }

    function testValidNSAddressMapping() public {
        address ns1 = manager.tldContracts(TLD1);
        address ns2 = manager.tldContracts(TLD2);

        assertTrue(manager.validNSAddress(ns1));
        assertTrue(manager.validNSAddress(ns2));
        assertFalse(manager.validNSAddress(address(0x123)));
    }

    // ============ FUNDS WITHDRAWAL TESTS ============

    function testWithdrawFunds() public {
        // Send some ETH to the manager
        vm.deal(address(manager), 1 ether);

        uint256 initialBalance = owner.balance;
        manager.withdrawFunds();

        assertEq(owner.balance, initialBalance + 1 ether);
        assertEq(address(manager).balance, 0);
    }

    function testWithdrawFundsNoFunds() public {
        vm.expectRevert(abi.encodeWithSelector(HNSManager.NoFunds.selector));
        manager.withdrawFunds();
    }

    function testWithdrawFundsEventEmitted() public {
        vm.deal(address(manager), 0.5 ether);

        vm.expectEmit(true, false, false, true);
        emit FundsWithdrawn(owner, 0.5 ether);

        manager.withdrawFunds();
    }

    function testWithdrawFundsOnlyOwner() public {
        vm.deal(address(manager), 1 ether);

        vm.prank(user1);
        vm.expectRevert();
        manager.withdrawFunds();
    }

    // ============ MAIN DOMAIN TESTS ============

    function testSetMainDomain() public {
        // Register a domain first
        vm.startPrank(user1);
        nameService1.register{value: _price("test", 1)}("test", 1);
        vm.stopPrank();

        // Set main domain
        vm.prank(user1);
        manager.setMainDomain("test", "hotdogs");

        assertEq(manager.mainDomain(user1), "test.hotdogs");
    }

    function testSetMainDomainUnauthorized() public {
        // Register domain with user1
        vm.startPrank(user1);
        nameService1.register{value: _price("test", 1)}("test", 1);
        vm.stopPrank();

        // Try to set main domain with user2
        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSelector(HNSManager.NoDomain.selector));
        manager.setMainDomain("test", "hotdogs");
    }

    function testSetMainDomainTLDNotFound() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(HNSManager.InvalidTLD.selector));
        manager.setMainDomain("test", "nonexistent");
    }

    function testSetMainDomainDomainNotFound() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(HNSManager.InvalidTLD.selector));
        manager.setMainDomain("nonexistent", "hotdogs");
    }

    function testSetMainDomainOverwrite() public {
        // Register domains
        vm.startPrank(user1);
        nameService1.register{value: _price("test1", 1)}("test1", 1);
        nameService1.register{value: _price("test2", 1)}("test2", 1);
        vm.stopPrank();

        // Set first main domain
        vm.prank(user1);
        manager.setMainDomain("test1", "hotdogs");
        assertEq(manager.mainDomain(user1), "test1.hotdogs");

        // Overwrite with second domain
        vm.prank(user1);
        manager.setMainDomain("test2", "hotdogs");
        assertEq(manager.mainDomain(user1), "test2.hotdogs");
    }

    // ============ REVERSE LOOKUP TESTS ============

    function testReverseLookupMainDomain() public {
        // Register domains
        vm.startPrank(user1);
        uint256 price1 = nameService1._calculatePrice("test1", 1);
        uint256 price2 = nameService1._calculatePrice("test2", 1);

        nameService1.register{value: price1}("test1", 1);
        nameService1.register{value: price2}("test2", 1);
        vm.stopPrank();

        // Set main domain
        vm.prank(user1);
        manager.setMainDomain("test2", "hotdogs");

        // Reverse lookup should return main domain
        assertEq(manager.reverseLookup(user1), "test2.hotdogs");
    }

    function testReverseLookupNoMainDomain() public {
        // Register domain
        vm.startPrank(user1);
        uint256 price = nameService1._calculatePrice("test", 1);
        nameService1.register{value: price}("test", 1);
        vm.stopPrank();

        // No main domain set, should return first domain
        assertEq(manager.reverseLookup(user1), "test.hotdogs");
    }

    function testReverseLookupNoDomains() public {
        assertEq(manager.reverseLookup(user1), "");
    }

    function testReverseLookupMultipleTLDs() public {
        // Register domains in both TLDs
        vm.startPrank(user1);
        nameService1.register{value: _price("test1", 1)}("test1", 1);
        nameService2.register{value: _price("test2", 1)}("test2", 1);
        vm.stopPrank();

        // Set main domain from second TLD
        vm.prank(user1);
        manager.setMainDomain("test2", "rise");

        // Should return main domain
        assertEq(manager.reverseLookup(user1), "test2.rise");
    }

    // ============ DOMAIN RESOLUTION TESTS ============

    function testResolve() public {
        // Register domain
        vm.startPrank(user1);
        nameService1.register{value: _price("test", 1)}("test", 1);
        vm.stopPrank();

        (
            address owner_,
            uint256 expiration,
            address nftAddress,
            uint256 tokenId
        ) = manager.resolve("test", TLD1);

        assertEq(owner_, user1);
        assertTrue(expiration > block.timestamp);
        assertEq(nftAddress, address(nameService1));
        assertTrue(tokenId > 0);
    }

    function testResolveTLDNotFound() public {
        vm.expectRevert(abi.encodeWithSelector(HNSManager.InvalidTLD.selector));
        manager.resolve("test", "nonexistent");
    }

    function testResolveDomainNotFound() public {
        (
            address owner_,
            uint256 expiration,
            address nftAddress,
            uint256 tokenId
        ) = manager.resolve("nonexistent", TLD1);

        assertEq(owner_, address(0));
        assertEq(expiration, 0);
        assertEq(nftAddress, address(0));
        assertEq(tokenId, 0);
    }

    function testResolveExpiredDomain() public {
        // Register domain
        vm.startPrank(user1);
        uint256 price = nameService1._calculatePrice("test", 1);
        nameService1.register{value: price}("test", 1);
        vm.stopPrank();

        // Fast forward past expiration
        vm.warp(block.timestamp + 2 * YEAR);

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

    // ============ COMPREHENSIVE INTEGRATION TESTS ============

    function testFullWorkflow() public {
        // 1. Register domains in multiple TLDs
        vm.startPrank(user1);
        nameService1.register{value: _price("alice", 1)}("alice", 1);
        nameService2.register{value: _price("bob", 1)}("bob", 1);
        nameService3.register{value: _price("charlie", 1)}("charlie", 1);
        vm.stopPrank();

        // 2. Set main domain
        vm.prank(user1);
        manager.setMainDomain("alice", "hotdogs");

        // 3. Verify reverse lookup
        assertEq(manager.reverseLookup(user1), "alice.hotdogs");

        // 4. Verify resolution
        (address owner_, uint256 exp, address nft, uint256 tokenId) = manager
            .resolve("alice", TLD1);
        assertEq(owner_, user1);
        assertEq(nft, address(nameService1));
        assertGt(exp, block.timestamp);
        assertGt(tokenId, 0);

        // 5. Transfer domain
        vm.prank(user1);
        nameService1.transferDomain("alice", user2);

        // 6. Verify new owner
        assertEq(nameService1.getDomainOwner("alice"), user2);
        assertEq(manager.reverseLookup(user2), "alice.hotdogs");

        // 7. Renew domain
        vm.prank(user2);
        nameService1.renew{value: _price("alice", 2)}("alice", 2);

        // 8. Verify extended expiration
        uint256 newExp = nameService1.getDomainExpiration("alice");
        assertGt(newExp, block.timestamp + 365 days);
    }

    function testMultipleUsersWorkflow() public {
        // User1 registers in TLD1
        vm.prank(user1);
        nameService1.register{value: _price("user1", 1)}("user1", 1);

        // User2 registers in TLD2
        vm.prank(user2);
        nameService2.register{value: _price("user2", 1)}("user2", 1);

        // User3 registers in TLD3
        vm.prank(user3);
        nameService3.register{value: _price("user3", 1)}("user3", 1);

        // Set main domains
        vm.prank(user1);
        manager.setMainDomain("user1", "hotdogs");

        vm.prank(user2);
        manager.setMainDomain("user2", "rise");

        vm.prank(user3);
        manager.setMainDomain("user3", "test");

        // Verify reverse lookups
        assertEq(manager.reverseLookup(user1), "user1.hotdogs");
        assertEq(manager.reverseLookup(user2), "user2.rise");
        assertEq(manager.reverseLookup(user3), "user3.test");

        // Verify resolutions
        (address owner1, , , ) = manager.resolve("user1", TLD1);
        (address owner2, , , ) = manager.resolve("user2", TLD2);
        (address owner3, , , ) = manager.resolve("user3", TLD3);

        assertEq(owner1, user1);
        assertEq(owner2, user2);
        assertEq(owner3, user3);
    }

    function testDomainExpirationWorkflow() public {
        // Register domain
        vm.prank(user1);
        nameService1.register{value: _price("expire", 1)}("expire", 1);

        // Set as main domain
        vm.prank(user1);
        manager.setMainDomain("expire", "hotdogs");

        // Verify initial state
        assertEq(manager.reverseLookup(user1), "expire.hotdogs");
        assertEq(nameService1.getDomainOwner("expire"), user1);

        // Fast forward past expiration
        vm.warp(block.timestamp + 2 * YEAR);

        // Check and burn expired domains
        nameService1.cleanupExpiredDomains(1);

        // Verify domain is expired
        assertEq(nameService1.getDomainOwner("expire"), address(0));
        assertTrue(nameService1.isDomainAvailable("expire"));
        assertEq(manager.reverseLookup(user1), "");

        // Re-register domain
        vm.prank(user2);
        nameService1.register{value: _price("expire", 1)}("expire", 1);

        // Verify new owner
        assertEq(nameService1.getDomainOwner("expire"), user2);
        assertEq(manager.reverseLookup(user2), "expire.hotdogs");
    }

    function testComplexTransferWorkflow() public {
        // Register domain
        vm.prank(user1);
        nameService1.register{value: _price("transfer", 1)}("transfer", 1);

        // Set as main domain
        vm.prank(user1);
        manager.setMainDomain("transfer", "hotdogs");

        // Transfer via NFT
        uint256 tokenId = nameService1.domainToToken("transfer");
        vm.prank(user1);
        nameService1.transferFrom(user1, user2, tokenId);

        // Verify new owner
        assertEq(nameService1.getDomainOwner("transfer"), user2);
        assertEq(manager.reverseLookup(user2), "transfer.hotdogs");
        assertEq(manager.reverseLookup(user1), "");

        // Transfer via domain function
        vm.prank(user2);
        nameService1.transferDomain("transfer", user3);

        // Verify final owner
        assertEq(nameService1.getDomainOwner("transfer"), user3);
        assertEq(manager.reverseLookup(user3), "transfer.hotdogs");
        assertEq(manager.reverseLookup(user2), "");
    }

    function testBatchOperations() public {
        // Register multiple domains
        vm.startPrank(user1);
        for (uint i = 0; i < 5; i++) {
            string memory name = string(
                abi.encodePacked("batch", vm.toString(i))
            );
            nameService1.register{value: _price(name, 1)}(name, 1);
        }
        vm.stopPrank();

        // Set main domain
        vm.prank(user1);
        manager.setMainDomain("batch0", "hotdogs");

        // Verify all domains are registered
        assertEq(nameService1.getTotalDomainCount(), 5);
        assertEq(manager.reverseLookup(user1), "batch0.hotdogs");

        // Fast forward and expire all
        vm.warp(block.timestamp + 2 * YEAR);
        nameService1.cleanupExpiredDomains(5);

        // Verify all domains are expired
        assertEq(nameService1.getTotalDomainCount(), 0);
        assertEq(manager.reverseLookup(user1), "");
    }

    function testPricingConsistency() public {
        // Test pricing across different name lengths
        assertEq(nameService1._calculatePrice("abc", 1), 0.012 ether);
        assertEq(nameService1._calculatePrice("abcd", 1), 0.01 ether);
        assertEq(nameService1._calculatePrice("abcde", 1), 0.008 ether);
        assertEq(nameService1._calculatePrice("abcdef", 1), 0.006 ether);
        assertEq(nameService1._calculatePrice("abcdefg", 1), 0.004 ether);

        // Test multiple years
        assertEq(nameService1._calculatePrice("test", 5), 0.01 ether * 5);
    }

    function testEventEmission() public {
        // Test domain registration event
        vm.startPrank(user1);
        vm.expectEmit(true, true, false, false);
        emit DomainRegistered(
            "eventtest",
            user1,
            1,
            block.timestamp + 365 days
        );
        nameService1.register{value: _price("eventtest", 1)}("eventtest", 1);
        vm.stopPrank();

        // Test domain renewal event
        vm.prank(user1);
        vm.expectEmit(true, true, false, false);
        emit DomainRenewed("eventtest", user1, block.timestamp + 365 days);
        nameService1.renew{value: _price("eventtest", 1)}("eventtest", 1);

        // Test domain transfer event
        vm.prank(user1);
        vm.expectEmit(true, true, true, false);
        emit DomainTransferred("eventtest", user1, user2);
        nameService1.transferDomain("eventtest", user2);
    }

    function testGasOptimization() public {
        // Test gas usage for multiple operations
        uint256 gasStart = gasleft();

        vm.startPrank(user1);
        nameService1.register{value: _price("gas1", 1)}("gas1", 1);
        nameService1.register{value: _price("gas2", 1)}("gas2", 1);
        nameService1.register{value: _price("gas3", 1)}("gas3", 1);
        vm.stopPrank();

        vm.prank(user1);
        manager.setMainDomain("gas1", "hotdogs");

        vm.prank(user1);
        nameService1.renew{value: _price("gas1", 1)}("gas1", 1);

        vm.prank(user1);
        nameService1.transferDomain("gas1", user2);

        uint256 gasUsed = gasStart - gasleft();
        console.log("Gas used for complex operations:", gasUsed);

        // All operations should succeed
        assertEq(nameService1.getDomainOwner("gas1"), user2);
        assertEq(manager.reverseLookup(user2), "gas1.hotdogs");
    }

    function testEdgeCases() public {
        // Test empty string handling
        assertEq(manager.reverseLookup(address(0x999)), "");

        // Test non-existent domain resolution
        (address owner_, uint256 exp, address nft, uint256 tokenId) = manager
            .resolve("nonexistent", TLD1);
        assertEq(owner_, address(0));
        assertEq(exp, 0);
        assertEq(nft, address(0));
        assertEq(tokenId, 0);

        // Test invalid TLD resolution
        vm.expectRevert(abi.encodeWithSelector(HNSManager.InvalidTLD.selector));
        manager.resolve("test", "invalid");

        // Test zero address transfers
        vm.prank(user1);
        nameService1.register{value: _price("test", 1)}("test", 1);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(NameService.ZeroAddr.selector));
        nameService1.transferDomain("test", address(0));
    }

    function testStressTest() public {
        // Register many domains across multiple TLDs
        vm.startPrank(user1);
        for (uint i = 0; i < 10; i++) {
            string memory name1 = string(
                abi.encodePacked("stress1", vm.toString(i))
            );
            string memory name2 = string(
                abi.encodePacked("stress2", vm.toString(i))
            );
            string memory name3 = string(
                abi.encodePacked("stress3", vm.toString(i))
            );

            nameService1.register{value: _price(name1, 1)}(name1, 1);
            nameService2.register{value: _price(name2, 1)}(name2, 1);
            nameService3.register{value: _price(name3, 1)}(name3, 1);
        }
        vm.stopPrank();

        // Set main domains
        vm.prank(user1);
        manager.setMainDomain("stress10", "hotdogs");

        // Verify all operations work
        assertEq(nameService1.getTotalDomainCount(), 10);
        assertEq(nameService2.getTotalDomainCount(), 10);
        assertEq(nameService3.getTotalDomainCount(), 10);
        assertEq(manager.reverseLookup(user1), "stress10.hotdogs");

        // Test resolution
        (address owner_, , , ) = manager.resolve("stress10", TLD1);
        assertEq(owner_, user1);
    }

    receive() external payable {}
}
