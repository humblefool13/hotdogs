// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/MinHeap.sol";

contract MinHeapTest is Test {
    using MinHeap for MinHeap.Heap;

    MinHeap.Heap private heap;

    function setUp() public {
        // Reset heap for each test
        delete heap;
    }

    // ============ INSERT TESTS ============

    function testInsert_SingleElement() public {
        heap.insert("domain1", 1000);

        assertEq(heap.size(), 1);
        assertTrue(heap.contains("domain1"));

        (string memory domain, uint256 expiration) = heap.getMin();
        assertEq(domain, "domain1");
        assertEq(expiration, 1000);
    }

    function testInsert_MultipleElements() public {
        heap.insert("domain1", 1000);
        heap.insert("domain2", 500);
        heap.insert("domain3", 1500);

        assertEq(heap.size(), 3);
        assertTrue(heap.contains("domain1"));
        assertTrue(heap.contains("domain2"));
        assertTrue(heap.contains("domain3"));

        // Should return minimum (domain2 with 500)
        (string memory domain, uint256 expiration) = heap.getMin();
        assertEq(domain, "domain2");
        assertEq(expiration, 500);
    }

    function testInsert_HeapProperty() public {
        // Insert in reverse order to test heap property maintenance
        heap.insert("domain1", 1000);
        heap.insert("domain2", 500);
        heap.insert("domain3", 200);
        heap.insert("domain4", 800);
        heap.insert("domain5", 100);

        assertEq(heap.size(), 5);

        // Should always return minimum
        (string memory domain, uint256 expiration) = heap.getMin();
        assertEq(domain, "domain5");
        assertEq(expiration, 100);
    }

    // ============ POP MIN TESTS ============

    function testPopMin_SingleElement() public {
        heap.insert("domain1", 1000);

        (string memory domain, uint256 expiration) = heap.popMin();
        assertEq(domain, "domain1");
        assertEq(expiration, 1000);
        assertEq(heap.size(), 0);
        assertFalse(heap.contains("domain1"));
    }

    function testPopMin_MultipleElements() public {
        heap.insert("domain1", 1000);
        heap.insert("domain2", 500);
        heap.insert("domain3", 200);
        heap.insert("domain4", 800);

        // Pop minimums in order
        (string memory domain, uint256 expiration) = heap.popMin();
        assertEq(domain, "domain3");
        assertEq(expiration, 200);
        assertEq(heap.size(), 3);

        (domain, expiration) = heap.popMin();
        assertEq(domain, "domain2");
        assertEq(expiration, 500);
        assertEq(heap.size(), 2);

        (domain, expiration) = heap.popMin();
        assertEq(domain, "domain4");
        assertEq(expiration, 800);
        assertEq(heap.size(), 1);

        (domain, expiration) = heap.popMin();
        assertEq(domain, "domain1");
        assertEq(expiration, 1000);
        assertEq(heap.size(), 0);
    }

    function testPopMin_EmptyHeap() public {
        vm.expectRevert(MinHeap.HeapEmpty.selector);
        heap.popMin();
    }

    function testPopMin_HeapPropertyAfterPop() public {
        heap.insert("domain1", 1000);
        heap.insert("domain2", 500);
        heap.insert("domain3", 200);
        heap.insert("domain4", 800);
        heap.insert("domain5", 100);

        // Pop minimum
        heap.popMin();

        // Next minimum should be correct
        (string memory domain, uint256 expiration) = heap.getMin();
        assertEq(domain, "domain3");
        assertEq(expiration, 200);
    }

    // ============ UPDATE EXPIRATION TESTS ============

    function testUpdateExpiration_DecreaseExpiration() public {
        heap.insert("domain1", 1000);
        heap.insert("domain2", 500);
        heap.insert("domain3", 200);

        // Update domain1 to have lower expiration
        heap.updateExpiration("domain1", 100);

        // domain1 should now be minimum
        (string memory domain, uint256 expiration) = heap.getMin();
        assertEq(domain, "domain1");
        assertEq(expiration, 100);
    }

    function testUpdateExpiration_IncreaseExpiration() public {
        heap.insert("domain1", 100);
        heap.insert("domain2", 500);
        heap.insert("domain3", 200);

        // Update domain1 to have higher expiration
        heap.updateExpiration("domain1", 1000);

        // domain3 should now be minimum
        (string memory domain, uint256 expiration) = heap.getMin();
        assertEq(domain, "domain3");
        assertEq(expiration, 200);
    }

    function testUpdateExpiration_SameExpiration() public {
        heap.insert("domain1", 1000);
        heap.insert("domain2", 500);

        // Update domain1 to same expiration
        heap.updateExpiration("domain1", 1000);

        // Should still work correctly
        (string memory domain, uint256 expiration) = heap.getMin();
        assertEq(domain, "domain2");
        assertEq(expiration, 500);
    }

    function testUpdateExpiration_NotInHeap() public {
        heap.insert("domain1", 1000);

        vm.expectRevert(MinHeap.NotInHeap.selector);
        heap.updateExpiration("domain2", 500);
    }

    function testUpdateExpiration_ComplexScenario() public {
        heap.insert("domain1", 1000);
        heap.insert("domain2", 500);
        heap.insert("domain3", 200);
        heap.insert("domain4", 800);
        heap.insert("domain5", 100);

        // Update multiple domains
        heap.updateExpiration("domain1", 50); // Now minimum
        heap.updateExpiration("domain4", 1500); // Now maximum

        // Check order
        (string memory domain, uint256 expiration) = heap.getMin();
        assertEq(domain, "domain1");
        assertEq(expiration, 50);

        heap.popMin();
        (domain, expiration) = heap.getMin();
        assertEq(domain, "domain5");
        assertEq(expiration, 100);

        heap.popMin();
        (domain, expiration) = heap.getMin();
        assertEq(domain, "domain3");
        assertEq(expiration, 200);
    }

    // ============ GET MIN TESTS ============

    function testGetMin_SingleElement() public {
        heap.insert("domain1", 1000);

        (string memory domain, uint256 expiration) = heap.getMin();
        assertEq(domain, "domain1");
        assertEq(expiration, 1000);
        assertEq(heap.size(), 1); // Size unchanged
    }

    function testGetMin_MultipleElements() public {
        heap.insert("domain1", 1000);
        heap.insert("domain2", 500);
        heap.insert("domain3", 200);

        (string memory domain, uint256 expiration) = heap.getMin();
        assertEq(domain, "domain3");
        assertEq(expiration, 200);
    }

    function testGetMin_EmptyHeap() public {
        vm.expectRevert(MinHeap.HeapEmpty.selector);
        heap.getMin();
    }

    function testGetMin_AfterOperations() public {
        heap.insert("domain1", 1000);
        heap.insert("domain2", 500);
        heap.insert("domain3", 200);

        // Get min without removing
        (string memory domain, uint256 expiration) = heap.getMin();
        assertEq(domain, "domain3");
        assertEq(expiration, 200);

        // Update and get min again
        heap.updateExpiration("domain1", 100);
        (domain, expiration) = heap.getMin();
        assertEq(domain, "domain1");
        assertEq(expiration, 100);
    }

    // ============ REMOVE TESTS ============

    function testRemove_SingleElement() public {
        heap.insert("domain1", 1000);

        heap.remove("domain1");
        assertEq(heap.size(), 0);
        assertFalse(heap.contains("domain1"));
    }

    function testRemove_MiddleElement() public {
        heap.insert("domain1", 1000);
        heap.insert("domain2", 500);
        heap.insert("domain3", 200);
        heap.insert("domain4", 800);

        heap.remove("domain2");
        assertEq(heap.size(), 3);
        assertFalse(heap.contains("domain2"));

        // domain3 should still be minimum
        (string memory domain, uint256 expiration) = heap.getMin();
        assertEq(domain, "domain3");
        assertEq(expiration, 200);
    }

    function testRemove_LastElement() public {
        heap.insert("domain1", 1000);
        heap.insert("domain2", 500);

        heap.remove("domain2");
        assertEq(heap.size(), 1);
        assertFalse(heap.contains("domain2"));

        (string memory domain, uint256 expiration) = heap.getMin();
        assertEq(domain, "domain1");
        assertEq(expiration, 1000);
    }

    function testRemove_FirstElement() public {
        heap.insert("domain1", 100);
        heap.insert("domain2", 500);
        heap.insert("domain3", 200);

        heap.remove("domain1");
        assertEq(heap.size(), 2);
        assertFalse(heap.contains("domain1"));

        // domain3 should now be minimum
        (string memory domain, uint256 expiration) = heap.getMin();
        assertEq(domain, "domain3");
        assertEq(expiration, 200);
    }

    function testRemove_NotInHeap() public {
        heap.insert("domain1", 1000);

        vm.expectRevert(MinHeap.NotInHeap.selector);
        heap.remove("domain2");
    }

    function testRemove_ComplexScenario() public {
        heap.insert("domain1", 1000);
        heap.insert("domain2", 500);
        heap.insert("domain3", 200);
        heap.insert("domain4", 800);
        heap.insert("domain5", 100);

        // Remove middle elements
        heap.remove("domain2");
        heap.remove("domain4");

        assertEq(heap.size(), 3);
        assertFalse(heap.contains("domain2"));
        assertFalse(heap.contains("domain4"));

        // Check remaining order
        (string memory domain, uint256 expiration) = heap.getMin();
        assertEq(domain, "domain5");
        assertEq(expiration, 100);

        heap.popMin();
        (domain, expiration) = heap.getMin();
        assertEq(domain, "domain3");
        assertEq(expiration, 200);
    }

    // ============ CONTAINS TESTS ============

    function testContains_ExistingDomain() public {
        heap.insert("domain1", 1000);
        heap.insert("domain2", 500);

        assertTrue(heap.contains("domain1"));
        assertTrue(heap.contains("domain2"));
    }

    function testContains_NonExistingDomain() public {
        heap.insert("domain1", 1000);

        assertFalse(heap.contains("domain2"));
        assertFalse(heap.contains(""));
    }

    function testContains_AfterRemoval() public {
        heap.insert("domain1", 1000);
        heap.insert("domain2", 500);

        heap.remove("domain1");
        assertFalse(heap.contains("domain1"));
        assertTrue(heap.contains("domain2"));
    }

    function testContains_AfterPop() public {
        heap.insert("domain1", 1000);
        heap.insert("domain2", 500);

        heap.popMin();
        assertTrue(heap.contains("domain1"));
        assertFalse(heap.contains("domain2"));
    }

    // ============ SIZE TESTS ============

    function testSize_EmptyHeap() public view {
        assertEq(heap.size(), 0);
    }

    function testSize_AfterInsert() public {
        heap.insert("domain1", 1000);
        assertEq(heap.size(), 1);

        heap.insert("domain2", 500);
        assertEq(heap.size(), 2);
    }

    function testSize_AfterRemove() public {
        heap.insert("domain1", 1000);
        heap.insert("domain2", 500);

        heap.remove("domain1");
        assertEq(heap.size(), 1);
    }

    function testSize_AfterPop() public {
        heap.insert("domain1", 1000);
        heap.insert("domain2", 500);

        heap.popMin();
        assertEq(heap.size(), 1);
    }

    // ============ EDGE CASES AND STRESS TESTS ============

    function testLargeHeap() public {
        // Insert many elements
        for (uint i = 0; i < 100; i++) {
            string memory domainName = string(
                abi.encodePacked("domain", vm.toString(i))
            );
            heap.insert(domainName, 1000 - i);
        }

        assertEq(heap.size(), 100);

        // Check minimum
        (string memory domain, uint256 expiration) = heap.getMin();
        assertEq(domain, "domain99");
        assertEq(expiration, 901);
    }

    function testSameExpirationTimes() public {
        heap.insert("domain1", 1000);
        heap.insert("domain2", 1000);
        heap.insert("domain3", 1000);

        assertEq(heap.size(), 3);

        // All have same expiration, should return one of them
        (string memory domain, uint256 expiration) = heap.getMin();
        assertEq(expiration, 1000);
        assertTrue(
            keccak256(bytes(domain)) == keccak256(bytes("domain1")) ||
                keccak256(bytes(domain)) == keccak256(bytes("domain2")) ||
                keccak256(bytes(domain)) == keccak256(bytes("domain3"))
        );
    }

    function testZeroExpiration() public {
        heap.insert("domain1", 0);
        heap.insert("domain2", 1000);

        (string memory domain, uint256 expiration) = heap.getMin();
        assertEq(domain, "domain1");
        assertEq(expiration, 0);
    }

    function testMaxUint256Expiration() public {
        heap.insert("domain1", type(uint256).max);
        heap.insert("domain2", 1000);

        (string memory domain, uint256 expiration) = heap.getMin();
        assertEq(domain, "domain2");
        assertEq(expiration, 1000);
    }

    function testEmptyStringDomain() public {
        heap.insert("", 1000);
        heap.insert("domain1", 500);

        (string memory domain, uint256 expiration) = heap.getMin();
        assertEq(domain, "domain1");
        assertEq(expiration, 500);
    }

    function testLongDomainName() public {
        string
            memory longDomain = "thisisareallylongdomainnamethatexceedstypicallimits";
        heap.insert(longDomain, 1000);
        heap.insert("short", 500);

        (string memory domain, uint256 expiration) = heap.getMin();
        assertEq(domain, "short");
        assertEq(expiration, 500);
    }

    // ============ HEAP PROPERTY VERIFICATION ============

    function testHeapProperty_MaintainedAfterInsert() public {
        // Insert elements in random order
        heap.insert("domain1", 1000);
        heap.insert("domain2", 200);
        heap.insert("domain3", 800);
        heap.insert("domain4", 100);
        heap.insert("domain5", 500);

        // Verify heap property by popping all elements
        uint256 lastExpiration = 0;
        while (heap.size() > 0) {
            (, uint256 expiration) = heap.popMin();
            assertTrue(expiration >= lastExpiration, "Heap property violated");
            lastExpiration = expiration;
        }
    }

    function testHeapProperty_MaintainedAfterUpdate() public {
        heap.insert("domain1", 1000);
        heap.insert("domain2", 500);
        heap.insert("domain3", 200);

        // Update to maintain heap property
        heap.updateExpiration("domain1", 100);

        // Verify heap property
        uint256 lastExpiration = 0;
        while (heap.size() > 0) {
            (, uint256 expiration) = heap.popMin();
            assertTrue(
                expiration >= lastExpiration,
                "Heap property violated after update"
            );
            lastExpiration = expiration;
        }
    }

    function testHeapProperty_MaintainedAfterRemove() public {
        heap.insert("domain1", 1000);
        heap.insert("domain2", 500);
        heap.insert("domain3", 200);
        heap.insert("domain4", 800);

        // Remove middle element
        heap.remove("domain2");

        // Verify heap property
        uint256 lastExpiration = 0;
        while (heap.size() > 0) {
            (, uint256 expiration) = heap.popMin();
            assertTrue(
                expiration >= lastExpiration,
                "Heap property violated after remove"
            );
            lastExpiration = expiration;
        }
    }
}
