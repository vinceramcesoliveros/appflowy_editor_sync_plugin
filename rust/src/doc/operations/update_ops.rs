use yrs::{Doc, Map, ReadTxn, StateVector, Update, merge_updates_v2};
use std::collections::HashMap;

use crate::doc::document_types::{BlockDoc, CustomRustError, DocumentState, FailedToDecodeUpdates};
use crate::doc::error::DocError;
use crate::doc::utils::sorting::ChainSorting;
use crate::doc::utils::logging::{log_info, log_error};
use crate::doc::document_service::{BLOCKS, CHILDREN_MAP, ID, TYPE, TEXT, ATTRIBUTES, PARENT_ID, PREV_ID, ROOT_ID};

pub struct UpdateOperations;

impl UpdateOperations {
    /// Apply a list of updates to a document
    pub fn apply_updates(
        doc: Doc,
        doc_id: &str,
        updates: Vec<(String, Vec<u8>)>
    ) -> Result<FailedToDecodeUpdates, CustomRustError> {
        log_info!("apply_updates: Starting with {} updates for doc_id: {}", updates.len(), doc_id);

        // Extract just the binary updates
        let updates_only: Vec<Vec<u8>> = updates.into_iter().map(|(_, v)| v).collect();
        
        // Merge all the updates together
        let merged_update = merge_updates_v2(updates_only)
            .map_err(|e| DocError::MergeError(format!("Failed to merge updates: {}", e)))?;
        
        // Apply the merged update to the document
        let mut txn = doc.transact_mut();
        
        let result = match Update::decode_v2(&merged_update) {
            Ok(decoded_update) => {
                log_info!("apply_updates: Applying update for doc_id: {}", doc_id);
                txn.apply_update(decoded_update);
                FailedToDecodeUpdates { failed_ids: Vec::new() }
            },
            Err(e) => {
                log_error!("Failed to decode update for doc_id: {}: {}", doc_id, e);
                return Err(DocError::UpdateDecodingFailed(format!("Failed to decode update: {}", e)).into());
            }
        };

        log_info!("apply_updates: Finished for doc_id: {}", doc_id);
        Ok(result)
    }

    /// Extract the current document state
    pub fn extract_document_state<T: ReadTxn>(
        txn: &T,
        root: yrs::MapRef,
        doc_id: &str
    ) -> Result<DocumentState, CustomRustError> {
        log_info!("extract_document_state: Starting for doc_id: {}", doc_id);

        // Extract blocks
        let blocks_map = match root.get(txn, BLOCKS) {
            Some(yrs::Out::YMap(map)) => map,
            _ => return Err(DocError::StateError("Blocks map not found in document".into()).into()),
        };

        let mut blocks = HashMap::new();
        let block_keys: Vec<String> = blocks_map.keys(txn).map(|k| k.to_string()).collect();
        
        log_info!("extract_document_state: Processing {} blocks", block_keys.len());
        for key in block_keys {
            let id = key.clone();
            if let Some(block) = Self::extract_block(txn, &blocks_map, &id)? {
                blocks.insert(id, block);
            }
        }

        // Extract children map
        let children_map = match root.get(txn, CHILDREN_MAP) {
            Some(yrs::Out::YMap(map)) => map,
            _ => return Err(DocError::StateError("Children map not found in document".into()).into()),
        };

        let mut children_relationships = HashMap::new();
        for parent_id in children_map.keys(txn) {
            let parent_id_str = parent_id.to_string();
            
            if let Some(yrs::Out::YArray(array)) = children_map.get(txn, &parent_id) {
                let child_ids: Vec<String> = array.iter(txn)
                    .map(|item| {
                        if let yrs::Out::Any(yrs::Any::String(s)) = item {
                            s.to_string()
                        } else {
                            String::new() // Skip invalid entries
                        }
                    })
                    .filter(|s| !s.is_empty())
                    .collect();
                
                children_relationships.insert(parent_id_str, child_ids);
            }
        }

        // Sort blocks by chain if needed
        let sorted_children = ChainSorting::sort_blocks_by_chain(&children_relationships, &blocks);

        log_info!("extract_document_state: Extracted {} blocks and {} parent-child relationships", 
                blocks.len(), sorted_children.len());
        
        // Build the complete document state
        Ok(DocumentState {
            blocks,
            children_map: sorted_children,
            doc_id: doc_id.to_string(),
        })
    }

    /// Extract a single block from the document
    fn extract_block<T: ReadTxn>(
        txn: &T, 
        blocks_map: &yrs::MapRef, 
        id: &str
    ) -> Result<Option<BlockDoc>, CustomRustError> {
        if let Some(yrs::Out::YMap(block_map)) = blocks_map.get(txn, id) {
            // Extract text content if present
            let delta_string = if let Some(yrs::Out::YText(text)) = block_map.get(txn, TEXT) {
                use crate::doc::operations::delta_ops::DeltaOperations;
                
                let deltas = text.delta(txn);
                match DeltaOperations::deltas_to_json(txn, deltas) {
                    Ok(json_deltas) => {
                        match serde_json::to_string(&json_deltas) {
                            Ok(s) => Some(s),
                            Err(e) => {
                                log_error!("Failed to serialize deltas for block_id {}: {}", id, e);
                                return Err(DocError::StateEncodingFailed(
                                    format!("Failed to serialize deltas: {}", e)
                                ).into());
                            }
                        }
                    },
                    Err(e) => return Err(e),
                }
            } else {
                None
            };

            // Extract attributes
            let attributes_map = if let Some(yrs::Out::YMap(attrs)) = block_map.get(txn, ATTRIBUTES) {
                let mut result = HashMap::new();
                for key in attrs.keys(txn) {
                    if let Some(out) = attrs.get(txn, &key) {
                        result.insert(key.to_string(), out.to_string(txn));
                    }
                }
                result
            } else {
                HashMap::new()
            };

            // Build the block object
            let block = BlockDoc {
                id: match block_map.get(txn, ID) {
                    Some(out) => out.to_string(txn),
                    None => id.to_string(),
                },
                ty: block_map.get(txn, TYPE)
                    .map(|out| out.to_string(txn))
                    .unwrap_or_default(),
                attributes: attributes_map,
                delta: delta_string,
                parent_id: block_map.get(txn, PARENT_ID)
                    .map(|out| out.to_string(txn)),
                prev_id: block_map.get(txn, PREV_ID)
                    .map(|out| out.to_string(txn)),
                old_parent_id: None,
            };

            Ok(Some(block))
        } else {
            Ok(None)
        }
    }
    
    /// Merge multiple document updates into one
    pub fn merge_updates(updates: Vec<Vec<u8>>) -> Result<Vec<u8>, CustomRustError> {
        log_info!("merge_updates: Merging {} updates", updates.len());
        
        merge_updates_v2(updates)
            .map_err(|e| DocError::MergeError(format!("Failed to merge updates: {}", e)).into())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_merge_updates_empty() {
        let result = UpdateOperations::merge_updates(vec![]);
        assert!(result.is_ok());
        assert!(!result.unwrap().is_empty());
    }
    
    #[test]
    fn test_merge_updates_single() {
        // Create a document and get an update
        let doc = Doc::new();
        let mut txn = doc.transact_mut();
        let map = txn.get_or_create_map("test");
        map.insert(&mut txn, "key", "value");
        let update = txn.encode_update_v2();
        
        let result = UpdateOperations::merge_updates(vec![update.clone()]);
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), update);
    }
}