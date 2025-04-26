use std::collections::HashMap;

use crate::{doc::document_types::BlockDoc, log_info};

pub struct ChainSorting;

impl ChainSorting {
    pub fn sort_blocks_by_chain(
        blocks: &HashMap<String, BlockDoc>
    ) -> HashMap<String, Vec<String>> {
        log_info!("====== STARTING BLOCK SORTING ======");
        
        // First, group blocks by parent ID
        let mut blocks_by_parent: HashMap<String, Vec<String>> = HashMap::new();
        
        // Add each block to its parent's group
        for (block_id, block) in blocks {
            let parent_id = block.parent_id.clone().unwrap_or_else(|| "root".to_string());
            blocks_by_parent.entry(parent_id.clone()).or_default().push(block_id.clone());
            log_info!("Block {} assigned to parent {}", block_id, parent_id);
        }

        //Print blocks by parent map
        for (parent_id, child_ids) in &blocks_by_parent {
            log_info!("Parent {} has {} children: {:?}", parent_id, child_ids.len(), child_ids);
        }
        
        log_info!("Grouped {} blocks by parent", blocks.len());
        
        let mut sorted_children = HashMap::new();

        for (parent_id, child_ids) in blocks_by_parent {
            log_info!("\n----- Sorting children of parent: {} -----", parent_id);
            log_info!("Parent has {} children to sort", child_ids.len());
            
            // Create a map of blocks by ID for quick access
            let blocks_by_id: HashMap<String, &BlockDoc> = child_ids
                .iter()
                .filter_map(|id| {
                    let block = blocks.get(id);
                    if block.is_none() {
                        log_info!("WARNING: Block with ID {} not found in blocks map", id);
                    }
                    block.map(|b| (id.clone(), b))
                })
                .collect();
                
            log_info!("Mapped {} valid blocks by ID", blocks_by_id.len());
                
            // Group blocks by device - this will help us maintain device grouping
            let mut blocks_by_device: HashMap<String, Vec<String>> = HashMap::new();
            
            for (id, block) in &blocks_by_id {
                let device_id = block.attributes
                    .get("device")
                    .unwrap_or(&"unknown".to_string())
                    .clone();
                
                blocks_by_device.entry(device_id.clone()).or_default().push(id.clone());
                log_info!("Block {} assigned to device {}", id, device_id);
            }
            
            log_info!("Grouped blocks into {} devices", blocks_by_device.len());
            for (device, blocks) in &blocks_by_device {
                log_info!("  - Device {} has {} blocks", device, blocks.len());
            }
                
            // Build a multi-map from prevId to blocks
            let mut next_blocks: HashMap<String, Vec<String>> = HashMap::new();
            let mut has_prev = std::collections::HashSet::new();
            
            for (id, block) in &blocks_by_id {
                if let Some(prev) = &block.prev_id {
                    next_blocks.entry(prev.clone()).or_default().push(id.clone());
                    has_prev.insert(id.clone());
                    log_info!("Block {} has prev_id {}", id, prev);
                } else {
                    log_info!("Block {} has no prev_id", id);
                }
            }
            
            log_info!("Built prev->next map with {} entries", next_blocks.len());
            for (prev, nexts) in &next_blocks {
                log_info!("  - {} has {} next blocks: {:?}", prev, nexts.len(), nexts);
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
                    roots_by_device.insert(device.clone(), device_roots.clone());
                    log_info!("Device {} has {} root blocks: {:?}", device, device_roots.len(), device_roots);
                } else {
                    log_info!("Device {} has no root blocks", device);
                }
            }
            
            // Process each device's chain separately to maintain grouping
            let mut sorted_ids = Vec::new();
            let mut visited = std::collections::HashSet::new();
            
            // Process devices in order (for consistent results)
            let mut devices: Vec<String> = blocks_by_device.keys().cloned().collect();
            devices.sort();
            log_info!("Processing devices in order: {:?}", devices);
            
            for device in &devices {
                log_info!("\nProcessing device: {}", device);
                if let Some(roots) = roots_by_device.get(device) {
                    let mut device_roots = roots.clone();
                    
                    // Sort roots within each device by timestamp
                    device_roots.sort_by(|a, b| {
                        let block_a = blocks_by_id.get(a).unwrap();
                        let block_b = blocks_by_id.get(b).unwrap();
                        
                        let binding = "".to_string();
                        let time_a = block_a.attributes.get("timestamp").unwrap_or(&binding);
                        let time_b = block_b.attributes.get("timestamp").unwrap_or(&binding);
                        log_info!("Comparing root blocks: {} (time: {}) vs {} (time: {})", a, time_a, b, time_b);
                        time_a.cmp(time_b)
                    });
                    
                    log_info!("Sorted roots for device {}: {:?}", device, device_roots);
                    
                    // Process each root from this device and its chain
                    for root in &device_roots {
                        if visited.contains(root) {
                            log_info!("Root {} already visited, skipping", root);
                            continue;
                        }
                        
                        log_info!("Starting chain from root: {}", root);
                        let mut stack = vec![root.clone()];
                        
                        // Process this chain completely
                        while let Some(block_id) = stack.pop() {
                            if visited.contains(&block_id) {
                                log_info!("  Block {} already visited, skipping", block_id);
                                continue;
                            }
                            
                            log_info!("  Adding block {} to sorted list", block_id);
                            sorted_ids.push(block_id.clone());
                            visited.insert(block_id.clone());
                            
                            if let Some(next_block_ids) = next_blocks.get(&block_id) {
                                // Sort next blocks by timestamp if there are multiple
                                let mut next_blocks_sorted = next_block_ids.clone();
                                
                                if next_blocks_sorted.len() > 1 {
                                    log_info!("  Multiple next blocks for {}: {:?}, sorting by timestamp", block_id, next_blocks_sorted);
                                    next_blocks_sorted.sort_by(|a, b| {
                                        let block_a = blocks_by_id.get(a).unwrap();
                                        let block_b = blocks_by_id.get(b).unwrap();
                                        
                                        let binding = "".to_string();
                                        let time_a = block_a.attributes.get("timestamp").unwrap_or(&binding);
                                        let time_b = block_b.attributes.get("timestamp").unwrap_or(&binding);
                                        log_info!("    Comparing: {} (time: {}) vs {} (time: {})", a, time_a, b, time_b);
                                        time_a.cmp(time_b)
                                    });
                                    log_info!("    Sorted next blocks: {:?}", next_blocks_sorted);
                                }
                                
                                // Add to stack in reverse order for depth-first traversal
                                for next_id in next_blocks_sorted.into_iter().rev() {
                                    if !visited.contains(&next_id) {
                                        log_info!("    Pushing {} onto stack", next_id);
                                        stack.push(next_id);
                                    } else {
                                        log_info!("    Next block {} already visited, skipping", next_id);
                                    }
                                }
                            } else {
                                log_info!("  No next blocks for {}", block_id);
                            }
                        }
                    }
                    
                    // Add any remaining blocks from this device that weren't in chains
                    if let Some(device_blocks) = blocks_by_device.get(device) {
                        let remaining = device_blocks.iter()
                            .filter(|id| !visited.contains(*id))
                            .collect::<Vec<_>>();
                            
                        if !remaining.is_empty() {
                            log_info!("Adding {} remaining blocks for device {}: {:?}", 
                                remaining.len(), device, remaining);
                                
                            for block_id in device_blocks {
                                if !visited.contains(block_id) {
                                    log_info!("  Adding remaining block {} to sorted list", block_id);
                                    sorted_ids.push(block_id.clone());
                                    visited.insert(block_id.clone());
                                }
                            }
                        } else {
                            log_info!("No remaining blocks for device {}", device);
                        }
                    }
                } else {
                    log_info!("No roots for device {}, skipping", device);
                }
            }
            
            // Add any remaining blocks that weren't processed
            let remaining = child_ids.iter()
                .filter(|id| !visited.contains(*id))
                .collect::<Vec<_>>();
                
            if !remaining.is_empty() {
                log_info!("Adding {} globally remaining blocks: {:?}", remaining.len(), remaining);
                
                for block_id in child_ids {
                    if !visited.contains(&block_id) {
                        log_info!("  Adding remaining block {} to sorted list", block_id);
                        sorted_ids.push(block_id.clone());
                        visited.insert(block_id.clone());
                    }
                }
            } else {
                log_info!("No globally remaining blocks");
            }
            
            log_info!("Final sorted order for parent {}: {:?}", parent_id, sorted_ids);
            sorted_children.insert(parent_id.clone(), sorted_ids);
        }
        
        log_info!("====== COMPLETED BLOCK SORTING ======");
        log_info!("Final sorted children map has {} parents", sorted_children.len());
        
        sorted_children
    }
}