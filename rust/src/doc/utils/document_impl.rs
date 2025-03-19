use flutter_rust_bridge::{ frb, DartFnFuture };
use log::{ error, info };
use serde_json::{ json, Map as JsonMap, Value };
use std::{ collections::HashMap, sync::{ Arc, Mutex } };
use yrs::{
    merge_updates_v2,
    types::Delta,
    updates::decoder::Decode,
    Array,
    ArrayPrelim,
    ArrayRef,
    Doc,
    Map,
    MapPrelim,
    MapRef,
    Out,
    ReadTxn,
    Text,
    TextPrelim,
    Transact,
};

use super::util::{ ArrayExt, MapExt, TextExt };
use crate::doc::document_types::{
    BlockActionDoc,
    BlockActionTypeDoc,
    BlockDoc,
    CustomRustError,
    DocumentState,
    FailedToDecodeUpdates,
};

// Define keys for the document map
const BLOCKS: &str = "blocks";
const CHILDREN_MAP: &str = "childrenMap";
const ROOT_ID: &str = "document";
const ROOT_TYPE: &str = "page";
const ATTRIBUTES: &str = "attributes";
const TEXT: &str = "text";
const ID: &str = "id";
const TYPE: &str = "type";
const PARENT_ID: &str = "parentId";
const PREV_ID: &str = "prevId";
const INSERT: &str = "insert";
const RETAIN: &str = "retain";
const DELETE: &str = "delete";
const DEFAULT_PARENT: &str = "default_parent";

// Define a macro for combined println and info logging
macro_rules! println_info {
    ($($arg:tt)*) => {
        {
        let message = format!($($arg)*);
        info!("{}", message);
        println!("{}", message);
        }
    };
}

// Define a macro for combined println and error logging
macro_rules! println_error {
    ($($arg:tt)*) => {
        {
        let message = format!($($arg)*);
        error!("{}", message);
        println!("{}", message);
        }
    };
}

#[frb(ignore)]
pub struct DocumentServiceImpl {
    doc: Doc, // Thread-safe Doc
    doc_id: String,
}

impl DocumentServiceImpl {
    pub fn new(doc_id: String) -> Self {
        println_info!("new: Starting for doc_id: {}", doc_id);
        let doc = Doc::new();
        Self { doc_id, doc }
    }

    // //Write a function that will combine updates together
    // //This function will take in a vector of updates and return a single update
    // //The function will be called combine_updates
    // //The function will take in a vector of updates and return a single update

    // pub fn combine_updates(updates: Vec<Vec<u8>>) -> Vec<u8> {
    //     merge_updates_v2(updates)
    // }

    #[no_mangle]
    #[inline(never)]
    pub fn init_empty_doc_inner(&mut self) -> Result<Vec<u8>, CustomRustError> {
        let doc_id = self.doc_id.clone();
        println_info!("init_empty_doc: Starting for doc_id: {}", doc_id);

        // // Attempt to lock the mutex, handling poisoning
        // let mut doc_guard = self.doc.lock().map_err(|poisoned| {
        //     println_error!(
        //         "Failed to lock mutex for doc_id: {} due to poisoning",
        //         doc_id
        //     );
        //     ConcurrentAccessError::new("Mutex poisoned, concurrent access detected")
        // })?;
        let doc_guard = self.doc.clone();

        // Ensure the lock is dropped if an error occurs
        let result = (|| {
            let root = doc_guard.get_or_insert_map(ROOT_ID); // No error handling
            let mut txn = doc_guard.transact_mut();

            println_info!("init_empty_doc: Initializing blocks for doc_id: {}", doc_id);
            root.get_or_init_map(&mut txn, BLOCKS); // No error handling
            println_info!("init_empty_doc: Initializing childrenMap for doc_id: {}", doc_id);
            root.get_or_init_map(&mut txn, CHILDREN_MAP); // No error handling
            println_info!("init_empty_doc: Finished for doc_id: {}", doc_id);

            println_info!("init_empty_doc: Encoding state for doc_id: {}", self.doc_id);
            let empty_state = yrs::StateVector::default(); // Full state
            let result = txn.encode_state_as_update_v2(&empty_state); // No error handling per your clarification

            Ok(result)
        })();

        // The lock is automatically released here when doc_guard goes out of scope
        result
    }

    #[no_mangle]
    #[inline(never)]
    pub fn apply_action_inner(
        &mut self,
        actions: Vec<BlockActionDoc>,
        diff_deltas: &impl Fn(String, String) -> DartFnFuture<String>
    ) -> Result<Vec<u8>, CustomRustError> {
        println_info!(
            "apply_action: Starting with {} actions for doc_id: {}",
            actions.len(),
            self.doc_id
        );

        // let mut doc_guard = self.doc.lock().map_err(|poisoned| {
        //     println_error!(
        //         "Failed to lock mutex for doc_id: {} due to poisoning in apply_action_inner",
        //         self.doc_id
        //     );
        //     ConcurrentAccessError::new("Mutex poisoned, concurrent access detected")
        // })?;
        let doc_guard = self.doc.clone();

        let result = (|| {
            let root = doc_guard.get_or_insert_map(ROOT_ID); // No error handling
            let mut txn = doc_guard.transact_mut();

            for action in actions {
                println_info!(
                    "apply_action: Processing action {:?} for block_id: {}",
                    action.action,
                    action.block.id
                );
                let children_map = root.get_or_init_map(&mut txn, CHILDREN_MAP); // No error handling
                let blocks_map = root.get_or_init_map(&mut txn, BLOCKS); // No error handling
                match action.action {
                    BlockActionTypeDoc::Move => {
                        if
                            action.old_path.is_some() &&
                            action.block.parent_id.is_some() &&
                            action.block.old_parent_id.is_some()
                        {
                            let block_id = action.block.id.clone();
                            println_info!("apply_action: Moving block_id: {}", block_id);
                            let old_path = action.old_path.as_ref().unwrap();
                            let parent_id = action.block.parent_id.as_ref().unwrap();
                            let old_parent_id = action.block.old_parent_id.as_ref().unwrap();
                            let prev_id = action.block.prev_id.clone();
                            let new_path = &action.path;
                            Self::move_block(
                                &mut txn,
                                children_map,
                                blocks_map,
                                old_path,
                                new_path,
                                parent_id,
                                old_parent_id,
                                &block_id,
                                prev_id
                            );
                            println_info!("apply_action: Moved block_id: {}", block_id);
                        } else {
                            println_error!("Invalid Move action: missing required fields");
                            return Err(
                                CustomRustError::new(
                                    "Invalid Move action: missing required fields"
                                )
                            );
                        }
                    }
                    BlockActionTypeDoc::Insert => {
                        let block_id = action.block.id.clone();
                        println_info!("apply_action: Inserting block_id: {}", block_id);
                        Self::insert_node(&mut txn, blocks_map, action, children_map, diff_deltas)?;
                        println_info!("apply_action: Inserted block_id: {}", block_id);
                    }
                    BlockActionTypeDoc::Update => {
                        let block_id = action.block.id.clone();
                        println_info!("apply_action: Updating block_id: {}", block_id);
                        let node = blocks_map.get_or_init_map(&mut txn, block_id.clone()); // No error handling

                        if !action.block.attributes.is_empty() {
                            println_info!("apply_action: Updating attributes for block_id: {}", block_id);
                            let data = node.get_or_init_map(&mut txn, ATTRIBUTES); // No error handling
                            for (k, v) in action.block.attributes {
                                println_info!(
                                    "apply_action: Inserting attribute {} for block_id: {}",
                                    k,
                                    block_id
                                );
                                data.insert(&mut txn, k, v);
                            }
                        }
                        if let Some(delta_json) = action.block.delta {
                            println_info!("apply_action: Applying delta to block_id: {}", block_id);
                            let text = node.get_or_init_text(&mut txn, TEXT); // No error handling
                            Self::apply_delta_to_text(&mut txn, text, delta_json, diff_deltas);
                        }
                        println_info!("apply_action: Updated block_id: {}", block_id);
                    }
                    BlockActionTypeDoc::Delete => {
                        let block_id = action.block.id.clone();
                        println_info!("apply_action: Deleting block_id: {}", block_id);
                        let parent_id = action.block.parent_id.unwrap_or_else(||
                            DEFAULT_PARENT.to_owned()
                        );
                        Self::delete_node(
                            &mut txn,
                            blocks_map,
                            children_map,
                            &block_id,
                            &parent_id
                        );
                        println_info!("apply_action: Deleted block_id: {}", block_id);
                    }
                }
            }

            println_info!("apply_action: Encoding state for doc_id: {}", self.doc_id);
            let before_state = txn.before_state();
            let result = txn.encode_diff_v2(before_state); // No error handling per your clarification

            Ok(result)
        })();

        // The lock is automatically released here when doc_guard goes out of scope
        result
    }

    #[no_mangle]
    #[inline(never)]
    fn is_same_path_except_last(old_path: &[u32], new_path: &[u32]) -> bool {
        println_info!(
            "is_same_path_except_last: Comparing old_path: {:?}, new_path: {:?}",
            old_path,
            new_path
        );
        let result =
            old_path.len() == new_path.len() &&
            old_path
                .iter()
                .take(old_path.len() - 1)
                .zip(new_path.iter())
                .all(|(a, b)| a == b);
        println_info!("is_same_path_except_last: Result: {}", result);
        result
    }

    #[no_mangle]
    #[inline(never)]
    fn insert_node(
        txn: &mut yrs::TransactionMut,
        blocks_map: MapRef,
        block: BlockActionDoc,
        children_map: MapRef,
        diff_deltas: &impl Fn(String, String) -> DartFnFuture<String>
    ) -> Result<MapRef, CustomRustError> {
        println_info!("insert_node: Starting for block_id: {}", block.block.id);
        let parent_id = block.block.parent_id.unwrap_or_else(|| DEFAULT_PARENT.to_owned()).clone();
        let block_id = block.block.id.clone();
        println_info!("insert_node: Creating node_ref for block_id: {}", block_id);

        let node_ref = blocks_map.get_or_init_map(txn, block_id.clone()); // No error handling

        println_info!("insert_node: Inserting ID for block_id: {}", block_id);
        node_ref.insert(txn, Arc::from(ID), block_id.clone());
        println_info!("insert_node: Inserting Type for block_id: {}", block_id);
        node_ref.insert(txn, Arc::from(TYPE), block.block.ty.clone());
        println_info!("insert_node: Inserting Parent ID for block_id: {}", block_id);
        if parent_id != DEFAULT_PARENT {
            node_ref.insert(txn, Arc::from(PARENT_ID), parent_id.clone());
        }

        println_info!("insert_node: Preparing attributes for block_id: {}", block_id);
        let mut attr_map = MapPrelim::default();
        for (k, v) in block.block.attributes {
            println_info!("insert_node: Adding attribute {} for block_id: {}", k, block_id);
            attr_map.insert(k.into(), v.into());
        }
        node_ref.insert(txn, Arc::from(ATTRIBUTES), attr_map);
        println_info!("insert_node: Inserted attributes for block_id: {}", block_id);

        if let Some(delta_json) = block.block.delta {
            println_info!("insert_node: Applying delta for block_id: {}", block_id);
            let text = node_ref.get_or_init_text(txn, TEXT); // No error handling
            Self::apply_delta_to_text(txn, text, delta_json, diff_deltas);
        }

        //Store prev_id
        if let Some(prev_id) = block.block.prev_id {
            //If another block has my current prev_id as its prev_id, then I want to give that block my prev_id
            let block_with_mine_prev_id = Self::find_block_referencing_prev_id(
                txn,
                blocks_map.clone(),
                &prev_id
            );
            if let Some(block_id_with_mine_prev_id) = block_with_mine_prev_id {
                let block_with_mine_prev_id_data = blocks_map.get_or_init_map(
                    txn,
                    block_id_with_mine_prev_id.clone()
                );
                block_with_mine_prev_id_data.insert(txn, Arc::from(PREV_ID), block_id.clone());
            }

            println_info!("insert_node: Inserting Prev ID for block_id: {}", block_id);
            node_ref.insert(txn, Arc::from(PREV_ID), prev_id.clone());
        }

        if parent_id != DEFAULT_PARENT {
            println_info!("insert_node: Adding to children_map for parent_id: {}", parent_id);
            let parent_children = children_map.get_or_init_array(txn, parent_id.clone()); // No error handling
            let node_index_val = *block.path.last().unwrap_or(&0); // No error handling
            let current_len = parent_children.len(txn);
            if node_index_val > current_len {
                println_error!(
                    "insert_node: node_index {} out of bounds (current length: {}), pushing instead",
                    node_index_val,
                    current_len
                );
                parent_children.push_back(txn, block_id.clone()); // No error handling
            } else {
                parent_children.insert(txn, node_index_val, block_id.clone()); // No error handling
            }

            println_info!(
                "insert_node: Inserted block_id: {} into parent_id: {} at index: {}",
                block_id,
                parent_id,
                node_index_val
            );
        }

        println_info!("insert_node: Initializing children array for block_id: {}", block_id);
        children_map.get_or_init_array(txn, block_id.clone()); // No error handling

        println_info!("insert_node: Finished for block_id: {}", block_id);
        Ok(node_ref)
    }

    fn find_block_referencing_prev_id(
        txn: &yrs::TransactionMut,
        blocks_map: MapRef,
        prev_id_value: &str
    ) -> Option<String> {
        // Iterate over all blocks and look for a block where prev_id equals the provided value
        let mut blocks_map_iter = blocks_map.iter(txn);
        blocks_map_iter
            .find(|(_k, v)| {
                if let yrs::Out::Any(yrs::Any::Map(inner_map)) = v {
                    if let Some(prev_id_out) = inner_map.get(PREV_ID) {
                        if let yrs::Any::String(s) = prev_id_out {
                            return s.to_string() == prev_id_value;
                        }
                    }
                }
                false
            })
            .map(|(id, _)| id.to_string())
    }

    /// Removes a block from the previous ID chain.
    ///
    /// When a block is deleted/moved, we need to maintain the chain of previous ID references.
    /// This function:
    /// 1. Gets the `prev_id` of the block being deleted/moved
    /// 2. Finds any block that references the deleted/moved block as its `prev_id`
    /// 3. Updates that next block to point to the deleted/moved block's `prev_id` instead
    ///
    /// # Arguments
    /// * `txn` - Transaction object for modifying the document
    /// * `blocks_map` - Reference to the map containing all blocks
    /// * `block_id` - ID of the block being deleted/moved
    ///
    #[no_mangle]
    #[inline(never)]
    fn remove_block_from_prev_id_chain(
        txn: &mut yrs::TransactionMut,
        blocks_map: MapRef,
        block_id: &str
    ) {
        // Get the block data of the block being deleted
        let block_data = blocks_map.clone().get_or_init_map(txn, block_id);

        // Get Some(prev_id) if it exists, otherwise None
        let prev_id = block_data.get(txn, PREV_ID).and_then(|out| {
            if let yrs::Out::Any(yrs::Any::String(s)) = out { Some(s.to_string()) } else { None }
        });

        // Find any block that references this block as its prev_id
        let next_block_id = Self::find_block_referencing_prev_id(txn, blocks_map.clone(), block_id);
        if let Some(next_id) = next_block_id {
            let cloned_map = blocks_map.clone();
            let next_block_data = cloned_map.get_or_init_map(txn, next_id);

            if let Some(prev_id) = prev_id {
                next_block_data.insert(txn, Arc::from(PREV_ID), prev_id);
            } else {
                next_block_data.remove(txn, &Arc::from(PREV_ID));
            }
        }
    }

    #[no_mangle]
    #[inline(never)]
    fn delete_node(
        txn: &mut yrs::TransactionMut,
        blocks_map: MapRef,
        children_map: MapRef,
        block_id: &str,
        parent_id: &str
    ) -> Result<(), CustomRustError> {
        //If another block has this block as prev_id, then I want to give that block my prev_id
        let blocks_map_copy = blocks_map.clone();
        Self::remove_block_from_prev_id_chain(txn, blocks_map_copy, block_id);

        if parent_id != DEFAULT_PARENT {
            let parent_children = children_map.get_or_init_array(txn, parent_id); // No error handling
            let node_index_val = parent_children
                .iter(txn)
                .position(|x| x.to_string(txn) == block_id)
                .unwrap_or(0) as u32; // No error handling
            parent_children.remove(txn, node_index_val);
        }

        println_info!("delete_node: Starting for block_id: {}", block_id);
        let children = children_map.get_or_init_array(txn, block_id); // No error handling

        println_info!("delete_node: Collecting children for block_id: {}", block_id);
        let child_ids: Vec<String> = children
            .iter(txn)
            .map(|child| child.to_string(txn)) // No error handling
            .collect();
        println_info!("delete_node: Found {} children for block_id: {}", child_ids.len(), block_id);
        for child_id in child_ids {
            println_info!(
                "delete_node: Recursively deleting child_id: {} of block_id: {}",
                child_id,
                block_id
            );
            if
                let Err(e) = Self::delete_node(
                    txn,
                    blocks_map.clone(),
                    children_map.clone(),
                    &child_id,
                    block_id
                )
            {
                println_error!("Failed to delete child_id {}: {}", child_id, e);
                return Err(e);
            }
        }

        println_info!("delete_node: Removing block_id: {} after children", block_id);
        match blocks_map.remove(txn, block_id) {
            Some(_) => println_info!("Successfully removed block_id {} from blocks_map", block_id),
            None => {
                println_error!("Failed to remove block_id {} from blocks_map: item not found", block_id);
                return Err(
                    CustomRustError::new(
                        "Failed to remove block from blocks map: item not found"
                    )
                );
            }
        }
        match children_map.remove(txn, block_id) {
            Some(_) =>
                println_info!("Successfully removed block_id {} from children_map", block_id),
            None => {
                println_error!("Failed to remove block_id {} from children_map: item not found", block_id);
                return Err(
                    CustomRustError::new(
                        "Failed to remove block from children map: item not found"
                    )
                );
            }
        }

        println_info!("delete_node: Finished for block_id: {}", block_id);
        Ok(())
    }

    #[no_mangle]
    #[inline(never)]
    fn move_block(
        txn: &mut yrs::TransactionMut,
        children_map: MapRef,
        blocks_map: MapRef,
        old_path: &[u32],
        new_path: &[u32],
        parent_id: &str,
        old_parent_id: &str,
        node_id: &str,
        prev_id: Option<String>
    ) -> Result<(), CustomRustError> {
        let parent_id_owned = parent_id.to_string(); // No error handling
        let old_parent_id_owned = old_parent_id.to_string(); // No error handling
        let node_id_owned = node_id.to_string(); // No error handling

        let blocks_map_copy = blocks_map.clone();
        Self::remove_block_from_prev_id_chain(txn, blocks_map_copy, &node_id_owned.clone());

        //Set prev_id if it is some, or remove it if it is none
        let node = blocks_map.get_or_init_map(txn, node_id_owned.clone());
        if let Some(prev_id) = prev_id {
            node.insert(txn, Arc::from(PREV_ID), prev_id);
        } else {
            node.remove(txn, &Arc::from(PREV_ID));
        }

        println_info!(
            "move_block: Starting for node_id: {} from {} to {}",
            node_id_owned,
            old_parent_id_owned,
            parent_id_owned
        );
        let old_index = *old_path.last().ok_or_else(|| {
            println_error!("Empty old_path for node_id: {}", node_id_owned);
            CustomRustError::new("Empty old path for move operation")
        })?;
        let new_index = *new_path.last().ok_or_else(|| {
            println_error!("Empty new_path for node_id: {}", node_id_owned);
            CustomRustError::new("Empty new path for move operation")
        })?;

        if parent_id_owned == old_parent_id_owned {
            println_info!("move_block: Moving within same parent: {}", parent_id_owned);
            let current_parent_id = parent_id_owned.as_str();
            let parent_child_map = children_map.get_or_init_array(txn, current_parent_id); // No error handling
            parent_child_map.move_to(txn, old_index, new_index);
            println_info!(
                "move_block: Moved node_id: {} within parent: {}",
                node_id_owned,
                parent_id_owned
            );
            return Ok(());
        }

        println_info!("move_block: Moving node_id: {} between parents", node_id_owned);
        let old_parent_child_map = children_map.get_or_init_array(
            txn,
            old_parent_id_owned.as_str()
        ); // No error handling
        old_parent_child_map.remove(txn, old_index);

        let new_parent_child_map = children_map.get_or_init_array(txn, parent_id_owned.as_str()); // No error handling
        new_parent_child_map.insert(txn, new_index, node_id_owned.as_str());
        println_info!("move_block: Finished for node_id: {}", node_id_owned);
        Ok(())
    }

    #[no_mangle]
    #[inline(never)]
    pub fn apply_updates_inner(&mut self, update: Vec<(String, Vec<u8>)>) -> Result<(), CustomRustError> {
        println_info!(
            "apply_updates: Starting with {} updates for doc_id: {}",
            update.len(),
            self.doc_id
        );

        // Create a new document to recreate from scratch
        let new_doc = Doc::new();

        // Apply all updates to the new document
        let result = Self::apply_updates_inner_actual(new_doc.clone(), self.doc_id.clone(), update);

        // Replace the current document with the newly created one
        self.doc = new_doc;

        // Return any failed updates
        result
    }

    pub fn apply_updates_inner_actual(
        doc: Doc,
        doc_id: String,
        update: Vec<(String, Vec<u8>)>
    ) -> Result<(), CustomRustError> {

        //Get only map of <Vec<u8>> from the update
        let updates_only = update
            .into_iter()
            .map(|(_, v)| v)
            .collect::<Vec<Vec<u8>>>();
        //Merge updates
        let merged_updates = merge_updates_v2(updates_only);
        //handle error case
        if merged_updates.is_err() {
            println_error!("Failed to merge updates: {}", merged_updates.err().unwrap());
            return Err(CustomRustError::new("Failed to merge updates"));
        }
        let merged_updates_res = merged_updates.unwrap();
        let mut txn = doc.transact_mut();

        //Decode the update
        match yrs::Update::decode_v2(&merged_updates_res) {
            Ok(decoded_update) => {
                info!("apply_updates: Applying update for doc_id: {}", doc_id);
                txn.apply_update(decoded_update);
            }
            Err(e) => {
                error!("Failed to decode update for doc_id: {}: {}", doc_id, e);
                return Err(CustomRustError::new("Failed to decode update"));
            }
        }

        println_info!("apply_updates: Finished for doc_id: {}", doc_id);
        Ok(())
    }

    #[no_mangle]
    #[inline(never)]
    fn delta_to_json<T: ReadTxn>(
        txn: &T,
        delta: Delta<Out>
    ) -> Result<Value, CustomRustError> {
        println_info!("delta_to_json: Converting delta");
        match delta {
            Delta::Inserted(text, attrs) => {
                println_info!("delta_to_json: Inserted text");
                let mut map = JsonMap::new();
                map.insert("insert".to_string(), Value::String(text.to_string(txn))); // No error handling
                if let Some(attributes) = attrs {
                    println_info!("delta_to_json: Adding attributes");
                    let attrs_json: JsonMap<String, Value> = attributes
                        .iter()
                        .map(|(k, v)| (k.to_string(), Self::any_to_json(v))) // No error handling
                        .collect();
                    map.insert("attributes".to_string(), Value::Object(attrs_json));
                }
                Ok(Value::Object(map))
            }
            Delta::Retain(len, attrs) => {
                println_info!("delta_to_json: Retain length: {}", len);
                let mut map = JsonMap::new();
                map.insert("retain".to_string(), Value::Number(len.into()));
                if let Some(attributes) = attrs {
                    println_info!("delta_to_json: Adding attributes to retain");
                    let attrs_json: JsonMap<String, Value> = attributes
                        .iter()
                        .map(|(k, v)| (k.to_string(), Self::any_to_json(v))) // No error handling
                        .collect();
                    map.insert("attributes".to_string(), Value::Object(attrs_json));
                }
                Ok(Value::Object(map))
            }
            Delta::Deleted(len) => {
                println_info!("delta_to_json: Deleted length: {}", len);
                let mut map = JsonMap::new();
                map.insert("delete".to_string(), Value::Number(len.into()));
                Ok(Value::Object(map))
            }
        }
    }

    #[no_mangle]
    #[inline(never)]
    fn deltas_to_json<T: ReadTxn>(
        txn: &T,
        deltas: Vec<Delta<Out>>
    ) -> Result<Value, CustomRustError> {
        println_info!("deltas_to_json: Converting {} deltas", deltas.len());
        let json_deltas: Result<Vec<Value>, CustomRustError> = deltas
            .into_iter()
            .map(|delta| Self::delta_to_json(txn, delta))
            .collect();
        println_info!(
            "deltas_to_json: Converted {} deltas",
            json_deltas.as_ref().map_or(0, |v| v.len())
        );
        json_deltas.map(|deltas| Value::Array(deltas))
    }

    #[no_mangle]
    #[inline(never)]
    fn any_to_json(any: &yrs::Any) -> Value {
        println_info!("any_to_json: Converting yrs::Any");
        match any {
            yrs::Any::Null => Value::Null,
            yrs::Any::Undefined => Value::Null,
            yrs::Any::Bool(b) => Value::Bool(*b),
            yrs::Any::Number(n) => {
                Value::Number(serde_json::Number::from_f64(*n).unwrap_or((0).into()))
            }
            yrs::Any::String(s) => Value::String(s.to_string()), // No error handling
            yrs::Any::Array(arr) => Value::Array(arr.iter().map(Self::any_to_json).collect()),
            yrs::Any::Map(map) =>
                Value::Object(
                    map
                        .iter()
                        .map(|(k, v)| (k.to_string(), Self::any_to_json(v))) // No error handling
                        .collect()
                ),
            yrs::Any::BigInt(i) => Value::Number((*i).into()),
            yrs::Any::Buffer(_) => Value::String("<buffer>".to_string()),
        }
    }

    #[no_mangle]
    #[inline(never)]
    fn apply_delta_to_text(
        txn: &mut yrs::TransactionMut,
        text: yrs::TextRef,
        new_delta: String,
        diff_deltas: &impl Fn(String, String) -> DartFnFuture<String>
    ) -> Result<(), CustomRustError> {
        // Get current text delta
        let current_delta = text.delta(txn);
        let current_delta_value = Self::deltas_to_json(txn, current_delta)?;
        let current_delta_str = serde_json::to_string(&current_delta_value).map_err(|e| {
            println_error!("Failed to serialize current delta: {}", e);
            CustomRustError::new("Failed to serialize current delta")
        })?;

        // Call diff_deltas and await the result
        println_info!("apply_delta_to_text: Computing delta diff");
        //Print current delta str and new_delta
        println_info!("apply_delta_to_text: current_delta_str: {}", current_delta_str);
        println_info!("apply_delta_to_text: new_delta: {}", new_delta);
        let new_delta_diff = futures::executor::block_on(diff_deltas(current_delta_str, new_delta));
        //Print new_delta_diff
        println_info!("apply_delta_to_text: new_delta_diff: {}", new_delta_diff);

        // Parse the delta diff into a Vec<HashMap<String, Value>>
        println_info!("apply_delta_to_text: Parsing delta diff from JSON");
        let parsed_delta: Vec<HashMap<String, Value>> = match serde_json::from_str(&new_delta_diff) {
            Ok(delta) => delta,
            Err(e) => {
                println_error!("Failed to parse delta diff JSON: {}", e);
                return Err(
                    CustomRustError::new(&format!("Failed to parse delta diff: {}", e))
                );
            }
        };

        // Apply the delta diff to the text
        println_info!(
            "apply_delta_to_text: Applying parsed delta with {} operations",
            parsed_delta.len()
        );
        if parsed_delta.is_empty() {
            println_info!("apply_delta_to_text: No changes to apply");
            return Ok(());
        }

        // Use the existing apply_delta_diff_to_text function to apply the diff
        match Self::apply_delta_diff_to_text(txn, text, &parsed_delta) {
            Ok(_) => {
                println_info!("apply_delta_to_text: Successfully applied delta diff");
                Ok(())
            }
            Err(e) => {
                println_error!("Failed to apply delta diff: {}", e);
                Err(e)
            }
        }
    }

    #[no_mangle]
    #[inline(never)]
    fn apply_delta_diff_to_text(
        txn: &mut yrs::TransactionMut,
        text: yrs::TextRef,
        delta: &[HashMap<String, Value>]
    ) -> Result<(), CustomRustError> {
        println_info!("apply_delta_to_text: Starting with {} operations", delta.len());

        let mut current_len = text.len(txn); // Current length in UTF-16 code units
        println_info!("apply_delta_to_text: Initial text length: {}", current_len);

        let mut cursor_pos = 0; // Track the cursor position as we process operations

        let deltas = delta
            .iter()
            .map(|d| {
                if d.contains_key(INSERT) {
                    println_info!("apply_delta_to_text: Processing insert");
                    let insert = d
                        .get(INSERT)
                        .and_then(|v| v.as_str())
                        .ok_or_else(|| {
                            println_error!(
                                "Invalid insert value: not a string - got {:?}",
                                d.get(INSERT)
                            );
                            CustomRustError::new("Insert value must be a string")
                        })?;

                    // Calculate the length of the inserted text in UTF-16 code units
                    let insert_len = insert.encode_utf16().count() as u32;
                    if insert_len == 0 {
                        println_info!("apply_delta_to_text: Skipping zero-length insert");
                        return Ok(Delta::Retain(0, None)); // No-op insert
                    }

                    let attributes = d.get(ATTRIBUTES).map(|a| {
                        println_info!("apply_delta_to_text: Processing attributes for insert");
                        Box::new(
                            a
                                .as_object()
                                .unwrap_or(&JsonMap::new())
                                .iter()
                                .map(|(k, v)| {
                                    (Arc::from(k.as_str()), Self::json_value_to_yrs_any(v))
                                })
                                .collect::<HashMap<Arc<str>, yrs::Any>>()
                        ) as Box<_>
                    });

                    current_len += insert_len; // Update text length
                    cursor_pos += insert_len; // Move cursor forward by the inserted length
                    println_info!(
                        "apply_delta_to_text: After insert '{}', new text length: {}, cursor_pos: {}",
                        insert,
                        current_len,
                        cursor_pos
                    );
                    Ok(Delta::Inserted(insert.to_string(), attributes))
                } else if d.contains_key(RETAIN) {
                    println_info!("apply_delta_to_text: Processing retain");
                    let retain = d
                        .get(RETAIN)
                        .and_then(|v| v.as_u64())
                        .ok_or_else(|| {
                            println_error!(
                                "Invalid retain value: not a number - got {:?}",
                                d.get(RETAIN)
                            );
                            CustomRustError::new("Retain value must be a number")
                        })? as u32;

                    let remaining_len = current_len.saturating_sub(cursor_pos);
                    if retain > remaining_len {
                        println_error!(
                            "Retain {} exceeds remaining text length {} (cursor_pos: {}, total_len: {})",
                            retain,
                            remaining_len,
                            cursor_pos,
                            current_len
                        );
                        return Err(
                            CustomRustError::new(
                                "Retain operation exceeds remaining text length"
                            )
                        );
                    }

                    if retain == 0 {
                        println_info!("apply_delta_to_text: Skipping zero-length retain");
                        return Ok(Delta::Retain(0, None)); // No-op retain
                    }

                    cursor_pos += retain; // Move cursor forward
                    println_info!("apply_delta_to_text: After retain, cursor_pos: {}", cursor_pos);

                    let attributes = d.get(ATTRIBUTES).map(|a| {
                        println_info!("apply_delta_to_text: Processing attributes for retain");
                        Box::new(
                            a
                                .as_object()
                                .unwrap_or(&JsonMap::new())
                                .iter()
                                .map(|(k, v)| {
                                    (Arc::from(k.as_str()), Self::json_value_to_yrs_any(v))
                                })
                                .collect::<HashMap<Arc<str>, yrs::Any>>()
                        ) as Box<_>
                    });
                    Ok(Delta::Retain(retain, attributes))
                } else if d.contains_key(DELETE) {
                    println_info!("apply_delta_to_text: Processing delete");
                    let delete = d
                        .get(DELETE)
                        .and_then(|v| v.as_u64())
                        .ok_or_else(|| {
                            println_error!(
                                "Invalid delete value: not a number - got {:?}",
                                d.get(DELETE)
                            );
                            CustomRustError::new("Delete value must be a number")
                        })? as u32;

                    if delete > current_len {
                        println_error!(
                            "Delete {} exceeds current text length {}",
                            delete,
                            current_len
                        );
                        return Err(
                            CustomRustError::new("Delete operation exceeds text length")
                        );
                    }

                    if delete == 0 {
                        println_info!("apply_delta_to_text: Skipping zero-length delete");
                        return Ok(Delta::Deleted(0)); // No-op delete
                    }

                    current_len -= delete; // Update text length
                    cursor_pos = cursor_pos.saturating_sub(delete); // Adjust cursor if it was beyond the deleted portion
                    println_info!(
                        "apply_delta_to_text: After delete, new text length: {}, cursor_pos: {}",
                        current_len,
                        cursor_pos
                    );
                    Ok(Delta::Deleted(delete))
                } else {
                    println_error!(
                        "apply_delta_to_text: Invalid delta encountered - delta: {:?}",
                        d
                    );
                    Err(CustomRustError::new("Invalid delta operation"))
                }
            })
            .collect::<Result<Vec<_>, CustomRustError>>()?;

        // Final validation before applying delta
        if cursor_pos > current_len {
            println_error!(
                "Cursor position {} exceeds final text length {}",
                cursor_pos,
                current_len
            );
            return Err(CustomRustError::new("Cursor position exceeds text length"));
        }

        println_info!("apply_delta_to_text: Applying {} deltas", deltas.len());
        text.apply_delta(txn, deltas);

        Ok(())
    }

    /// Create a new function that will be preceding step before apply_delta_to_text
    /// get_delta_diff(new_whole_delta, textRef) that will
    /// Get the current text from the textRef as a sequence of deltas, or maybe it is
    ///  going to be just Delta(Insert:xxxxx). I am not sure. And stores that in current_delta.
    /// Diffes the new_whole_delta with the current_delta. And then calls [apply_delta_to_text]
    /// with the diffed delta n the textRef.
    /// This would be used inside apply_whole_delta_to_text() function. That will:
    /// 1. Get delta_diff
    /// 2. Apply the diffed delta to the textRef
    ///

    #[no_mangle]
    #[inline(never)]
    fn json_value_to_yrs_any(val: &Value) -> yrs::Any {
        println_info!("json_value_to_yrs_any: Converting JSON value");
        match val {
            Value::Null => yrs::Any::Null,
            Value::Bool(b) => yrs::Any::Bool(*b),
            Value::Number(n) => {
                if let Some(i) = n.as_i64() {
                    yrs::Any::Number(i as f64)
                } else if let Some(f) = n.as_f64() {
                    yrs::Any::Number(f)
                } else {
                    yrs::Any::Undefined
                }
            }
            Value::String(s) => yrs::Any::String(Arc::from(s.as_str())),
            Value::Array(arr) =>
                yrs::Any::Array(
                    Arc::from(arr.iter().map(Self::json_value_to_yrs_any).collect::<Vec<_>>())
                ),
            Value::Object(obj) =>
                yrs::Any::Map(
                    Arc::from(
                        obj
                            .iter()
                            .map(|(k, v)| (k.clone(), Self::json_value_to_yrs_any(v)))
                            .collect::<HashMap<_, _>>()
                    )
                ),
        }
    }

    #[no_mangle]
    #[inline(never)]
    pub fn get_document_state(&self) -> Result<DocumentState, CustomRustError> {
        println_info!("get_document_state: Starting for doc_id: {}", self.doc_id);

        // let mut doc_guard = self.doc.lock().map_err(|poisoned| {
        //     println_error!(
        //         "Failed to lock mutex for doc_id: {} due to poisoning in get_document_state",
        //         self.doc_id
        //     );
        //     ConcurrentAccessError::new("Mutex poisoned, concurrent access detected")
        // })?;
        let doc_guard = self.doc.clone();

        let result = (|| {
            let root = doc_guard.get_or_insert_map(ROOT_ID); // No error handling
            let mut txn = doc_guard.transact_mut();

            println_info!("get_document_state: Extracting blocks for doc_id: {}", self.doc_id);
            let blocks_map = root.get_or_init_map(&mut txn, BLOCKS); // No error handling
            let mut blocks = HashMap::new();
            let block_keys: Vec<String> = blocks_map
                .keys(&txn)
                .map(|k| k.to_string())
                .collect(); // No error handling
            println_info!("get_document_state: Found {} block keys", block_keys.len());

            for key in block_keys {
                println_info!("get_document_state: Processing block key: {}", key);
                let id = key.clone().to_string(); // No error handling
                let block_map = blocks_map.get_or_init_map(&mut txn, key.clone()); // No error handling

                println_info!("get_document_state: Accessing text for block_id: {}", id);

                let delta_string: Option<String> = {
                    if let Some(text) = block_map.get_text(&mut txn, TEXT) {
                        // No error handling

                        let deltas = text.delta(&txn);
                        println_info!("get_document_state: Converting deltas to JSON for block_id: {}", id);
                        match Self::deltas_to_json(&txn, deltas) {
                            Ok(json_deltas) =>
                                match serde_json::to_string(&json_deltas) {
                                    Ok(s) => Some(s),
                                    Err(e) => {
                                        println_error!(
                                            "Failed to serialize deltas for block_id: {}: {}",
                                            id,
                                            e
                                        );
                                        return Err(
                                            CustomRustError::new(
                                                "Failed to serialize deltas to JSON"
                                            )
                                        );
                                    }
                                }
                            Err(e) => {
                                println_error!(
                                    "Failed to convert deltas to JSON for block_id: {}: {}",
                                    id,
                                    e
                                );
                                return Err(e);
                            }
                        }
                    } else {
                        None
                    }
                };

                let mut block_data = HashMap::new();
                for (k, v) in block_map.iter(&txn) {
                    block_data.insert(k.to_string(), v); // No error handling
                }

                let attributes_map = block_map.get_or_init_map(&mut txn, ATTRIBUTES); // No error handling
                let mut attributes_result = HashMap::new();
                for (k, v) in attributes_map.iter(&txn) {
                    attributes_result.insert(k.to_string(), v.to_string(&txn)); // No error handling
                }

                if !block_data.is_empty() {
                    println_info!("get_document_state: Building BlockDoc for block_id: {}", id);
                    let block = BlockDoc {
                        id: block_data
                            .get(ID)
                            .and_then(|v| {
                                if let yrs::Out::Any(yrs::Any::String(ref s)) = v {
                                    Some(s.to_string()) // No error handling
                                } else {
                                    None
                                }
                            })
                            .unwrap_or_else(|| id.clone()),
                        ty: block_data
                            .get(TYPE)
                            .and_then(|v| {
                                if let yrs::Out::Any(yrs::Any::String(ref s)) = v {
                                    Some(s.to_string()) // No error handling
                                } else {
                                    None
                                }
                            })
                            .unwrap_or_default(),
                        attributes: attributes_result,
                        delta: delta_string,
                        parent_id: block_data.get(PARENT_ID).and_then(|v| {
                            if let yrs::Out::Any(yrs::Any::String(ref s)) = v {
                                Some(s.to_string()) // No error handling
                            } else {
                                None
                            }
                        }),
                        prev_id: block_data.get(PREV_ID).and_then(|v| {
                            if let yrs::Out::Any(yrs::Any::String(ref s)) = v {
                                Some(s.to_string()) // No error handling
                            } else {
                                None
                            }
                        }),
                        old_parent_id: None,
                    };
                    blocks.insert(id, block);
                }
            }

            println_info!(
                "get_document_state: Extracting children_map for doc_id: {}",
                self.doc_id
            );
            let children_map = root.get_or_init_map(&mut txn, CHILDREN_MAP); // No error handling

            let mut children = HashMap::new();
            for (parent_id, value) in children_map.iter(&txn) {
                println_info!(
                    "get_document_state: Processing parent_id: {}",
                    parent_id.to_string()
                ); // No error handling
                match value {
                    yrs::Out::YArray(array) => {
                        let child_ids: Vec<String> = array
                            .iter(&txn)
                            .map(|item| {
                                if let yrs::Out::Any(yrs::Any::String(s)) = item {
                                    s.to_string() // No error handling
                                } else {
                                    println_error!(
                                        "Unexpected item type in children array for parent_id: {}",
                                        parent_id.to_string() // No error handling
                                    );
                                    String::new() // Default to empty string instead of returning error
                                }
                            })
                            .collect();
                        children.insert(parent_id.to_string(), child_ids); // No error handling
                    }
                    _ => {
                        println_error!(
                            "Expected YArray for parent_id: {}, found different type",
                            parent_id.to_string() // No error handling
                        );
                        return Err(CustomRustError::new("Unexpected type in children map"));
                    }
                }
            }

            let sorted_children_map = Self::sort_blocks_by_chain(&children, &blocks);

            println_info!("get_document_state: Finished for doc_id: {}", self.doc_id);
            Ok(DocumentState {
                blocks,
                children_map: sorted_children_map,
                doc_id: self.doc_id.clone(),
            })
        })();

        // The lock is automatically released here when doc_guard goes out of scope
        result
    }

    #[no_mangle]
    #[inline(never)]
    #[frb]
    pub fn merge_updates_inner(
        &self,
        updates: Vec<Vec<u8>>
    ) -> Result<Vec<u8>, CustomRustError> {
        println_info!("DocumentService::merge_updates: Merging {} updates", updates.len());
        let merged_update = merge_updates_v2(updates);
        println_info!("DocumentService::merge_updates: Merged update: {:?}", merged_update);

        //Check if merged_update is succesufll otherwise return error
        return match merged_update {
            Ok(update) => Ok(update),
            Err(e) => {
                println_error!("DocumentService::merge_updates: Failed to merge updates: {}", e);
                return Err(CustomRustError::new("Failed to merge updates"));
            }
        };
    }


    pub fn sort_blocks_by_chain(
        children_map: &HashMap<String, Vec<String>>,
        blocks: &HashMap<String, BlockDoc>
    ) -> HashMap<String, Vec<String>> {
        let mut sorted_children = HashMap::new();

        for (parent_id, child_ids) in children_map {
            // Create a map of blocks by ID for quick access
            let blocks_by_id: HashMap<String, &BlockDoc> = child_ids
                .iter()
                .filter_map(|id| blocks.get(id).map(|block| (id.clone(), block)))
                .collect();
                
            // Group blocks by device - this will help us maintain device grouping
            let mut blocks_by_device: HashMap<String, Vec<String>> = HashMap::new();
            
            for (id, block) in &blocks_by_id {
                let device_id = block.attributes
                    .get("device")
                    .unwrap_or(&"unknown".to_string())
                    .clone();
                    
                blocks_by_device.entry(device_id).or_default().push(id.clone());
            }
                
            // Build a multi-map from prevId to blocks
            let mut next_blocks: HashMap<String, Vec<String>> = HashMap::new();
            let mut has_prev = std::collections::HashSet::new();
            
            for (id, block) in &blocks_by_id {
                if let Some(prev) = &block.prev_id {
                    next_blocks.entry(prev.clone()).or_default().push(id.clone());
                    has_prev.insert(id.clone());
                }
            }
            
            // Find all root blocks (those without prev_id)
            let mut roots_by_device: HashMap<String, Vec<String>> = HashMap::new();
            
            for (device, device_blocks) in &blocks_by_device {
                let device_roots: Vec<String> = device_blocks
                    .iter()
                    .filter(|id| !has_prev.contains(*id))
                    .cloned()
                    .collect();
                    
                if !device_roots.is_empty() {
                    roots_by_device.insert(device.clone(), device_roots);
                }
            }
            
            // Process each device's chain separately to maintain grouping
            let mut sorted_ids = Vec::new();
            let mut visited = std::collections::HashSet::new();
            
            // Process devices in order (for consistent results)
            let mut devices: Vec<String> = blocks_by_device.keys().cloned().collect();
            devices.sort();
            
            for device in devices {
                if let Some(roots) = roots_by_device.get(&device) {
                    let mut device_roots = roots.clone();
                    
                    // Sort roots within each device by timestamp
                    device_roots.sort_by(|a, b| {
                        let block_a = blocks_by_id.get(a).unwrap();
                        let block_b = blocks_by_id.get(b).unwrap();
                        
                        let binding = "".to_string();
                        let time_a = block_a.attributes.get("timestamp").unwrap_or(&binding);
                        let time_b = block_b.attributes.get("timestamp").unwrap_or(&binding);
                        time_a.cmp(time_b)
                    });
                    
                    // Process each root from this device and its chain
                    for root in device_roots {
                        if visited.contains(&root) {
                            continue;
                        }
                        
                        let mut stack = vec![root.clone()];
                        
                        // Process this chain completely
                        while let Some(block_id) = stack.pop() {
                            if visited.contains(&block_id) {
                                continue;
                            }
                            
                            sorted_ids.push(block_id.clone());
                            visited.insert(block_id.clone());
                            
                            if let Some(next_block_ids) = next_blocks.get(&block_id) {
                                // Sort next blocks by timestamp if there are multiple
                                let mut next_blocks_sorted = next_block_ids.clone();
                                next_blocks_sorted.sort_by(|a, b| {
                                    let block_a = blocks_by_id.get(a).unwrap();
                                    let block_b = blocks_by_id.get(b).unwrap();
                                    
                                    let binding = "".to_string();
                                    let time_a = block_a.attributes.get("timestamp").unwrap_or(&binding);
                                    let time_b = block_b.attributes.get("timestamp").unwrap_or(&binding);
                                    time_a.cmp(time_b)
                                });
                                
                                // Add to stack in reverse order for depth-first traversal
                                for next_id in next_blocks_sorted.into_iter().rev() {
                                    if !visited.contains(&next_id) {
                                        stack.push(next_id);
                                    }
                                }
                            }
                        }
                    }
                    
                    // Add any remaining blocks from this device that weren't in chains
                    if let Some(device_blocks) = blocks_by_device.get(&device) {
                        for block_id in device_blocks {
                            if !visited.contains(block_id) {
                                sorted_ids.push(block_id.clone());
                                visited.insert(block_id.clone());
                            }
                        }
                    }
                }
            }
            
            // Add any remaining blocks that weren't processed
            for block_id in child_ids {
                if !visited.contains(block_id) {
                    sorted_ids.push(block_id.clone());
                    visited.insert(block_id.clone());
                }
            }
            
            sorted_children.insert(parent_id.clone(), sorted_ids);
        }
        
        sorted_children
    }
}
