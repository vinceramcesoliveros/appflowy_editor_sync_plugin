use std::collections::HashMap;
use std::sync::Arc;
use serde_json::{Value, Map as JsonMap, json};
use yrs::{Any as YrsAny, types::Delta, ReadTxn, Map, Array};

use crate::doc::document_types::{BlockDoc, DocumentState};
use crate::doc::constants::{ID, TYPE, PARENT_ID, PREV_ID, TEXT, ATTRIBUTES};
use crate::doc::error::DocError;
use crate::doc::document_types::CustomRustError;

/// Utilities for converting between different data representations
pub struct Conversion;

impl Conversion {
    /// Convert a Yrs Any value to a JSON Value
    pub fn yrs_any_to_json(any: &YrsAny) -> Value {
        match any {
            YrsAny::Null => Value::Null,
            YrsAny::Undefined => Value::Null,
            YrsAny::Bool(b) => Value::Bool(*b),
            YrsAny::Number(n) => {
                Value::Number(serde_json::Number::from_f64(*n).unwrap_or(0.into()))
            }
            YrsAny::String(s) => Value::String(s.to_string()),
            YrsAny::Array(arr) => Value::Array(
                arr.iter().map(Self::yrs_any_to_json).collect()
            ),
            YrsAny::Map(map) => Value::Object(
                map.iter()
                   .map(|(k, v)| (k.to_string(), Self::yrs_any_to_json(v)))
                   .collect()
            ),
            YrsAny::BigInt(i) => Value::Number((*i).into()),
            YrsAny::Buffer(_) => Value::String("<buffer>".to_string()),
        }
    }

    /// Convert a JSON Value to a Yrs Any
    pub fn json_to_yrs_any(value: &Value) -> YrsAny {
        match value {
            Value::Null => YrsAny::Null,
            Value::Bool(b) => YrsAny::Bool(*b),
            Value::Number(n) => {
                if let Some(i) = n.as_i64() {
                    YrsAny::Number(i as f64)
                } else if let Some(f) = n.as_f64() {
                    YrsAny::Number(f)
                } else {
                    YrsAny::Undefined
                }
            }
            Value::String(s) => YrsAny::String(Arc::from(s.as_str())),
            Value::Array(arr) => YrsAny::Array(
                Arc::from(arr.iter().map(Self::json_to_yrs_any).collect::<Vec<_>>())
            ),
            Value::Object(obj) => YrsAny::Map(
                Arc::from(
                    obj.iter()
                        .map(|(k, v)| (k.clone(), Self::json_to_yrs_any(v)))
                        .collect::<HashMap<_, _>>()
                )
            ),
        }
    }

    /// Convert a Yrs delta to JSON
    pub fn delta_to_json<T: ReadTxn>(
        txn: &T,
        delta: Delta<yrs::Out>
    ) -> Result<Value, CustomRustError> {
        match delta {
            Delta::Inserted(text, attrs) => {
                let mut map = JsonMap::new();
                map.insert("insert".to_string(), Value::String(text.to_string(txn)));
                
                if let Some(attributes) = attrs {
                    let attrs_json: JsonMap<String, Value> = attributes
                        .iter()
                        .map(|(k, v)| (k.to_string(), Self::yrs_any_to_json(v)))
                        .collect();
                    
                    map.insert("attributes".to_string(), Value::Object(attrs_json));
                }
                
                Ok(Value::Object(map))
            },
            Delta::Retain(len, attrs) => {
                let mut map = JsonMap::new();
                map.insert("retain".to_string(), Value::Number(len.into()));
                
                if let Some(attributes) = attrs {
                    let attrs_json: JsonMap<String, Value> = attributes
                        .iter()
                        .map(|(k, v)| (k.to_string(), Self::yrs_any_to_json(v)))
                        .collect();
                    
                    map.insert("attributes".to_string(), Value::Object(attrs_json));
                }
                
                Ok(Value::Object(map))
            },
            Delta::Deleted(len) => {
                let mut map = JsonMap::new();
                map.insert("delete".to_string(), Value::Number(len.into()));
                Ok(Value::Object(map))
            }
        }
    }

    /// Convert a sequence of deltas to JSON array
    pub fn deltas_to_json<T: ReadTxn>(
        txn: &T,
        deltas: Vec<Delta<yrs::Out>>
    ) -> Result<Value, CustomRustError> {
        let json_deltas: Result<Vec<Value>, CustomRustError> = deltas
            .into_iter()
            .map(|delta| Self::delta_to_json(txn, delta))
            .collect();
            
        json_deltas.map(Value::Array)
    }

    /// Convert a Yrs map to a BlockDoc
    pub fn map_to_block_doc<T: ReadTxn>(
        txn: &T, 
        map: &Map,
        id: &str
    ) -> Result<BlockDoc, CustomRustError> {
        let mut attributes = HashMap::new();
        
        // Extract attributes if they exist
        if let Some(attrs_map) = map.get_map(ATTRIBUTES) {
            for (k, v) in attrs_map.iter(txn) {
                attributes.insert(k.to_string(), v.to_string(txn));
            }
        }
        
        // Extract delta if text exists
        let delta = if let Some(text) = map.get_text(TEXT) {
            let deltas = text.delta(txn);
            let json_deltas = Self::deltas_to_json(txn, deltas)?;
            Some(serde_json::to_string(&json_deltas).map_err(|e| {
                DocError::EncodingError(format!("Failed to serialize delta: {}", e))
            })?)
        } else {
            None
        };
        
        // Get block type
        let ty = map.get(TYPE)
            .and_then(|v| match v {
                yrs::Out::Any(YrsAny::String(s)) => Some(s.to_string()),
                _ => None
            })
            .unwrap_or_default();
        
        // Get parent_id if it exists
        let parent_id = map.get(PARENT_ID).and_then(|v| match v {
            yrs::Out::Any(YrsAny::String(s)) => Some(s.to_string()),
            _ => None
        });
        
        // Get prev_id if it exists
        let prev_id = map.get(PREV_ID).and_then(|v| match v {
            yrs::Out::Any(YrsAny::String(s)) => Some(s.to_string()),
            _ => None
        });
        
        Ok(BlockDoc {
            id: id.to_string(),
            ty,
            attributes,
            delta,
            parent_id,
            prev_id,
            old_parent_id: None,
        })
    }

    /// Convert a document tree to JSON
    pub fn document_to_json(doc_state: &DocumentState) -> Result<Value, CustomRustError> {
        let mut blocks_json = JsonMap::new();
        
        for (id, block) in &doc_state.blocks {
            let mut block_json = JsonMap::new();
            
            // Add basic properties
            block_json.insert("id".to_string(), json!(block.id));
            block_json.insert("type".to_string(), json!(block.ty));
            
            // Add optional properties
            if let Some(parent_id) = &block.parent_id {
                block_json.insert("parentId".to_string(), json!(parent_id));
            }
            
            if let Some(prev_id) = &block.prev_id {
                block_json.insert("prevId".to_string(), json!(prev_id));
            }
            
            // Add attributes
            let attrs_json: JsonMap<String, Value> = block.attributes
                .iter()
                .map(|(k, v)| (k.clone(), json!(v)))
                .collect();
            
            block_json.insert("attributes".to_string(), Value::Object(attrs_json));
            
            // Add delta if present
            if let Some(delta) = &block.delta {
                block_json.insert("delta".to_string(), 
                    serde_json::from_str(delta).unwrap_or(Value::Null));
            }
            
            blocks_json.insert(id.clone(), Value::Object(block_json));
        }
        
        // Build children map
        let mut children_json = JsonMap::new();
        for (parent_id, children) in &doc_state.children_map {
            children_json.insert(parent_id.clone(), json!(children));
        }
        
        // Build final document
        let mut doc_json = JsonMap::new();
        doc_json.insert("docId".to_string(), json!(doc_state.doc_id));
        doc_json.insert("blocks".to_string(), Value::Object(blocks_json));
        doc_json.insert("childrenMap".to_string(), Value::Object(children_json));
        
        Ok(Value::Object(doc_json))
    }

    /// Extract strings from array for building children lists
    pub fn array_to_string_vec<T: ReadTxn>(txn: &T, array: &Array) -> Vec<String> {
        array.iter(txn)
            .map(|item| item.to_string(txn))
            .collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use yrs::{Doc, Map, Text, ArrayRef, MapRef, TextRef, TransactionMut};

    #[test]
    fn test_json_conversion_roundtrip() {
        // Test that JSON conversion is reversible
        let original_value = json!({
            "string": "hello",
            "number": 42,
            "bool": true,
            "null": null,
            "object": {
                "nested_key": "nested_value"
            },
            "array": ["one", "two"]
        });
        
        // Convert to Yrs Any
        let yrs_any = Conversion::json_to_yrs_any(&original_value);
        
        // Convert back to JSON
        let roundtrip_value = Conversion::yrs_any_to_json(&yrs_any);
        
        // Compare (ignoring some precision issues with floating point)
        assert_eq!(original_value.to_string(), roundtrip_value.to_string());
    }

    #[test]
    fn test_map_to_block_doc() {
        let doc = Doc::new();
        let mut txn = doc.transact_mut();
        
        // Create a test block map
        let block_map = doc.get_or_create_map("test_block");
        block_map.insert(&mut txn, ID, "block1");
        block_map.insert(&mut txn, TYPE, "paragraph");
        block_map.insert(&mut txn, PARENT_ID, "parent1");
        block_map.insert(&mut txn, PREV_ID, "prev1");
        
        // Add attributes
        let attrs_map = block_map.get_or_create_map(ATTRIBUTES);
        attrs_map.insert(&mut txn, "align", "center");
        attrs_map.insert(&mut txn, "bold", true);
        
        // Add text
        let text = block_map.get_or_create_text(TEXT);
        text.insert(&mut txn, 0, "Hello, world!");
        
        // Convert to BlockDoc
        let block_doc = Conversion::map_to_block_doc(&txn, &block_map, "block1").unwrap();
        
        // Verify conversion
        assert_eq!(block_doc.id, "block1");
        assert_eq!(block_doc.ty, "paragraph");
        assert_eq!(block_doc.parent_id, Some("parent1".to_string()));
        assert_eq!(block_doc.prev_id, Some("prev1".to_string()));
        assert_eq!(block_doc.attributes.get("align").unwrap(), "center");
        assert_eq!(block_doc.attributes.get("bold").unwrap(), "true");
        assert!(block_doc.delta.is_some());
    }

    #[test]
    fn test_array_to_string_vec() {
        let doc = Doc::new();
        let mut txn = doc.transact_mut();
        
        // Create a test array
        let array = doc.get_or_create_array("test_array");
        array.push_back(&mut txn, "item1");
        array.push_back(&mut txn, "item2");
        array.push_back(&mut txn, "item3");
        
        // Convert to string vec
        let strings = Conversion::array_to_string_vec(&txn, &array);
        
        // Verify conversion
        assert_eq!(strings, vec!["item1", "item2", "item3"]);
    }
}