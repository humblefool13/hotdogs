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

/**
 * @title MinHeap
 * @notice Min-heap implementation for managing domain expirations efficiently
 * @dev Provides O(log n) insertions/updates and O(1) access to earliest expiration
 */
library MinHeap {
    struct HeapEntry {
        string domain;
        uint256 expiration;
    }

    struct Heap {
        HeapEntry[] entries;
        mapping(string => uint256) domainToIndex; // Tracks domain position in heap (1-based)
    }

    /**
     * @notice Inserts a new domain with expiration into the heap
     * @param heap The heap storage reference
     * @param domain The domain name
     * @param expiration The expiration timestamp
     */
    function insert(
        Heap storage heap,
        string memory domain,
        uint256 expiration
    ) internal {
        heap.entries.push(HeapEntry(domain, expiration));
        uint256 index = heap.entries.length - 1;
        heap.domainToIndex[domain] = index + 1; // 1-based indexing (0 means not in heap)
        _bubbleUp(heap, index);
    }

    /**
     * @notice Removes and returns the domain with earliest expiration
     * @param heap The heap storage reference
     * @return domain The domain name
     * @return expiration The expiration timestamp
     */
    function popMin(
        Heap storage heap
    ) internal returns (string memory domain, uint256 expiration) {
        if (heap.entries.length == 0) revert HeapEmpty();
        HeapEntry memory minEntry = heap.entries[0];
        domain = minEntry.domain;
        expiration = minEntry.expiration;

        // Move last to root and bubble down
        heap.entries[0] = heap.entries[heap.entries.length - 1];
        heap.domainToIndex[heap.entries[0].domain] = 1;
        heap.entries.pop();
        delete heap.domainToIndex[domain];

        if (heap.entries.length > 0) {
            _bubbleDown(heap, 0);
        }
        return (domain, expiration);
    }

    /**
     * @notice Updates the expiration time of an existing domain
     * @param heap The heap storage reference
     * @param domain The domain name
     * @param newExpiration The new expiration timestamp
     */
    function updateExpiration(
        Heap storage heap,
        string memory domain,
        uint256 newExpiration
    ) internal {
        uint256 index = heap.domainToIndex[domain];
        if (index == 0) revert NotInHeap();
        index -= 1; // Convert to 0-based

        uint256 oldExpiration = heap.entries[index].expiration;
        heap.entries[index].expiration = newExpiration;

        // Bubble up or down as needed based on whether expiration increased or decreased
        if (newExpiration < oldExpiration) {
            _bubbleUp(heap, index);
        } else if (newExpiration > oldExpiration) {
            _bubbleDown(heap, index);
        }
    }

    /**
     * @notice Gets the domain with earliest expiration without removing it
     * @param heap The heap storage reference
     * @return domain The domain name
     * @return expiration The expiration timestamp
     */
    function getMin(
        Heap storage heap
    ) internal view returns (string memory domain, uint256 expiration) {
        if (heap.entries.length == 0) revert HeapEmpty();
        return (heap.entries[0].domain, heap.entries[0].expiration);
    }

    /**
     * @notice Removes a specific domain from the heap
     * @param heap The heap storage reference
     * @param domain The domain name to remove
     */
    function remove(Heap storage heap, string memory domain) internal {
        uint256 index = heap.domainToIndex[domain];
        if (index == 0) revert NotInHeap();
        index -= 1; // Convert to 0-based

        // If it's the last element, just pop
        if (index == heap.entries.length - 1) {
            heap.entries.pop();
            delete heap.domainToIndex[domain];
            return;
        }

        // Move last element to this position
        heap.entries[index] = heap.entries[heap.entries.length - 1];
        heap.domainToIndex[heap.entries[index].domain] = index + 1;
        heap.entries.pop();
        delete heap.domainToIndex[domain];

        // Rebalance the heap
        if (index < heap.entries.length) {
            _bubbleDown(heap, index);
        }
    }

    /**
     * @notice Checks if a domain exists in the heap
     * @param heap The heap storage reference
     * @param domain The domain name to check
     * @return True if domain exists in heap
     */
    function contains(
        Heap storage heap,
        string memory domain
    ) internal view returns (bool) {
        return heap.domainToIndex[domain] > 0;
    }

    /**
     * @notice Gets the current size of the heap
     * @param heap The heap storage reference
     * @return The number of entries in the heap
     */
    function size(Heap storage heap) internal view returns (uint256) {
        return heap.entries.length;
    }

    /**
     * @notice Bubbles up an element to maintain heap property
     * @param heap The heap storage reference
     * @param index The index to bubble up from
     */
    function _bubbleUp(Heap storage heap, uint256 index) private {
        while (index > 0) {
            uint256 parent = (index - 1) / 2;
            if (
                heap.entries[index].expiration >=
                heap.entries[parent].expiration
            ) break;
            _swap(heap, index, parent);
            index = parent;
        }
    }

    /**
     * @notice Bubbles down an element to maintain heap property
     * @param heap The heap storage reference
     * @param index The index to bubble down from
     */
    function _bubbleDown(Heap storage heap, uint256 index) private {
        uint256 minIndex = index;
        uint256 length = heap.entries.length;

        while (true) {
            uint256 left = 2 * index + 1;
            uint256 right = 2 * index + 2;

            if (
                left < length &&
                heap.entries[left].expiration <
                heap.entries[minIndex].expiration
            ) {
                minIndex = left;
            }
            if (
                right < length &&
                heap.entries[right].expiration <
                heap.entries[minIndex].expiration
            ) {
                minIndex = right;
            }

            if (minIndex == index) break;

            _swap(heap, index, minIndex);
            index = minIndex;
        }
    }

    /**
     * @notice Swaps two elements in the heap and updates their indices
     * @param heap The heap storage reference
     * @param i First index
     * @param j Second index
     */
    function _swap(Heap storage heap, uint256 i, uint256 j) private {
        HeapEntry memory temp = heap.entries[i];
        heap.entries[i] = heap.entries[j];
        heap.entries[j] = temp;

        // Update the domain-to-index mappings
        heap.domainToIndex[heap.entries[i].domain] = i + 1;
        heap.domainToIndex[heap.entries[j].domain] = j + 1;
    }

    error HeapEmpty();
    error NotInHeap();
}
