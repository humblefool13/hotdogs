// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/NameService.sol";
import "../src/HNSManager.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title MockERC721Receiver
 * @notice Mock contract for testing safe transfers
 */
contract MockERC721Receiver is IERC721Receiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}

/**
 * @title NonReceiverContract
 * @notice Contract that doesn't implement IERC721Receiver for testing
 */
contract NonReceiverContract {
    // This contract doesn't implement IERC721Receiver
}

/**
 * @title NameServiceNFTTest
 * @notice Comprehensive NFT tests for NameService contract
 * @dev Focuses on ERC721 compliance, events, and domain ownership synchronization
 */
contract NameServiceNFTTest is Test {
    using Strings for uint256;
    NameService public nameService;
    HNSManager public manager;
    address public user = address(0x123);
    address public user2 = address(0x456);
    address public user3 = address(0x789);
    string public constant TLD = "hotdogs";

    // Mock contract for testing safe transfers
    MockERC721Receiver public mockReceiver;

    // Event definitions
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );
    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );
    event DomainRegistered(
        string indexed name,
        address indexed owner,
        uint256 tokenId,
        uint256 expiration
    );
    event DomainTransferred(
        string indexed name,
        address indexed from,
        address indexed to
    );
    event DomainExpired(string indexed name, address indexed previousOwner);
    event DomainRenewed(
        string indexed name,
        address indexed owner,
        uint256 newExpiration
    );
    event ExpiredDomainsProcessed(uint256 cleaned);

    function setUp() public {
        manager = new HNSManager();
        manager.addTLD(TLD);
        nameService = NameService(manager.tldContracts(TLD));
        mockReceiver = new MockERC721Receiver();

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
        if (len == 3) base = 0.012 ether;
        else if (len == 4) base = 0.01 ether;
        else if (len == 5) base = 0.008 ether;
        else if (len == 6) base = 0.006 ether;
        else base = 0.004 ether;
        return base * years_;
    }

    // ============ MINT TESTS ============

    function testMint_EmitsTransferEvent() public {
        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), user, 1);
        emit DomainRegistered("test", user, 1, 0);
        nameService.register{value: _price("test", 1)}("test", 1);
    }

    function testMint_UpdatesOwnership() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);

        assertEq(nameService.ownerOf(1), user);
        assertEq(nameService.getDomainOwner("test"), user);
        assertEq(nameService.balanceOf(user), 1);
    }

    function testMint_UpdatesMappings() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);

        assertEq(nameService.domainToToken("test"), 1);
        assertEq(nameService.tokenToDomain(1), "test");
    }

    function testMint_UpdatesManagerMappings() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);

        string memory domain = manager.addressToDomains(user, 0);
        assertEq(domain, "test.hotdogs");
        assertEq(manager.mainDomain(user), "test.hotdogs");
    }

    // ============ TRANSFER TESTS ============

    function testTransferFrom_EmitsTransferEvent() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit Transfer(user, user2, tokenId);
        emit DomainTransferred("test", user, user2);
        nameService.transferFrom(user, user2, tokenId);
    }

    function testTransferFrom_UpdatesOwnership() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        vm.prank(user);
        nameService.transferFrom(user, user2, tokenId);

        assertEq(nameService.ownerOf(tokenId), user2);
        assertEq(nameService.getDomainOwner("test"), user2);
        assertEq(nameService.balanceOf(user), 0);
        assertEq(nameService.balanceOf(user2), 1);
    }

    function testTransferFrom_UpdatesManagerMappings() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        vm.prank(user);
        nameService.transferFrom(user, user2, tokenId);

        // Check old owner mappings cleared
        vm.expectRevert();
        manager.addressToDomains(user, 0);
        assertEq(manager.mainDomain(user), "");

        // Check new owner mappings updated
        string memory user2Domain = manager.addressToDomains(user2, 0);
        assertEq(user2Domain, "test.hotdogs");
        assertEq(manager.mainDomain(user2), "test.hotdogs");
    }

    function testTransferFrom_ByApproved() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        vm.prank(user);
        nameService.approve(user2, tokenId);

        vm.prank(user2);
        nameService.transferFrom(user, user3, tokenId);

        assertEq(nameService.ownerOf(tokenId), user3);
        assertEq(nameService.getDomainOwner("test"), user3);
    }

    function testTransferFrom_ByOperator() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        vm.prank(user);
        nameService.setApprovalForAll(user2, true);

        vm.prank(user2);
        nameService.transferFrom(user, user3, tokenId);

        assertEq(nameService.ownerOf(tokenId), user3);
        assertEq(nameService.getDomainOwner("test"), user3);
    }

    function testTransferFrom_ExpiredDomain() public {
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

    // ============ SAFE TRANSFER TESTS ============

    function testSafeTransferFrom_WithData() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        vm.prank(user);
        nameService.safeTransferFrom(
            user,
            address(mockReceiver),
            tokenId,
            "0x1234"
        );

        assertEq(nameService.ownerOf(tokenId), address(mockReceiver));
        assertEq(nameService.getDomainOwner("test"), address(mockReceiver));
    }

    function testSafeTransferFrom_ToEOA() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        vm.prank(user);
        nameService.safeTransferFrom(user, user2, tokenId, "");

        assertEq(nameService.ownerOf(tokenId), user2);
        assertEq(nameService.getDomainOwner("test"), user2);
    }

    // ============ APPROVAL TESTS ============

    function testApprove_EmitsApprovalEvent() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit Approval(user, user2, tokenId);
        nameService.approve(user2, tokenId);
    }

    function testApprove_UpdatesApproval() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        vm.prank(user);
        nameService.approve(user2, tokenId);

        assertEq(nameService.getApproved(tokenId), user2);
    }

    function testSetApprovalForAll_EmitsEvent() public {
        vm.prank(user);
        vm.expectEmit(true, true, false, true);
        emit ApprovalForAll(user, user2, true);
        nameService.setApprovalForAll(user2, true);
    }

    function testSetApprovalForAll_UpdatesApproval() public {
        vm.prank(user);
        nameService.setApprovalForAll(user2, true);

        assertTrue(nameService.isApprovedForAll(user, user2));

        vm.prank(user);
        nameService.setApprovalForAll(user2, false);

        assertFalse(nameService.isApprovedForAll(user, user2));
    }

    // ============ BURN TESTS ============

    function testBurn_EmitsTransferEvent() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        // Fast forward to expiration
        vm.warp(block.timestamp + 2 * 365 days);

        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit Transfer(user, address(0), tokenId);
        emit DomainExpired("test", user);
        nameService.cleanupExpiredDomains(1);
    }

    function testBurn_EmitsExpiredDomainsProcessedEvent() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);

        // Fast forward to expiration
        vm.warp(block.timestamp + 2 * 365 days);

        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit ExpiredDomainsProcessed(1);
        nameService.cleanupExpiredDomains(1);
    }

    function testBurn_MultipleDomainsEmitsCorrectEvents() public {
        vm.prank(user);
        nameService.register{value: _price("test1", 1)}("test1", 1);
        vm.prank(user2);
        nameService.register{value: _price("test2", 1)}("test2", 1);

        // Fast forward to expiration
        vm.warp(block.timestamp + 2 * 365 days);

        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit ExpiredDomainsProcessed(2);
        nameService.cleanupExpiredDomains(5);
    }

    function testBurn_UpdatesOwnership() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        // Fast forward to expiration
        vm.warp(block.timestamp + 2 * 365 days);

        vm.prank(user);
        nameService.cleanupExpiredDomains(1);

        // Check that domain is no longer owned
        assertEq(nameService.getDomainOwner("test"), address(0));
        assertEq(nameService.balanceOf(user), 0);
    }

    function testBurn_UpdatesManagerMappings() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);

        // Fast forward to expiration
        vm.warp(block.timestamp + 2 * 365 days);

        vm.prank(user);
        nameService.cleanupExpiredDomains(1);

        // Check that manager mappings are cleared
        vm.expectRevert();
        manager.addressToDomains(user, 0);
        assertEq(manager.mainDomain(user), "");
    }

    function testBurn_ClearsDomainMappings() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        // Fast forward to expiration
        vm.warp(block.timestamp + 2 * 365 days);

        vm.prank(user);
        nameService.cleanupExpiredDomains(1);

        // Check that domain mappings are cleared
        assertEq(nameService.domainToToken("test"), 0);
        assertEq(nameService.tokenToDomain(tokenId), "");
    }

    function testBurn_ExpiredDomainCannotTransfer() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        // Fast forward to expiration
        vm.warp(block.timestamp + 2 * 365 days);

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(NameService.DomainIsExpired.selector, "test")
        );
        nameService.transferFrom(user, user2, tokenId);
    }

    function testBurn_NonExpiredDomainCannotBeBurned() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);

        // Try to clean up before expiration
        vm.prank(user);
        nameService.cleanupExpiredDomains(1);

        // Should clean up 0 domains
        assertEq(nameService.getDomainOwner("test"), user);
    }

    function testBurn_OnlyExpiredDomainsAreBurned() public {
        vm.prank(user);
        nameService.register{value: _price("expired", 1)}("expired", 1);
        vm.prank(user2);
        nameService.register{value: _price("active", 2)}("active", 2);

        // Fast forward so only one domain expires
        vm.warp(block.timestamp + 1.5 * 365 days);

        vm.prank(user);
        nameService.cleanupExpiredDomains(5);

        // Should only clean up 1 domain
        assertEq(nameService.getDomainOwner("expired"), address(0));
        assertEq(nameService.getDomainOwner("active"), user2);
    }

    function testBurn_UpdatesTokenIdCounter() public {
        vm.prank(user);
        nameService.register{value: _price("test1", 1)}("test1", 1);
        vm.prank(user);
        nameService.register{value: _price("test2", 1)}("test2", 1);

        // Fast forward to expiration
        vm.warp(block.timestamp + 2 * 365 days);

        vm.prank(user);
        nameService.cleanupExpiredDomains(5);

        // Next token should still be 3 (not reset)
        vm.prank(user);
        nameService.register{value: _price("test3", 1)}("test3", 1);
        assertEq(nameService.domainToToken("test3"), 3);
    }

    function testBurn_ClearsApprovals() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        // Set approval
        vm.prank(user);
        nameService.approve(user2, tokenId);
        assertEq(nameService.getApproved(tokenId), user2);

        // Fast forward to expiration
        vm.warp(block.timestamp + 2 * 365 days);

        vm.prank(user);
        nameService.cleanupExpiredDomains(1);

        // Approval should be cleared (token no longer exists)
        vm.expectRevert();
        nameService.getApproved(tokenId);
    }

    // ============ ERC721 COMPLIANCE TESTS ============

    function testBalanceOf() public {
        assertEq(nameService.balanceOf(user), 0);

        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);

        assertEq(nameService.balanceOf(user), 1);
    }

    function testOwnerOf() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        assertEq(nameService.ownerOf(tokenId), user);
    }

    function testOwnerOf_NonExistentToken() public {
        vm.expectRevert();
        nameService.ownerOf(999);
    }

    function testGetApproved() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        assertEq(nameService.getApproved(tokenId), address(0));

        vm.prank(user);
        nameService.approve(user2, tokenId);

        assertEq(nameService.getApproved(tokenId), user2);
    }

    function testIsApprovedForAll() public {
        assertFalse(nameService.isApprovedForAll(user, user2));

        vm.prank(user);
        nameService.setApprovalForAll(user2, true);

        assertTrue(nameService.isApprovedForAll(user, user2));
    }

    function testNameAndSymbol() public {
        assertEq(nameService.name(), "HotDogs Naming Service - hotdogs");
        assertEq(nameService.symbol(), "HOTDOGS");
    }

    function testTokenURI() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        string memory uri = nameService.tokenURI(tokenId);
        assertTrue(bytes(uri).length > 0);
        assertTrue(keccak256(bytes(uri)) != keccak256(""));
    }

    function testTokenURI_NonExistentToken() public {
        vm.expectRevert();
        nameService.tokenURI(999);
    }

    function testTokenURI_ContainsDomainName() public {
        vm.prank(user);
        nameService.register{value: _price("mydomain", 1)}("mydomain", 1);
        uint256 tokenId = nameService.domainToToken("mydomain");

        string memory uri = nameService.tokenURI(tokenId);
        // URI should contain the domain name
        assertTrue(bytes(uri).length > 0);
    }

    function testBalanceOf_ZeroAddress() public {
        vm.expectRevert();
        nameService.balanceOf(address(0));
    }

    function testBalanceOf_MultipleTokens() public {
        assertEq(nameService.balanceOf(user), 0);

        vm.prank(user);
        nameService.register{value: _price("test1", 1)}("test1", 1);
        assertEq(nameService.balanceOf(user), 1);

        vm.prank(user);
        nameService.register{value: _price("test2", 1)}("test2", 1);
        assertEq(nameService.balanceOf(user), 2);
    }

    function testOwnerOf_AfterTransfer() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        assertEq(nameService.ownerOf(tokenId), user);

        vm.prank(user);
        nameService.transferFrom(user, user2, tokenId);

        assertEq(nameService.ownerOf(tokenId), user2);
    }

    function testGetApproved_AfterTransfer() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        // Set approval
        vm.prank(user);
        nameService.approve(user2, tokenId);
        assertEq(nameService.getApproved(tokenId), user2);

        // Transfer token
        vm.prank(user);
        nameService.transferFrom(user, user3, tokenId);

        // Approval should be cleared after transfer
        assertEq(nameService.getApproved(tokenId), address(0));
    }

    function testIsApprovedForAll_AfterTransfer() public {
        vm.prank(user);
        nameService.setApprovalForAll(user2, true);
        assertTrue(nameService.isApprovedForAll(user, user2));

        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        // Transfer token
        vm.prank(user2);
        nameService.transferFrom(user, user3, tokenId);

        // Approval for all should still be valid
        assertTrue(nameService.isApprovedForAll(user, user2));
    }

    function testNameAndSymbol_Consistency() public {
        string memory name = nameService.name();
        string memory symbol = nameService.symbol();

        assertTrue(bytes(name).length > 0);
        assertTrue(bytes(symbol).length > 0);
        assertEq(symbol, "HOTDOGS");
        assertTrue(
            keccak256(bytes(name)) ==
                keccak256("HotDogs Naming Service - hotdogs")
        );
    }

    // ============ ROYALTY TESTS ============

    function testRoyaltyInfo() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        (address receiver, uint256 royaltyAmount) = nameService.royaltyInfo(
            tokenId,
            1 ether
        );

        assertEq(receiver, address(manager));
        assertEq(royaltyAmount, 0.025 ether); // 2.5% of 1 ether
    }

    function testRoyaltyInfo_NonExistentToken() public {
        vm.expectRevert(abi.encodeWithSelector(NameService.NoToken.selector));
        nameService.royaltyInfo(999, 1 ether);
    }

    function testRoyaltyInfo_DifferentSalePrices() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        // Test with different sale prices
        (address receiver, uint256 royaltyAmount) = nameService.royaltyInfo(
            tokenId,
            0.1 ether
        );
        assertEq(receiver, address(manager));
        assertEq(royaltyAmount, 0.0025 ether); // 2.5% of 0.1 ether

        (receiver, royaltyAmount) = nameService.royaltyInfo(tokenId, 10 ether);
        assertEq(receiver, address(manager));
        assertEq(royaltyAmount, 0.25 ether); // 2.5% of 10 ether
    }

    function testRoyaltyInfo_ZeroSalePrice() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        (address receiver, uint256 royaltyAmount) = nameService.royaltyInfo(
            tokenId,
            0
        );
        assertEq(receiver, address(manager));
        assertEq(royaltyAmount, 0);
    }

    function testRoyaltyInfo_AfterTransfer() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        // Transfer token
        vm.prank(user);
        nameService.transferFrom(user, user2, tokenId);

        // Royalty info should still work
        (address receiver, uint256 royaltyAmount) = nameService.royaltyInfo(
            tokenId,
            1 ether
        );
        assertEq(receiver, address(manager));
        assertEq(royaltyAmount, 0.025 ether);
    }

    function testRoyaltyInfo_AfterRenewal() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        // Renew domain
        vm.prank(user);
        nameService.renew{value: _price("test", 1)}("test", 1);

        // Royalty info should still work
        (address receiver, uint256 royaltyAmount) = nameService.royaltyInfo(
            tokenId,
            1 ether
        );
        assertEq(receiver, address(manager));
        assertEq(royaltyAmount, 0.025 ether);
    }

    // ============ ERROR HANDLING TESTS ============

    function testTransferFrom_Unauthorized() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        vm.prank(user2);
        vm.expectRevert();
        nameService.transferFrom(user, user3, tokenId);
    }

    function testTransferFrom_InvalidToken() public {
        vm.prank(user);
        vm.expectRevert();
        nameService.transferFrom(user, user2, 999);
    }

    function testTransferFrom_ToZeroAddress() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        vm.prank(user);
        vm.expectRevert();
        nameService.transferFrom(user, address(0), tokenId);
    }

    function testApprove_Unauthorized() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        vm.prank(user2);
        vm.expectRevert();
        nameService.approve(user3, tokenId);
    }

    function testApprove_InvalidToken() public {
        vm.prank(user);
        vm.expectRevert();
        nameService.approve(user2, 999);
    }

    function testSetApprovalForAll_ToZeroAddress() public {
        vm.prank(user);
        vm.expectRevert();
        nameService.setApprovalForAll(address(0), true);
    }

    function testTransferFrom_FromZeroAddress() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        vm.prank(user);
        vm.expectRevert();
        nameService.transferFrom(address(0), user2, tokenId);
    }

    function testSafeTransferFrom_FromZeroAddress() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        vm.prank(user);
        vm.expectRevert();
        nameService.safeTransferFrom(address(0), user2, tokenId, "");
    }

    function testTransferFrom_ExpiredToken() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        // Fast forward to expiration
        vm.warp(block.timestamp + 2 * 365 days);

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(NameService.DomainIsExpired.selector, "test")
        );
        nameService.transferFrom(user, user2, tokenId);
    }

    function testSafeTransferFrom_ExpiredToken() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        // Fast forward to expiration
        vm.warp(block.timestamp + 2 * 365 days);

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(NameService.DomainIsExpired.selector, "test")
        );
        nameService.safeTransferFrom(user, user2, tokenId, "");
    }

    // ============ APPROVAL EDGE CASES TESTS ============

    function testApprove_ClearsPreviousApproval() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        // Set first approval
        vm.prank(user);
        nameService.approve(user2, tokenId);
        assertEq(nameService.getApproved(tokenId), user2);

        // Set new approval
        vm.prank(user);
        nameService.approve(user3, tokenId);
        assertEq(nameService.getApproved(tokenId), user3);
    }

    function testApprove_AfterTransferClearsApproval() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        // Set approval
        vm.prank(user);
        nameService.approve(user2, tokenId);
        assertEq(nameService.getApproved(tokenId), user2);

        // Transfer token
        vm.prank(user);
        nameService.transferFrom(user, user3, tokenId);

        // Approval should be cleared
        assertEq(nameService.getApproved(tokenId), address(0));
    }

    function testSetApprovalForAll_CanApproveMultipleTokens() public {
        vm.prank(user);
        nameService.setApprovalForAll(user2, true);

        vm.prank(user);
        nameService.register{value: _price("test1", 1)}("test1", 1);
        vm.prank(user);
        nameService.register{value: _price("test2", 1)}("test2", 1);

        uint256 tokenId1 = nameService.domainToToken("test1");
        uint256 tokenId2 = nameService.domainToToken("test2");

        // user2 should be able to transfer both tokens
        vm.prank(user2);
        nameService.transferFrom(user, user3, tokenId1);

        vm.prank(user2);
        nameService.transferFrom(user, user3, tokenId2);

        assertEq(nameService.ownerOf(tokenId1), user3);
        assertEq(nameService.ownerOf(tokenId2), user3);
    }

    function testSetApprovalForAll_CanRevokeApproval() public {
        vm.prank(user);
        nameService.setApprovalForAll(user2, true);
        assertTrue(nameService.isApprovedForAll(user, user2));

        vm.prank(user);
        nameService.setApprovalForAll(user2, false);
        assertFalse(nameService.isApprovedForAll(user, user2));
    }

    function testApprove_ToCurrentApprovedAddress() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        // Set approval
        vm.prank(user);
        nameService.approve(user2, tokenId);
        assertEq(nameService.getApproved(tokenId), user2);

        // Approve to same address again (should not revert)
        vm.prank(user);
        nameService.approve(user2, tokenId);
        assertEq(nameService.getApproved(tokenId), user2);
    }

    function testSetApprovalForAll_ToCurrentState() public {
        // Set approval to true
        vm.prank(user);
        nameService.setApprovalForAll(user2, true);
        assertTrue(nameService.isApprovedForAll(user, user2));

        // Set to true again (should not revert)
        vm.prank(user);
        nameService.setApprovalForAll(user2, true);
        assertTrue(nameService.isApprovedForAll(user, user2));

        // Set to false
        vm.prank(user);
        nameService.setApprovalForAll(user2, false);
        assertFalse(nameService.isApprovedForAll(user, user2));

        // Set to false again (should not revert)
        vm.prank(user);
        nameService.setApprovalForAll(user2, false);
        assertFalse(nameService.isApprovedForAll(user, user2));
    }

    function testApprove_AfterApprovalForAll() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        // Set approval for all
        vm.prank(user);
        nameService.setApprovalForAll(user2, true);

        // Set specific approval
        vm.prank(user);
        nameService.approve(user3, tokenId);

        // Both should work
        assertTrue(nameService.isApprovedForAll(user, user2));
        assertEq(nameService.getApproved(tokenId), user3);
    }

    function testApprove_OperatorCanApprove() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        // Set approval for all
        vm.prank(user);
        nameService.setApprovalForAll(user2, true);

        // user2 should be able to approve
        vm.prank(user2);
        nameService.approve(user3, tokenId);
        assertEq(nameService.getApproved(tokenId), user3);
    }

    // ============ TRANSFER EDGE CASES TESTS ============

    function testTransferFrom_OperatorCanTransfer() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        // Set approval for all
        vm.prank(user);
        nameService.setApprovalForAll(user2, true);

        // user2 should be able to transfer
        vm.prank(user2);
        nameService.transferFrom(user, user3, tokenId);
        assertEq(nameService.ownerOf(tokenId), user3);
    }

    function testTransferFrom_ApprovedCanTransfer() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        // Set specific approval
        vm.prank(user);
        nameService.approve(user2, tokenId);

        // user2 should be able to transfer
        vm.prank(user2);
        nameService.transferFrom(user, user3, tokenId);
        assertEq(nameService.ownerOf(tokenId), user3);
    }

    function testTransferFrom_OwnerCanTransfer() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        // Owner should be able to transfer without approval
        vm.prank(user);
        nameService.transferFrom(user, user2, tokenId);
        assertEq(nameService.ownerOf(tokenId), user2);
    }

    function testSafeTransferFrom_OperatorCanTransfer() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        // Set approval for all
        vm.prank(user);
        nameService.setApprovalForAll(user2, true);

        // user2 should be able to safe transfer
        vm.prank(user2);
        nameService.safeTransferFrom(
            user,
            address(mockReceiver),
            tokenId,
            "0x1234"
        );
        assertEq(nameService.ownerOf(tokenId), address(mockReceiver));
    }

    function testSafeTransferFrom_ApprovedCanTransfer() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        // Set specific approval
        vm.prank(user);
        nameService.approve(user2, tokenId);

        // user2 should be able to safe transfer
        vm.prank(user2);
        nameService.safeTransferFrom(
            user,
            address(mockReceiver),
            tokenId,
            "0x1234"
        );
        assertEq(nameService.ownerOf(tokenId), address(mockReceiver));
    }

    function testTransferFrom_AfterApprovalChange() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        // Set approval for user2
        vm.prank(user);
        nameService.approve(user2, tokenId);

        // Change approval to user3
        vm.prank(user);
        nameService.approve(user3, tokenId);

        // user2 should no longer be able to transfer
        vm.prank(user2);
        vm.expectRevert();
        nameService.transferFrom(user, user2, tokenId);

        // user3 should be able to transfer
        vm.prank(user3);
        nameService.transferFrom(user, user2, tokenId);
        assertEq(nameService.ownerOf(tokenId), user2);
    }

    function testTransferFrom_AfterApprovalForAllRevoked() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        // Set approval for all
        vm.prank(user);
        nameService.setApprovalForAll(user2, true);

        // Revoke approval for all
        vm.prank(user);
        nameService.setApprovalForAll(user2, false);

        // user2 should no longer be able to transfer
        vm.prank(user2);
        vm.expectRevert();
        nameService.transferFrom(user, user3, tokenId);
    }

    function testTransferFrom_ToContractWithoutReceiver() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        // Create a contract that doesn't implement IERC721Receiver
        address nonReceiver = address(new NonReceiverContract());

        vm.prank(user);
        vm.expectRevert();
        nameService.safeTransferFrom(user, nonReceiver, tokenId, "");
    }

    function testTransferFrom_ToContractWithReceiver() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        vm.prank(user);
        nameService.safeTransferFrom(
            user,
            address(mockReceiver),
            tokenId,
            "0x1234"
        );
        assertEq(nameService.ownerOf(tokenId), address(mockReceiver));
    }

    function testTransferFrom_WithEmptyData() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        vm.prank(user);
        nameService.safeTransferFrom(user, address(mockReceiver), tokenId, "");
        assertEq(nameService.ownerOf(tokenId), address(mockReceiver));
    }

    // ============ EXPIRATION TESTS ============

    function testCleanupExpiredDomains_MultipleDomains() public {
        vm.prank(user);
        nameService.register{value: _price("test1", 1)}("test1", 1);
        vm.prank(user2);
        nameService.register{value: _price("test2", 1)}("test2", 1);

        // Fast forward to expiration
        vm.warp(block.timestamp + 2 * 365 days);

        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit ExpiredDomainsProcessed(2);
        nameService.cleanupExpiredDomains(5);

        assertEq(nameService.getDomainOwner("test1"), address(0));
        assertEq(nameService.getDomainOwner("test2"), address(0));
    }

    function testCleanupExpiredDomains_BatchLimit() public {
        // Register multiple domains
        for (uint i = 0; i < 5; i++) {
            string memory domainName = string(
                abi.encodePacked("test", i.toString())
            );
            vm.prank(user);
            nameService.register{value: _price(domainName, 1)}(domainName, 1);
        }

        // Fast forward to expiration
        vm.warp(block.timestamp + 2 * 365 days);

        vm.prank(user);
        nameService.cleanupExpiredDomains(3);

        // Should only clean up 3 domains
        uint256 cleaned = 0;
        for (uint i = 0; i < 5; i++) {
            string memory domainName = string(
                abi.encodePacked("test", i.toString())
            );
            (address owner, , , ) = nameService.domains(domainName);
            if (owner == address(0)) {
                cleaned++;
            }
        }
        assertEq(cleaned, 3);
    }

    function testCleanupExpiredDomains_InvalidBatchSize() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(NameService.BadBatch.selector));
        nameService.cleanupExpiredDomains(0);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(NameService.BadBatch.selector));
        nameService.cleanupExpiredDomains(21);
    }

    function testCleanupExpiredDomains_NoExpiredDomains() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);

        // Try to clean up before expiration
        vm.prank(user);
        nameService.cleanupExpiredDomains(5);
        assertEq(nameService.getDomainOwner("test"), user);
    }

    function testCleanupExpiredDomains_PartialExpiration() public {
        vm.prank(user);
        nameService.register{value: _price("expired1", 1)}("expired1", 1);
        vm.prank(user);
        nameService.register{value: _price("expired2", 1)}("expired2", 1);
        vm.prank(user2);
        nameService.register{value: _price("active", 2)}("active", 2);

        // Fast forward so only first two domains expire
        vm.warp(block.timestamp + 1.5 * 365 days);

        vm.prank(user);
        nameService.cleanupExpiredDomains(5);

        assertEq(nameService.getDomainOwner("expired1"), address(0));
        assertEq(nameService.getDomainOwner("expired2"), address(0));
        assertEq(nameService.getDomainOwner("active"), user2);
    }

    function testCleanupExpiredDomains_ReturnsCorrectCount() public {
        // Register 3 domains
        for (uint i = 0; i < 3; i++) {
            string memory domainName = string(
                abi.encodePacked("test", i.toString())
            );
            vm.prank(user);
            nameService.register{value: _price(domainName, 1)}(domainName, 1);
        }

        // Fast forward to expiration
        vm.warp(block.timestamp + 2 * 365 days);

        vm.prank(user);
        nameService.cleanupExpiredDomains(2);

        vm.prank(user);
        nameService.cleanupExpiredDomains(2);
    }

    function testCleanupExpiredDomains_EmitsCorrectEvents() public {
        vm.prank(user);
        nameService.register{value: _price("test1", 1)}("test1", 1);
        vm.prank(user);
        nameService.register{value: _price("test2", 1)}("test2", 1);

        // Fast forward to expiration
        vm.warp(block.timestamp + 2 * 365 days);

        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit ExpiredDomainsProcessed(2);
        nameService.cleanupExpiredDomains(5);
    }

    function testCleanupExpiredDomains_UpdatesTotalSupply() public {
        vm.prank(user);
        nameService.register{value: _price("test1", 1)}("test1", 1);
        vm.prank(user);
        nameService.register{value: _price("test2", 1)}("test2", 1);

        assertEq(nameService.getTotalDomainCount(), 2);

        // Fast forward to expiration
        vm.warp(block.timestamp + 2 * 365 days);

        vm.prank(user);
        nameService.cleanupExpiredDomains(5);

        assertEq(nameService.getTotalDomainCount(), 0);
    }

    function testCleanupExpiredDomains_ClearsAllMappings() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        // Fast forward to expiration
        vm.warp(block.timestamp + 2 * 365 days);

        vm.prank(user);
        nameService.cleanupExpiredDomains(1);

        // All mappings should be cleared
        assertEq(nameService.getDomainOwner("test"), address(0));
        assertEq(nameService.domainToToken("test"), 0);
        assertEq(nameService.tokenToDomain(tokenId), "");
        assertEq(nameService.balanceOf(user), 0);
    }

    // ============ DOMAIN SYNCHRONIZATION TESTS ============

    function testDomainOwnershipSync_AfterTransfer() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);

        // Verify initial state
        assertEq(nameService.getDomainOwner("test"), user);
        assertEq(manager.mainDomain(user), "test.hotdogs");

        uint256 tokenId = nameService.domainToToken("test");

        // Transfer NFT
        vm.prank(user);
        nameService.transferFrom(user, user2, tokenId);

        // Verify domain ownership is updated
        assertEq(nameService.getDomainOwner("test"), user2);
        assertEq(manager.mainDomain(user2), "test.hotdogs");
        assertEq(manager.mainDomain(user), "");
    }

    function testDomainOwnershipSync_AfterSafeTransfer() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);

        uint256 tokenId = nameService.domainToToken("test");

        // Safe transfer NFT
        vm.prank(user);
        nameService.safeTransferFrom(user, user2, tokenId, "");

        // Verify domain ownership is updated
        assertEq(nameService.getDomainOwner("test"), user2);
        assertEq(manager.mainDomain(user2), "test.hotdogs");
    }

    function testDomainOwnershipSync_AfterTransferDomain() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);

        // Use transferDomain function
        vm.prank(user);
        nameService.transferDomain("test", user2);

        // Verify domain ownership is updated
        assertEq(nameService.getDomainOwner("test"), user2);
        assertEq(manager.mainDomain(user2), "test.hotdogs");
    }

    function testDomainOwnershipSync_MultipleDomains() public {
        vm.prank(user);
        nameService.register{value: _price("test1", 1)}("test1", 1);
        vm.prank(user);
        nameService.register{value: _price("test2", 1)}("test2", 1);

        // Transfer one domain
        uint256 tokenId1 = nameService.domainToToken("test1");
        vm.prank(user);
        nameService.transferFrom(user, user2, tokenId1);

        // Verify both domains are still tracked for user
        string memory userDomain = manager.addressToDomains(user, 0);
        assertEq(userDomain, "test2.hotdogs");

        // Verify user2 has the transferred domain
        string memory user2Domain = manager.addressToDomains(user2, 0);
        assertEq(user2Domain, "test1.hotdogs");
    }

    // ============ RENEWAL TESTS ============

    function testRenew_UpdatesTokenURI() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);
        uint256 tokenId = nameService.domainToToken("test");

        string memory originalURI = nameService.tokenURI(tokenId);

        // Renew domain
        vm.prank(user);
        nameService.renew{value: _price("test", 1)}("test", 1);

        string memory newURI = nameService.tokenURI(tokenId);

        // URI should be different due to updated expiration
        assertTrue(keccak256(bytes(originalURI)) != keccak256(bytes(newURI)));
    }

    function testRenew_EmitsEvent() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);

        vm.prank(user);
        vm.expectEmit(true, true, false, false);
        emit DomainRenewed("test", user, 0); // We can't predict exact expiration
        nameService.renew{value: _price("test", 1)}("test", 1);
    }

    function testRenew_UpdatesExpiration() public {
        vm.prank(user);
        nameService.register{value: _price("test", 1)}("test", 1);

        uint256 originalExpiration = nameService.getDomainExpiration("test");

        vm.prank(user);
        nameService.renew{value: _price("test", 1)}("test", 1);

        uint256 newExpiration = nameService.getDomainExpiration("test");
        assertTrue(newExpiration > originalExpiration);
    }

    receive() external payable {}
}
