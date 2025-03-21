use std::collections::HashMap;

use crate::doc::document_types::BlockDoc;



pub struct ChainSorting;


impl ChainSorting {
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