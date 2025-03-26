// #[cfg(test)]
// mod tests {
//     use serde_json::json;
//     use yrs::{Doc, Map, MapRef, TransactionMut, Array, ArrayRef, ReadTxn, Transact};
//     use yrs::types::{Attrs, ToJson};
//     use yrs::updates::decoder::Decode;
//     use yrs::updates::encoder::Encode;
//     use yrs::updates::Update;
//     use std::sync::Arc;
//     use std::collections::HashMap;
//     use crate::doc::constants::{BLOCKS, CHILDREN_MAP, ID, PARENT_ID, PREV_ID};
//     use crate::doc::operations::block_ops::BlockOperations;
//     use crate::doc::document_types::CustomRustError;
//     use crate::doc::error::DocError;
//     use crate::doc::utils::util::MapExt;

//     /// Converts a Yrs ArrayRef to a Vec<String> for easier comparison in tests
//     fn array_to_vec<T: ReadTxn>(txn: &T, array: &ArrayRef) -> Vec<String> {
//         let mut result = Vec::new();
//         for i in 0..array.len(txn) {
//             if let Some(item) = array.get(txn, i) {
//                 result.push(item.to_string(txn));
//             }
//         }
//         result
//     }

//     /// Extension trait for Yrs ArrayRef to add testing utilities
//     trait ArrayRefTestExt {
//         /// Convert the array to a Vec<String> for easier assertions
//         fn to_vec<T: ReadTxn>(&self, txn: &T) -> Vec<String>;
        
//         /// Assert that the array contains exactly the expected items
//         fn assert_items<T: ReadTxn>(&self, txn: &T, expected: &[&str]);
//     }

//     impl ArrayRefTestExt for ArrayRef {
//         fn to_vec<T: ReadTxn>(&self, txn: &T) -> Vec<String> {
//             let mut result = Vec::new();
//             for i in 0..self.len(txn) {
//                 if let Some(item) = self.get(txn, i) {
//                     result.push(item.to_string(txn));
//                 }
//             }
//             result
//         }
        
//         fn assert_items<T: ReadTxn>(&self, txn: &T, expected: &[&str]) {
//             let actual = self.to_vec(txn);
//             assert_eq!(
//                 actual.len(), 
//                 expected.len(), 
//                 "Array length mismatch. Got: {:?}, Expected: {:?}", 
//                 actual, expected
//             );
            
//             for (i, exp) in expected.iter().enumerate() {
//                 assert_eq!(
//                     actual[i], 
//                     exp.to_string(), 
//                     "Item at position {} differs. Got: {}, Expected: {}", 
//                     i, actual[i], exp
//                 );
//             }
//         }
//     }

//     // Helper function to create a block with given ID and optional parent_id and prev_id
//     fn create_block(
//         txn: &mut TransactionMut,
//         blocks_map: MapRef,
//         id: &str,
//         parent_id: Option<&str>,
//         prev_id: Option<&str>,
//     ) {
//         let block = blocks_map.get_or_init_map(txn, id);
//         block.insert(txn, Arc::from(ID), id.to_string());
//         if let Some(parent) = parent_id {
//             block.insert(txn, Arc::from(PARENT_ID), parent.to_string());
//         }
//         if let Some(prev) = prev_id {
//             block.insert(txn, Arc::from(PREV_ID), prev.to_string());
//         }
//     }

//     // Helper function to get children array for a parent
//     fn get_children<'a>(txn: &'a mut &mut TransactionMut, children_map: MapRef, parent_id: &str) -> ArrayRef {
//         children_map.get_or_init_array(*txn, parent_id)
//     }

//     #[test]
//     fn move_within_same_parent() {
//         let doc = Doc::new();
//         let mut txn = doc.transact_mut();
//         let blocks_map = doc.get_or_insert_map(BLOCKS);
//         let children_map = doc.get_or_insert_map(CHILDREN_MAP);

//         // Setup blocks
//         create_block(&mut txn, blocks_map.clone(), "A", Some("P1"), None);
//         create_block(&mut txn, blocks_map.clone(), "B", Some("P1"), Some("A"));
//         create_block(&mut txn, blocks_map.clone(), "C", Some("P1"), Some("B"));

//         let p1_children = get_children(txn, children_map.clone(), "P1");
//         p1_children.push_back(&mut txn, "A");
//         p1_children.push_back(&mut txn, "B");
//         p1_children.push_back(&mut txn, "C");

//         // Move B after C
//         BlockOperations::move_block(
//             &mut txn, children_map.clone(), blocks_map.clone(), &[1], &[2], "P1", "P1", "B", 
//             Some("C".to_string()), None
//         ).unwrap();

//         // Verify
//         p1_children.assert_items(&txn, &["A", "C", "B"]);
        
//         let c_block = blocks_map.get_or_init_map(&mut &txn, "C");
//         assert_eq!(c_block.get(&txn, PREV_ID).unwrap().to_string(&txn), "A");
        
//         let b_block = blocks_map.get_or_init_map(&mut &txn, "B");
//         assert_eq!(b_block.get(&txn, PREV_ID).unwrap().to_string(&txn), "C");
//         assert_eq!(b_block.get(&txn, PARENT_ID).unwrap().to_string(&txn), "P1");
//     }

//     #[test]
//     fn move_to_different_parent() {
//         let doc = Doc::new();
//         let mut txn = doc.transact_mut();
//         let blocks_map = doc.get_or_insert_map(BLOCKS);
//         let children_map = doc.get_or_insert_map(CHILDREN_MAP);

//         // Setup P1
//         create_block(&mut txn, blocks_map.clone(), "A", Some("P1"), None);
//         create_block(&mut txn, blocks_map.clone(), "B", Some("P1"), Some("A"));
//         create_block(&mut txn, blocks_map.clone(), "C", Some("P1"), Some("B"));
//         let p1_children = get_children(&txn, children_map.clone(), "P1");
//         p1_children.push_back(&mut txn, "A");
//         p1_children.push_back(&mut txn, "B");
//         p1_children.push_back(&mut txn, "C");

//         // Setup P2
//         create_block(&mut txn, blocks_map.clone(), "D", Some("P2"), None);
//         create_block(&mut txn, blocks_map.clone(), "E", Some("P2"), Some("D"));
//         let p2_children = get_children(&txn, children_map.clone(), "P2");
//         p2_children.push_back(&mut txn, "D");
//         p2_children.push_back(&mut txn, "E");

//         // Move B to P2 after D
//         BlockOperations::move_block(
//             &mut txn, children_map.clone(), blocks_map.clone(), &[1], &[1], "P2", "P1", "B",
//             Some("D".to_string()), Some("E".to_string())
//         ).unwrap();

//         // Verify
//         p1_children.assert_items(&txn, &["A", "C"]);
//         p2_children.assert_items(&txn, &["D", "B", "E"]);
        
//         let c_block = blocks_map.get_or_init_map(&mut &txn, "C");
//         assert_eq!(c_block.get(&txn, PREV_ID).unwrap().to_string(&txn), "A");
        
//         let b_block = blocks_map.get_or_init_map(&mut &txn, "B");
//         assert_eq!(b_block.get(&txn, PREV_ID).unwrap().to_string(&txn), "D");
//         assert_eq!(b_block.get(&txn, PARENT_ID).unwrap().to_string(&txn), "P2");
        
//         let e_block = blocks_map.get_or_init_map(&mut &txn, "E");
//         assert_eq!(e_block.get(&txn, PREV_ID).unwrap().to_string(&txn), "B");
//     }

//     #[test]
//     fn move_with_children() {
//         let doc = Doc::new();
//         let mut txn = doc.transact_mut();
//         let blocks_map = doc.get_or_insert_map(BLOCKS);
//         let children_map = doc.get_or_insert_map(CHILDREN_MAP);

//         // Setup
//         create_block(&mut txn, blocks_map.clone(), "A", Some("P1"), None);
//         create_block(&mut txn, blocks_map.clone(), "B", Some("A"), None);
//         create_block(&mut txn, blocks_map.clone(), "C", Some("A"), None);
//         create_block(&mut txn, blocks_map.clone(), "D", Some("B"), None);
//         create_block(&mut txn, blocks_map.clone(), "E", Some("B"), None);

//         let p1_children = get_children(&txn, children_map.clone(), "P1");
//         p1_children.push_back(&mut txn, "A");
//         let a_children = get_children(&txn, children_map.clone(), "A");
//         a_children.push_back(&mut txn, "B");
//         a_children.push_back(&mut txn, "C");
//         let b_children = get_children(&txn, children_map.clone(), "B");
//         b_children.push_back(&mut txn, "D");
//         b_children.push_back(&mut txn, "E");

//         // Move A to P2
//         BlockOperations::move_block(
//             &mut txn, children_map.clone(), blocks_map.clone(), &[0], &[0], "P2", "P1", "A", None, None
//         ).unwrap();

//         // Verify
//         assert_eq!(p1_children.len(&txn), 0);
//         let p2_children = get_children(&txn, children_map.clone(), "P2");
//         p2_children.assert_items(&txn, &["A"]);
        
//         let a_block = blocks_map.get_or_init_map(&mut &txn, "A");
//         assert_eq!(a_block.get(&txn, PARENT_ID).unwrap().to_string(&txn), "P2");
//         a_children.assert_items(&txn, &["B", "C"]);
        
//         let b_block = blocks_map.get_or_init_map(&mut &txn, "B");
//         assert_eq!(b_block.get(&txn, PARENT_ID).unwrap().to_string(&txn), "A");
//         b_children.assert_items(&txn, &["D", "E"]);
//     }

//     #[test]
//     fn detect_cycle() {
//         let doc = Doc::new();
//         let mut txn = doc.transact_mut();
//         let blocks_map = doc.get_or_insert_map(BLOCKS);
//         let children_map = doc.get_or_insert_map(CHILDREN_MAP);

//         // Setup
//         create_block(&mut txn, blocks_map.clone(), "A", Some("P1"), None);
//         create_block(&mut txn, blocks_map.clone(), "B", Some("P1"), Some("A"));
//         let children = get_children(&txn, children_map.clone(), "P1");
//         children.push_back(&mut txn, "A");
//         children.push_back(&mut txn, "B");

//         // Attempt to move A with prev_id="B" (creates cycle)
//         let result = BlockOperations::move_block(
//             &mut txn, children_map.clone(), blocks_map.clone(), &[0], &[0], "P1", "P1", "A", 
//             Some("B".to_string()), None
//         );
//         assert!(result.is_err());
//         assert!(result.unwrap_err().to_string().contains("cycle"));
//     }

//     #[test]
//     fn invalid_prev_id() {
//         let doc = Doc::new();
//         let mut txn = doc.transact_mut();
//         let blocks_map = doc.get_or_insert_map(BLOCKS);
//         let children_map = doc.get_or_insert_map(CHILDREN_MAP);

//         // Setup
//         create_block(&mut txn, blocks_map.clone(), "A", Some("P1"), None);
//         let children = get_children(&txn, children_map.clone(), "P1");
//         children.push_back(&mut txn, "A");

//         // Attempt to move A with invalid prev_id="X"
//         let result = BlockOperations::move_block(
//             &mut txn, children_map.clone(), blocks_map.clone(), &[0], &[0], "P1", "P1", "A", 
//             Some("X".to_string()), None
//         );
//         assert!(result.is_err());
//         assert!(result.unwrap_err().to_string().contains("does not exist"));
//     }
// }