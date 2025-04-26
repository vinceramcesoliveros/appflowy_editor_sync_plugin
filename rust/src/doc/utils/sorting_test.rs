fn main() {
    println!("This is a test binary. Run with `cargo test` to execute tests.");
}

#[cfg(test)]
mod tests {
    use std::collections::HashMap;

    use crate::doc::{ document_types::BlockDoc, utils::{ sorting::ChainSorting } };

    // Helper to create a test block
    fn create_test_block(
        id: &str,
        ty: &str,
        device: &str,
        timestamp: &str,
        prev_id: Option<&str>,
        parent_id: Option<&str>
    ) -> BlockDoc {
        let mut attributes = HashMap::new();
        attributes.insert("device".to_string(), device.to_string());
        attributes.insert("timestamp".to_string(), timestamp.to_string());

        BlockDoc {
            id: id.to_string(),
            ty: ty.to_string(),
            attributes,
            delta: None,
            parent_id: parent_id.map(|s| s.to_string()),
            prev_id: prev_id.map(|s| s.to_string()),
            old_parent_id: None,
            next_id: None,
        }
    }

    #[test]
    fn test_basic_device_grouping() {
        // Create blocks from two different devices
        let mut blocks = HashMap::new();
        blocks.insert(
            "a1".to_string(),
            create_test_block("a1", "paragraph", "device_a", "1", None, Some("root"))
        );
        blocks.insert(
            "b1".to_string(),
            create_test_block("b1", "paragraph", "device_b", "2", None, Some("root"))
        );
        blocks.insert(
            "a2".to_string(),
            create_test_block("a2", "paragraph", "device_a", "3", None, Some("root"))
        );
        blocks.insert(
            "b2".to_string(),
            create_test_block("b2", "paragraph", "device_b", "4", None, Some("root"))
        );

        // // Create children map
        // let mut children_map = HashMap::new();
        // children_map.insert(
        //     "root".to_string(),
        //     vec!["a1".to_string(), "b1".to_string(), "a2".to_string(), "b2".to_string()]
        // );

        // Sort blocks
        let sorted = ChainSorting::sort_blocks_by_chain( &blocks);

        // Verify: blocks should be grouped by device
        // Either [a1, a2, b1, b2] or [b1, b2, a1, a2] depending on which device sorts first
        let sorted_root = &sorted["root"];

        // Check that device blocks are together
        let a1_pos = sorted_root
            .iter()
            .position(|id| id == "a1")
            .unwrap();
        let a2_pos = sorted_root
            .iter()
            .position(|id| id == "a2")
            .unwrap();
        let b1_pos = sorted_root
            .iter()
            .position(|id| id == "b1")
            .unwrap();
        let b2_pos = sorted_root
            .iter()
            .position(|id| id == "b2")
            .unwrap();

        // Verify device A blocks are grouped together and device B blocks are grouped together
        assert!(
            (a1_pos < a2_pos && b1_pos < b2_pos) || (a2_pos < a1_pos && b2_pos < b1_pos),
            "Blocks from same device should be grouped together"
        );

        // Verify devices are separated (either all A then all B, or all B then all A)
        assert!(
            (a1_pos < b1_pos && a2_pos < b1_pos) || (b1_pos < a1_pos && b2_pos < a1_pos),
            "Blocks should be grouped by device"
        );
    }

    #[test]
    fn test_prev_id_chain() {
        // Create a chain of blocks: a1 -> a2 -> a3
        let mut blocks = HashMap::new();
        blocks.insert(
            "a1".to_string(),
            create_test_block("a1", "paragraph", "device_a", "1", None, Some("root"))
        );
        blocks.insert(
            "a2".to_string(),
            create_test_block("a2", "paragraph", "device_a", "2", Some("a1"), Some("root"))
        );
        blocks.insert(
            "a3".to_string(),
            create_test_block("a3", "paragraph", "device_a", "3", Some("a2"), Some("root"))
        );

  

        // Sort blocks
        let sorted = ChainSorting::sort_blocks_by_chain( &blocks);

        // Verify: blocks should follow prev_id chain (a1, a2, a3)
        let sorted_root = &sorted["root"];
        assert_eq!(sorted_root, &["a1", "a2", "a3"]);
    }

    #[test]
    fn test_multiple_devices_with_chains() {
        // Create two chains:
        // Device A: a1 -> a2 -> a3
        // Device B: b1 -> b2
        let mut blocks = HashMap::new();
        blocks.insert(
            "a1".to_string(),
            create_test_block("a1", "paragraph", "device_a", "1", None, Some("root"))
        );
        blocks.insert(
            "a2".to_string(),
            create_test_block("a2", "paragraph", "device_a", "2", Some("a1"), Some("root"))
        );
        blocks.insert(
            "a3".to_string(),
            create_test_block("a3", "paragraph", "device_a", "3", Some("a2"), Some("root"))
        );
        blocks.insert(
            "b1".to_string(),
            create_test_block("b1", "paragraph", "device_b", "1", None, Some("root"))
        );
        blocks.insert(
            "b2".to_string(),
            create_test_block("b2", "paragraph", "device_b", "2", Some("b1"), Some("root"))
        );

        // Create children map with blocks in random order
        let mut children_map = HashMap::new();
        children_map.insert(
            "root".to_string(),
            vec![
                "b2".to_string(),
                "a3".to_string(),
                "a1".to_string(),
                "b1".to_string(),
                "a2".to_string()
            ]
        );

        // Sort blocks
        let sorted = ChainSorting::sort_blocks_by_chain( &blocks);
        let sorted_root = &sorted["root"];

        // Verify:
        // 1. All device_a blocks are together in order: a1, a2, a3
        // 2. All device_b blocks are together in order: b1, b2

        let a1_pos = sorted_root
            .iter()
            .position(|id| id == "a1")
            .unwrap();
        let a2_pos = sorted_root
            .iter()
            .position(|id| id == "a2")
            .unwrap();
        let a3_pos = sorted_root
            .iter()
            .position(|id| id == "a3")
            .unwrap();
        let b1_pos = sorted_root
            .iter()
            .position(|id| id == "b1")
            .unwrap();
        let b2_pos = sorted_root
            .iter()
            .position(|id| id == "b2")
            .unwrap();

        // Check a1 -> a2 -> a3 sequence
        assert!(a1_pos < a2_pos && a2_pos < a3_pos, "Device A blocks should follow chain order");

        // Check b1 -> b2 sequence
        assert!(b1_pos < b2_pos, "Device B blocks should follow chain order");

        // Check that devices are grouped
        assert!(
            (a1_pos < b1_pos && a3_pos < b1_pos) || (b1_pos < a1_pos && b2_pos < a1_pos),
            "Blocks should be grouped by device"
        );
    }

    #[test]
    fn test_no_lost_blocks() {
        // Create blocks including one with missing metadata
        let mut blocks = HashMap::new();
        blocks.insert(
            "a1".to_string(),
            create_test_block("a1", "paragraph", "device_a", "1", None, Some("root"))
        );
        blocks.insert(
            "a2".to_string(),
            create_test_block("a2", "paragraph", "device_a", "2", Some("a1"), Some("root"))
        );

        // Create a block with no device attribute
        let mut orphan_block = create_test_block(
            "orphan",
            "paragraph",
            "",
            "3",
            None,
            Some("root")
        );
        orphan_block.attributes.remove("device");
        blocks.insert("orphan".to_string(), orphan_block);

        // Create children map
        let mut children_map = HashMap::new();
        children_map.insert(
            "root".to_string(),
            vec!["a1".to_string(), "a2".to_string(), "orphan".to_string()]
        );

        // Sort blocks
        let sorted = ChainSorting::sort_blocks_by_chain(&blocks);
        let sorted_root = &sorted["root"];

        // Verify all blocks are present
        assert_eq!(sorted_root.len(), 3, "No blocks should be lost during sorting");
        assert!(sorted_root.contains(&"a1".to_string()), "a1 should be present");
        assert!(sorted_root.contains(&"a2".to_string()), "a2 should be present");
        assert!(sorted_root.contains(&"orphan".to_string()), "orphan should be present");
    }

    #[test]
    fn test_multiple_blocks_same_prev_id() {
        // Test the case where multiple blocks have the same prev_id
        // This simulates two devices inserting after the same block
        let mut blocks = HashMap::new();
        blocks.insert(
            "a1".to_string(),
            create_test_block("a1", "paragraph", "device_a", "1", None, Some("root"))
        );

        // Both b1 and c1 have a1 as prev_id (inserted by different devices)
        blocks.insert(
            "b1".to_string(),
            create_test_block("b1", "paragraph", "device_b", "2", Some("a1"), Some("root"))
        );
        blocks.insert(
            "c1".to_string(),
            create_test_block("c1", "paragraph", "device_c", "3", Some("a1"), Some("root"))
        );

        // Create children map
        let mut children_map = HashMap::new();
        children_map.insert(
            "root".to_string(),
            vec!["a1".to_string(), "b1".to_string(), "c1".to_string()]
        );

        // Sort blocks
        let sorted = ChainSorting::sort_blocks_by_chain(&blocks);
        let sorted_root = &sorted["root"];

        // Verify:
        // 1. All blocks are present
        assert_eq!(sorted_root.len(), 3, "All blocks should be present");

        // 2. a1 should come before both b1 and c1
        let a1_pos = sorted_root
            .iter()
            .position(|id| id == "a1")
            .unwrap();
        let b1_pos = sorted_root
            .iter()
            .position(|id| id == "b1")
            .unwrap();
        let c1_pos = sorted_root
            .iter()
            .position(|id| id == "c1")
            .unwrap();

        assert!(a1_pos < b1_pos, "a1 should come before b1");
        assert!(a1_pos < c1_pos, "a1 should come before c1");

        // Current implementation will group by device, so b1 and c1 won't be directly connected to a1
        // This is a limitation of the current algorithm
    }

    #[test]
    fn test_improved_block_sorting() {
        // Create test data for the improved algorithm
        let mut blocks = HashMap::new();
        blocks.insert(
            "a1".to_string(),
            create_test_block("a1", "paragraph", "device_a", "1", None, Some("root"))
        );

        // Both b1 and c1 have a1 as prev_id (inserted by different devices)
        blocks.insert(
            "b1".to_string(),
            create_test_block("b1", "paragraph", "device_b", "2", Some("a1"), Some("root"))
        );
        blocks.insert(
            "c1".to_string(),
            create_test_block("c1", "paragraph", "device_c", "3", Some("a1"), Some("root"))
        );

        // Additional blocks in the chain
        blocks.insert(
            "b2".to_string(),
            create_test_block("b2", "paragraph", "device_b", "4", Some("b1"), Some("root"))
        );

        // Create children map
        let mut children_map = HashMap::new();
        children_map.insert(
            "root".to_string(),
            vec!["a1".to_string(), "b1".to_string(), "c1".to_string(), "b2".to_string()]
        );

        // Sort blocks using the new chain-based algorithm
        let sorted = ChainSorting::sort_blocks_by_chain(&blocks);
        let sorted_root = &sorted["root"];

        // Verify:
        // 1. All blocks are present
        assert_eq!(sorted_root.len(), 4, "All blocks should be present");

        // 2. Check proper ordering based on timestamps
        // a1 should be first since it has no prev_id
        assert_eq!(sorted_root[0], "a1", "a1 should be first as it has no prev_id");

        // Either b1 or c1 should come next as they both reference a1
        // Based on the timestamps, c1 should come after b1
        let b1_pos = sorted_root
            .iter()
            .position(|id| id == "b1")
            .unwrap();
        let c1_pos = sorted_root
            .iter()
            .position(|id| id == "c1")
            .unwrap();
        let b2_pos = sorted_root
            .iter()
            .position(|id| id == "b2")
            .unwrap();

        // Check b1 -> b2 chain is maintained
        assert!(b1_pos < b2_pos, "b2 should follow b1 in the chain");
    }

    #[test]
    fn test_complex_document_structure() {
        // Create a complex graph of blocks with multiple chains and interconnections
        let mut blocks = HashMap::new();

        // Device A: Main chain with branches
        blocks.insert(
            "a1".to_string(),
            create_test_block("a1", "paragraph", "device_a", "10", None, Some("root"))
        );
        blocks.insert(
            "a2".to_string(),
            create_test_block("a2", "paragraph", "device_a", "20", Some("a1"), Some("root"))
        );
        blocks.insert(
            "a3".to_string(),
            create_test_block("a3", "paragraph", "device_a", "30", Some("a2"), Some("root"))
        );
        blocks.insert(
            "a4".to_string(),
            create_test_block("a4", "paragraph", "device_a", "25", Some("a2"), Some("root"))
        ); // Branch from a2
        blocks.insert(
            "a5".to_string(),
            create_test_block("a5", "paragraph", "device_a", "35", Some("a4"), Some("root"))
        );

        // Device B: Chain with connections to Device A
        blocks.insert(
            "b1".to_string(),
            create_test_block("b1", "paragraph", "device_b", "15", None, Some("root"))
        );
        blocks.insert(
            "b2".to_string(),
            create_test_block("b2", "paragraph", "device_b", "25", Some("b1"), Some("root"))
        );
        blocks.insert(
            "b3".to_string(),
            create_test_block("b3", "paragraph", "device_b", "35", Some("b1"), Some("root"))
        ); // Branch from b1
        blocks.insert(
            "b4".to_string(),
            create_test_block("b4", "paragraph", "device_b", "45", Some("a3"), Some("root"))
        ); // Links to device A's chain
        blocks.insert(
            "b5".to_string(),
            create_test_block("b5", "paragraph", "device_b", "55", Some("b3"), Some("root"))
        );

        // Device C: Chain with connections to both Device A and B
        blocks.insert(
            "c1".to_string(),
            create_test_block("c1", "paragraph", "device_c", "22", None, Some("root"))
        );
        blocks.insert(
            "c2".to_string(),
            create_test_block("c2", "paragraph", "device_c", "32", Some("b2"), Some("root"))
        ); // Links to device B's chain
        blocks.insert(
            "c3".to_string(),
            create_test_block("c3", "paragraph", "device_c", "42", Some("a4"), Some("root"))
        ); // Links to device A's branch

        // Edge cases: Same timestamps
        blocks.insert(
            "d1".to_string(),
            create_test_block("d1", "paragraph", "device_d", "25", None, Some("root"))
        ); // Same timestamp as a4 and b2
        blocks.insert(
            "d2".to_string(),
            create_test_block("d2", "paragraph", "device_d", "25", Some("d1"), Some("root"))
        );

        // Problematic cases: Multiple blocks with the same prev_id
        blocks.insert(
            "e1".to_string(),
            create_test_block("e1", "paragraph", "device_e", "40", Some("a3"), Some("root"))
        ); // Same prev as b4
        blocks.insert(
            "e2".to_string(),
            create_test_block("e2", "paragraph", "device_e", "42", Some("a3"), Some("root"))
        ); // Same prev as b4 and e1

        // Cycle detection case
        blocks.insert(
            "f1".to_string(),
            create_test_block("f1", "paragraph", "device_f", "60", Some("f2"), Some("root"))
        );
        blocks.insert(
            "f2".to_string(),
            create_test_block("f2", "paragraph", "device_f", "70", Some("f1"), Some("root"))
        );

        // Block with non-existent prev_id
        blocks.insert(
            "g1".to_string(),
            create_test_block(
                "g1",
                "paragraph",
                "device_g",
                "80",
                Some("doesnt_exist"),
                Some("root")
            )
        );

        // Children pointing to the same blocks
        let mut children_map = HashMap::new();
        children_map.insert(
            "root".to_string(),
            vec![
                "a1".to_string(),
                "a2".to_string(),
                "a3".to_string(),
                "a4".to_string(),
                "a5".to_string(),
                "b1".to_string(),
                "b2".to_string(),
                "b3".to_string(),
                "b4".to_string(),
                "b5".to_string(),
                "c1".to_string(),
                "c2".to_string(),
                "c3".to_string(),
                "d1".to_string(),
                "d2".to_string(),
                "e1".to_string(),
                "e2".to_string(),
                "f1".to_string(),
                "f2".to_string(),
                "g1".to_string()
            ]
        );

        // Create a nested structure to test parent/child relationships
        blocks.insert(
            "parent".to_string(),
            create_test_block("parent", "container", "device_a", "5", None, Some("root"))
        );
        blocks.insert(
            "child1".to_string(),
            create_test_block("child1", "paragraph", "device_a", "6", None, Some("parent"))
        );
        blocks.insert(
            "child2".to_string(),
            create_test_block(
                "child2",
                "paragraph",
                "device_b",
                "7",
                Some("child1"),
                Some("parent")
            )
        );
        blocks.insert(
            "child3".to_string(),
            create_test_block(
                "child3",
                "paragraph",
                "device_c",
                "8",
                Some("child1"),
                Some("parent")
            )
        );

        children_map.insert(
            "parent".to_string(),
            vec!["child1".to_string(), "child2".to_string(), "child3".to_string()]
        );

        // Sort blocks usingpp the chain-based algorithm
        let sorted = ChainSorting::sort_blocks_by_chain(&blocks);

        // Verify root level sorting
        let sorted_root = &sorted["root"];

        // Test that all blocks are present
        assert_eq!(sorted_root.len(), 21, "All blocks should be present in the result");

        // Test specific chain relationships
        let a1_pos = sorted_root
            .iter()
            .position(|id| id == "a1")
            .unwrap();
        let a2_pos = sorted_root
            .iter()
            .position(|id| id == "a2")
            .unwrap();
        let a3_pos = sorted_root
            .iter()
            .position(|id| id == "a3")
            .unwrap();
        let b4_pos = sorted_root
            .iter()
            .position(|id| id == "b4")
            .unwrap();
        let e1_pos = sorted_root
            .iter()
            .position(|id| id == "e1")
            .unwrap();
        let e2_pos = sorted_root
            .iter()
            .position(|id| id == "e2")
            .unwrap();

        // Test chain preservation
        assert!(a1_pos < a2_pos && a2_pos < a3_pos, "Device A main chain should be preserved");

        // Test cross-device linking
        assert!(a3_pos < b4_pos, "b4 should follow a3 as it points to it");

        // Test multiple blocks with same prev_id
        assert!(
            a3_pos < b4_pos && a3_pos < e1_pos && a3_pos < e2_pos,
            "All blocks pointing to a3 should follow a3"
        );

        // Test branched structure within same device
        let a4_pos = sorted_root
            .iter()
            .position(|id| id == "a4")
            .unwrap();
        let a5_pos = sorted_root
            .iter()
            .position(|id| id == "a5")
            .unwrap();
        assert!(a2_pos < a4_pos && a4_pos < a5_pos, "Branch from a2->a4->a5 should be preserved");

        // Test nested parent/child relationship
        let sorted_parent = &sorted["parent"];
        assert_eq!(sorted_parent.len(), 3, "Parent should have 3 children");

        let child1_pos = sorted_parent
            .iter()
            .position(|id| id == "child1")
            .unwrap();
        let child2_pos = sorted_parent
            .iter()
            .position(|id| id == "child2")
            .unwrap();
        let child3_pos = sorted_parent
            .iter()
            .position(|id| id == "child3")
            .unwrap();

        assert_eq!(child1_pos, 0, "child1 should be first as it has no prev_id");
        assert!(
            child1_pos < child2_pos && child1_pos < child3_pos,
            "child2 and child3 should follow child1 as they both point to it"
        );

        // Check cyclic dependency handling
        let f1_pos = sorted_root
            .iter()
            .position(|id| id == "f1")
            .unwrap();
        let f2_pos = sorted_root
            .iter()
            .position(|id| id == "f2")
            .unwrap();

        // Regardless of how the cycle is handled, one must come before the other
        assert!(f1_pos != f2_pos, "f1 and f2 should be included in the result despite the cycle");

        // Check non-existent prev_id
        assert!(
            sorted_root.contains(&"g1".to_string()),
            "Block with non-existent prev_id should still be included"
        );
    }

    #[test]
    fn test_external_prev_id_becomes_root() {
        // A block with prev_id pointing to a block not in current children becomes root
        let mut blocks = HashMap::new();
        blocks.insert(
            "a1".to_string(),
            create_test_block("a1", "para", "device_a", "1", None, Some("root"))
        );
        // b1's prev_id points to a2 which doesn't exist in children
        blocks.insert(
            "b1".to_string(),
            create_test_block("b1", "para", "device_b", "2", Some("a2"), Some("root"))
        );

        let mut children_map = HashMap::new();
        children_map.insert("root".to_string(), vec!["a1".to_string(), "b1".to_string()]);

        let sorted = ChainSorting::sort_blocks_by_chain(&blocks);
        let sorted_root = &sorted["root"];

        // b1 should be treated as root since its prev_id is invalid
        // Order should be device_a first (sorted devices), then device_b
        assert_eq!(sorted_root, &["a1", "b1"]);
    }

    #[test]
    fn test_valid_prev_id_across_devices() {
        // prev_id valid but points to block from different device
        let mut blocks = HashMap::new();
        blocks.insert(
            "a1".to_string(),
            create_test_block("a1", "para", "device_a", "1", None, Some("root"))
        );
        blocks.insert(
            "b1".to_string(),
            create_test_block("b1", "para", "device_b", "2", Some("a1"), Some("root"))
        );

        let mut children_map = HashMap::new();
        children_map.insert("root".to_string(), vec!["a1".to_string(), "b1".to_string()]);

        let sorted = ChainSorting::sort_blocks_by_chain(&blocks);
        let sorted_root = &sorted["root"];

        // Even though b1 points to a1, devices should be grouped
        // Device A (a1) first, then device B (b1 as root)
        assert_eq!(sorted_root, &["a1", "b1"]);
    }

    #[test]
    fn test_mixed_valid_and_invalid_prev_id() {
        // Some valid prev_ids, some invalid within same device
        let mut blocks = HashMap::new();
        blocks.insert(
            "a1".to_string(),
            create_test_block("a1", "para", "device_a", "1", None, Some("root"))
        );
        blocks.insert(
            "a2".to_string(),
            create_test_block("a2", "para", "device_a", "2", Some("a1"), Some("root"))
        );
        blocks.insert(
            "a3".to_string(),
            create_test_block("a3", "para", "device_a", "3", Some("invalid"), Some("root"))
        );

        let mut children_map = HashMap::new();
        children_map.insert(
            "root".to_string(),
            vec!["a1".to_string(), "a2".to_string(), "a3".to_string()]
        );

        let sorted = ChainSorting::sort_blocks_by_chain(&blocks);
        let sorted_root = &sorted["root"];

        // Should have a1->a2 chain first, then a3 as root
        assert_eq!(sorted_root, &["a1", "a2", "a3"]);
    }

    #[test]
    fn test_multiple_roots_in_device() {
        // Device has multiple root blocks (no valid prev_ids)
        let mut blocks = HashMap::new();
        blocks.insert(
            "a1".to_string(),
            create_test_block("a1", "para", "device_a", "1", None, Some("root"))
        );
        blocks.insert(
            "a2".to_string(),
            create_test_block("a2", "para", "device_a", "2", None, Some("root"))
        );
        blocks.insert(
            "a3".to_string(),
            create_test_block("a3", "para", "device_a", "3", Some("a1"), Some("root"))
        );

        let mut children_map = HashMap::new();
        children_map.insert(
            "root".to_string(),
            vec!["a1".to_string(), "a2".to_string(), "a3".to_string()]
        );

        let sorted = ChainSorting::sort_blocks_by_chain(&blocks);
        let sorted_root = &sorted["root"];

        // Roots sorted by timestamp: a1 (1), a2 (2)
        // Followed by a3 chain
        assert_eq!(sorted_root, &["a1", "a3", "a2"]);
    }

    #[test]
    fn test_deep_chain_with_device_groups() {
        // Complex chains within and across devices
        let mut blocks = HashMap::new();
        // Device A chain
        blocks.insert(
            "a1".to_string(),
            create_test_block("a1", "para", "device_a", "1", None, Some("root"))
        );
        blocks.insert(
            "a2".to_string(),
            create_test_block("a2", "para", "device_a", "2", Some("a1"), Some("root"))
        );
        
        // Device B chain with cross-device reference
        blocks.insert(
            "b1".to_string(),
            create_test_block("b1", "para", "device_b", "3", Some("a2"), Some("root"))
        );
        blocks.insert(
            "b2".to_string(),
            create_test_block("b2", "para", "device_b", "4", Some("b1"), Some("root"))
        );

        // Device C independent chain
        blocks.insert(
            "c1".to_string(),
            create_test_block("c1", "para", "device_c", "5", None, Some("root"))
        );

        let mut children_map = HashMap::new();
        children_map.insert(
            "root".to_string(),
            vec!["a1".to_string(), "a2".to_string(), "b1".to_string(), "b2".to_string(), "c1".to_string()]
        );

        let sorted = ChainSorting::sort_blocks_by_chain(&blocks);
        let sorted_root = &sorted["root"];

        // Expected order:
        // 1. device_a: a1->a2
        // 2. device_b: b1 (prev_id valid but in different device) -> b2
        // 3. device_c: c1
        // Actual order depends on device sorting (device_a, device_b, device_c)
        assert!(sorted_root[0] == "a1" && sorted_root[1] == "a2");
        assert!(sorted_root[2] == "b1" && sorted_root[3] == "b2");
        assert_eq!(sorted_root[4], "c1");
    }

    #[test]
    fn test_moved_block_with_new_parent() {
        // Block moved to new parent with prev_id from old parent
        let mut blocks = HashMap::new();
        // Original parent blocks
        blocks.insert(
            "p1a".to_string(),
            create_test_block("p1a", "para", "device_a", "1", None, Some("parent1"))
        );
        blocks.insert(
            "p1b".to_string(),
            create_test_block("p1b", "para", "device_a", "2", Some("p1a"), Some("parent1"))
        );
        
        // New parent with moved block
        blocks.insert(
            "p2a".to_string(),
            create_test_block("p2a", "para", "device_b", "3", Some("p1b"), Some("parent2"))
        );

        let mut children_map = HashMap::new();
        children_map.insert("parent1".to_string(), vec!["p1a".to_string(), "p1b".to_string()]);
        children_map.insert("parent2".to_string(), vec!["p2a".to_string()]);

        let sorted = ChainSorting::sort_blocks_by_chain(&blocks);

        // In parent2, p2a's prev_id (p1b) doesn't exist -> should be root
        assert_eq!(sorted["parent2"], vec!["p2a"]);
    }

}
