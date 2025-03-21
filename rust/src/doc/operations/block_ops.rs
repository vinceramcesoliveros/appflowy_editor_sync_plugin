use flutter_rust_bridge::DartFnFuture;
use log::info;
use std::sync::Arc;
use yrs::{Array, ArrayRef, Map, MapPrelim, MapRef, ReadTxn, TextRef, TransactionMut};

use crate::doc::constants::{ATTRIBUTES, DEFAULT_PARENT, ID, PARENT_ID, PREV_ID, TEXT, TYPE};
use crate::doc::document_types::{BlockActionDoc, CustomRustError};
use crate::doc::error::DocError;
use crate::doc::operations::delta_ops::DeltaOperations;
use crate::doc::utils::util::MapExt;

use crate::{log_info, log_error};

pub struct BlockOperations;

impl BlockOperations {
    pub fn insert_node(
        txn: &mut TransactionMut,
        blocks_map: MapRef,
        action: BlockActionDoc,
        children_map: MapRef,
        diff_deltas: &impl Fn(String, String) -> DartFnFuture<String>
    ) -> Result<MapRef, CustomRustError> {
        let block_id = action.block.id.clone();
        log_info!("insert_node: Starting for block_id: {}", block_id);
        
        let parent_id = action.block.parent_id
            .unwrap_or_else(|| DEFAULT_PARENT.to_owned());
        
        // Create the node and set its basic properties
        let node_ref = blocks_map.get_or_init_map(txn, block_id.clone());
        node_ref.insert(txn, Arc::from(ID), block_id.clone());
        node_ref.insert(txn, Arc::from(TYPE), action.block.ty.clone());
        
        if parent_id != DEFAULT_PARENT {
            node_ref.insert(txn, Arc::from(PARENT_ID), parent_id.clone());
        }
        
        // Set attributes
        let mut attr_map = MapPrelim::default();
        for (k, v) in action.block.attributes {
            attr_map.insert(k.into(), v.into());
        }
        node_ref.insert(txn, Arc::from(ATTRIBUTES), attr_map);
        
        // Apply delta if present
        if let Some(delta_json) = action.block.delta {
            let text = node_ref.get_or_init_text(txn, TEXT);
            DeltaOperations::apply_delta_to_text(txn, text, delta_json, diff_deltas)?;
        }
        
        // Handle the prev_id chain
        Self::handle_prev_id_chain(txn, blocks_map.clone(), &block_id, action.block.prev_id)?;
        
        // Add to parent's children list
        if parent_id != DEFAULT_PARENT {
            let parent_children = children_map.get_or_init_array(txn, parent_id.clone());
            let node_index = *action.path.last().unwrap_or(&0);
            
            if node_index > parent_children.len(txn) {
                parent_children.push_back(txn, block_id.clone());
            } else {
                parent_children.insert(txn, node_index, block_id.clone());
            }
        }
        
        // Initialize an empty children array for this block
        children_map.get_or_init_array(txn, block_id.clone());
        
        log_info!("insert_node: Finished for block_id: {}", block_id);
        Ok(node_ref)
    }

    pub fn update_node(
        txn: &mut TransactionMut,
        blocks_map: MapRef,
        action: BlockActionDoc,
        diff_deltas: &impl Fn(String, String) -> DartFnFuture<String>
    ) -> Result<(), CustomRustError> {
        let block_id = action.block.id.clone();
        log_info!("update_node: Updating block_id: {}", block_id);
        
        let node = blocks_map.get_or_init_map(txn, block_id.clone());
        
        // Update attributes if any
        if !action.block.attributes.is_empty() {
            let data = node.get_or_init_map(txn, ATTRIBUTES);
            for (k, v) in action.block.attributes {
                data.insert(txn, k, v);
            }
        }
        
        // Apply delta if present
        if let Some(delta_json) = action.block.delta {
            let text = node.get_or_init_text(txn, TEXT);
            DeltaOperations::apply_delta_to_text(txn, text, delta_json, diff_deltas)?;
        }
        
        log_info!("update_node: Updated block_id: {}", block_id);
        Ok(())
    }

    pub fn delete_node(
        txn: &mut TransactionMut,
        blocks_map: MapRef,
        children_map: MapRef,
        block_id: &str,
        parent_id: &str
    ) -> Result<(), CustomRustError> {
        log_info!("delete_node: Starting for block_id: {}", block_id);
        
        // Update the prev_id chain
        Self::remove_block_from_prev_id_chain(txn, blocks_map.clone(), block_id)?;
        
        // Remove from parent's children array
        if parent_id != DEFAULT_PARENT {
            let parent_children = children_map.get_or_init_array(txn, parent_id);
            let parent_children_clone = parent_children.clone();
            
            if let Some(index) = Self::find_block_index(txn, parent_children, block_id) {
                parent_children_clone.remove(txn, index);
            }
        }
        
        // Delete all child blocks recursively
        let children = children_map.get_or_init_array(txn, block_id);
        let child_ids: Vec<String> = children.iter(txn)
            .map(|child| child.to_string(txn))
            .collect();
            
        for child_id in child_ids {
            Self::delete_node(
                txn,
                blocks_map.clone(),
                children_map.clone(),
                &child_id,
                block_id
            )?;
        }
        
        // Remove the block from storage
        blocks_map.remove(txn, block_id)
            .ok_or_else(|| DocError::BlockNotFound(format!("Block {} not found in blocks map", block_id)))?;
            
        children_map.remove(txn, block_id)
            .ok_or_else(|| DocError::BlockNotFound(format!("Block {} not found in children map", block_id)))?;
            
        log_info!("delete_node: Successfully deleted block_id: {}", block_id);
        Ok(())
    }

    pub fn move_block(
        txn: &mut TransactionMut,
        children_map: MapRef,
        blocks_map: MapRef,
        old_path: &[u32],
        new_path: &[u32],
        parent_id: &str,
        old_parent_id: &str,
        block_id: &str,
        prev_id: Option<String>
    ) -> Result<(), CustomRustError> {
        log_info!(
            "move_block: Moving block_id: {} from parent: {} to parent: {}", 
            block_id, old_parent_id, parent_id
        );
        
        // Update the prev_id chain
        Self::remove_block_from_prev_id_chain(txn, blocks_map.clone(), block_id)?;
        
        // Set the new prev_id or remove it
        let node = blocks_map.get_or_init_map(txn, block_id);
        if let Some(prev_id) = prev_id {
            node.insert(txn, Arc::from(PREV_ID), prev_id);
        } else {
            node.remove(txn, &Arc::from(PREV_ID));
        }
        
        let old_index = *old_path.last()
            .ok_or_else(|| DocError::InvalidOperation("Empty old path".into()))?;
        let new_index = *new_path.last()
            .ok_or_else(|| DocError::InvalidOperation("Empty new path".into()))?;
        
        // If moving within the same parent, use the move_to operation
        if parent_id == old_parent_id {
            let parent_children = children_map.get_or_init_array(txn, parent_id);
            parent_children.move_to(txn, old_index, new_index);
            log_info!("move_block: Moved block within same parent");
            return Ok(());
        }
        
        // Otherwise, remove from old parent and add to new parent
        let old_parent_children = children_map.get_or_init_array(txn, old_parent_id);
        old_parent_children.remove(txn, old_index);
        
        let new_parent_children = children_map.get_or_init_array(txn, parent_id);
        new_parent_children.insert(txn, new_index, block_id);
        
        log_info!("move_block: Moved block between parents");
        Ok(())
    }

    // Helper methods
    fn find_block_index(txn: &TransactionMut, array: ArrayRef, block_id: &str) -> Option<u32> {
        array.iter(txn)
            .position(|x| x.to_string(txn) == block_id)
            .map(|pos| pos as u32)
    }

    fn find_block_referencing_prev_id(
        txn: &TransactionMut,
        blocks_map: MapRef,
        prev_id_value: &str
    ) -> Option<String> {
        blocks_map.iter(txn)
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

    fn handle_prev_id_chain(
        txn: &mut TransactionMut,
        blocks_map: MapRef,
        block_id: &str,
        prev_id: Option<String>
    ) -> Result<(), CustomRustError> {
        if let Some(prev_id) = prev_id {
            // If another block has this prev_id, update its prev_id to point to this block
            if let Some(other_block_id) = Self::find_block_referencing_prev_id(
                txn, blocks_map.clone(), &prev_id
            ) {
                let other_block = blocks_map.get_or_init_map(txn, other_block_id.clone());
                other_block.insert(txn, Arc::from(PREV_ID), block_id.to_string());
            }
            
            // Set the prev_id for this block
            let block = blocks_map.get_or_init_map(txn, block_id.to_string());
            block.insert(txn, Arc::from(PREV_ID), prev_id);
        }
        
        Ok(())
    }

    fn remove_block_from_prev_id_chain(
        txn: &mut TransactionMut,
        blocks_map: MapRef,
        block_id: &str
    ) -> Result<(), CustomRustError> {
        // Get the block's prev_id if it exists
        let block_data = blocks_map.get_or_init_map(txn, block_id);
        let prev_id = block_data.get(txn, PREV_ID).and_then(|out| {
            if let yrs::Out::Any(yrs::Any::String(s)) = out { 
                Some(s.to_string()) 
            } else { 
                None 
            }
        });
        
        // Find any block that references this block as its prev_id
        if let Some(next_id) = Self::find_block_referencing_prev_id(txn, blocks_map.clone(), block_id) {
            let next_block = blocks_map.get_or_init_map(txn, next_id);
            
            // Update the next block to point to this block's prev_id
            if let Some(prev_id) = prev_id {
                next_block.insert(txn, Arc::from(PREV_ID), prev_id);
            } else {
                next_block.remove(txn, &Arc::from(PREV_ID));
            }
        }
        
        Ok(())
    }
}