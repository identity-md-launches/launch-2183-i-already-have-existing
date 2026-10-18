// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @dev One-based, dynamically growing Fenwick tree. All functions are inlined.
library WeightedTree {
    error WeightedTreeIndexOutOfRange();
    error WeightedTreeInsufficientWeight();
    error WeightedTreePositionOutOfRange();

    struct Tree {
        mapping(uint256 => uint256) nodes;
        uint256 size;
        uint256 total;
    }

    function append(Tree storage self, uint256 weight) internal {
        uint256 index = ++self.size;
        uint256 start = index - (index & (~index + 1));
        self.nodes[index] = prefix(self, index - 1) - prefix(self, start) + weight;
        self.total += weight;
    }

    function add(Tree storage self, uint256 index, uint256 weight) internal {
        if (index == 0 || index > self.size) revert WeightedTreeIndexOutOfRange();
        self.total += weight;
        while (index <= self.size) {
            self.nodes[index] += weight;
            index += index & (~index + 1);
        }
    }

    function remove(Tree storage self, uint256 index, uint256 weight) internal {
        if (index == 0 || index > self.size) revert WeightedTreeIndexOutOfRange();
        if (prefix(self, index) - prefix(self, index - 1) < weight) revert WeightedTreeInsufficientWeight();
        self.total -= weight;
        while (index <= self.size) {
            self.nodes[index] -= weight;
            index += index & (~index + 1);
        }
    }

    function prefix(Tree storage self, uint256 index) internal view returns (uint256 sum) {
        while (index != 0) {
            sum += self.nodes[index];
            index -= index & (~index + 1);
        }
    }

    /// @dev Finds the ticket interval containing a zero-based weighted position.
    function find(Tree storage self, uint256 position) internal view returns (uint256 index) {
        if (position >= self.total) revert WeightedTreePositionOutOfRange();
        uint256 bit = 1;
        while (bit <= self.size / 2) bit <<= 1;
        for (; bit != 0; bit >>= 1) {
            uint256 next = index + bit;
            if (next <= self.size && self.nodes[next] <= position) {
                position -= self.nodes[next];
                index = next;
            }
        }
        return index + 1;
    }
}
