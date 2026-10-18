// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {WeightedTree} from "../src/libraries/WeightedTree.sol";

contract TreeHarness {
    using WeightedTree for WeightedTree.Tree;
    WeightedTree.Tree private tree;

    function append(uint256 value) external {
        tree.append(value);
    }

    function add(uint256 index, uint256 value) external {
        tree.add(index, value);
    }

    function remove(uint256 index, uint256 value) external {
        tree.remove(index, value);
    }

    function find(uint256 position) external view returns (uint256) {
        return tree.find(position);
    }

    function total() external view returns (uint256) {
        return tree.total;
    }
}

contract WeightedTreeTest is Test {
    TreeHarness private tree;

    function setUp() public {
        tree = new TreeHarness();
    }

    function test_zeroWeightNodesAndInvalidActions() public {
        tree.append(0);
        tree.append(20);
        tree.append(0);
        tree.append(10);
        assertEq(tree.find(0), 2);
        assertEq(tree.find(19), 2);
        assertEq(tree.find(20), 4);
        tree.remove(2, 20);
        assertEq(tree.find(0), 4);
        vm.expectRevert(WeightedTree.WeightedTreePositionOutOfRange.selector);
        tree.find(10);
        vm.expectRevert(WeightedTree.WeightedTreeIndexOutOfRange.selector);
        tree.add(0, 1);
        vm.expectRevert(WeightedTree.WeightedTreeIndexOutOfRange.selector);
        tree.remove(5, 1);
        vm.expectRevert(WeightedTree.WeightedTreeInsufficientWeight.selector);
        tree.remove(2, 1);
    }

    /// @dev Compare all interval boundaries against a linear oracle, including dynamic growth after updates.
    function testFuzz_dynamicGrowthAndUpdatesMatchLinearOracle(uint256 seed, uint8 length) public {
        uint256 count = bound(length, 1, 64);
        uint256[] memory weights = new uint256[](count);
        for (uint256 i; i < count; ++i) {
            seed = uint256(keccak256(abi.encode(seed, i)));
            weights[i] = seed % 1000 + 1;
            tree.append(weights[i]);
            if (i > 0) {
                uint256 index = seed % i;
                tree.add(index + 1, 7);
                weights[index] += 7;
            }
        }
        uint256 total;
        for (uint256 i; i < count; ++i) {
            assertEq(tree.find(total), i + 1);
            assertEq(tree.find(total + weights[i] - 1), i + 1);
            total += weights[i];
        }
        assertEq(tree.total(), total);
        uint256 removeIndex = seed % count;
        tree.remove(removeIndex + 1, weights[removeIndex]);
        weights[removeIndex] = 0;
        total = 0;
        for (uint256 i; i < count; ++i) {
            if (weights[i] == 0) continue;
            assertEq(tree.find(total), i + 1);
            assertEq(tree.find(total + weights[i] - 1), i + 1);
            total += weights[i];
        }
        assertEq(tree.total(), total);
    }
}
