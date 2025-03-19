use flutter_rust_bridge::DartFnFuture;
use futures::executor::block_on;
use log::{info, error};
use serde_json::{Value, Map as JsonMap};
use std::collections::HashMap;
use std::sync::Arc;

use yrs::{Delta, ReadTxn, TextRef, TransactionMut};

use crate::doc::document_types::CustomRustError;
use crate::doc::error::DocError;
use crate::doc::utils::logging::{log_info, log_error};

// Constants for delta operations
pub const INSERT: &str = "insert";
pub const RETAIN: &str = "retain";
pub const DELETE: &str = "delete";
pub const ATTRIBUTES: &str = "attributes";

pub struct DeltaOperations;

impl DeltaOperations {
    pub fn apply_delta_to_text(
        txn: &mut TransactionMut,
        text: TextRef,
        new_delta: String,
        diff_deltas: &impl Fn(String, String) -> DartFnFuture<String>
    ) -> Result<(), CustomRustError> {
        // Get current text delta
        let current_delta = text.delta(txn);
        let current_delta_value = Self::deltas_to_json(txn, current_delta)?;
        
        let current_delta_str = serde_json::to_string(&current_delta_value)
            .map_err(|e| DocError::EncodingError(format!("Failed to serialize delta: {}", e)))?;
        
        // Get delta diff from the Dart side
        log_info!("apply_delta_to_text: Computing delta diff");
        let new_delta_diff = block_on(diff_deltas(current_delta_str, new_delta));
        
        // Parse the delta diff
        log_info!("apply_delta_to_text: Parsing delta diff from JSON");
        let parsed_delta: Vec<HashMap<String, Value>> = serde_json::from_str(&new_delta_diff)
            .map_err(|e| DocError::DecodingError(format!("Failed to parse delta diff: {}", e)))?;
        
        if parsed_delta.is_empty() {
            log_info!("apply_delta_to_text: No changes to apply");
            return Ok(());
        }
        
        // Apply the delta diff
        Self::apply_delta_diff_to_text(txn, text, &parsed_delta)
    }

    pub fn apply_delta_diff_to_text(
        txn: &mut TransactionMut,
        text: TextRef,
        delta: &[HashMap<String, Value>]
    ) -> Result<(), CustomRustError> {
        log_info!("apply_delta_diff_to_text: Starting with {} operations", delta.len());
        
        let mut current_len = text.len(txn);
        let mut cursor_pos = 0;
        
        // Convert the delta operations to Y.js delta format
        let deltas = delta
            .iter()
            .map(|d| Self::parse_delta_operation(d, &mut cursor_pos, &mut current_len))
            .collect::<Result<Vec<_>, CustomRustError>>()?;
        
        // Apply the deltas to the text
        text.apply_delta(txn, deltas);
        
        Ok(())
    }

    fn parse_delta_operation(
        d: &HashMap<String, Value>, 
        cursor_pos: &mut u32,
        current_len: &mut u32
    ) -> Result<Delta, CustomRustError> {
        if d.contains_key(INSERT) {
            // Handle insert operation
            let insert = d.get(INSERT)
                .and_then(|v| v.as_str())
                .ok_or_else(|| DocError::InvalidOperation("Insert value must be a string".into()))?;
                
            let insert_len = insert.encode_utf16().count() as u32;
            if insert_len == 0 {
                return Ok(Delta::Retain(0, None));
            }
            
            let attributes = Self::parse_attributes(d);
            
            *current_len += insert_len;
            *cursor_pos += insert_len;
            
            Ok(Delta::Inserted(insert.to_string(), attributes))
            
        } else if d.contains_key(RETAIN) {
            // Handle retain operation
            let retain = d.get(RETAIN)
                .and_then(|v| v.as_u64())
                .ok_or_else(|| DocError::InvalidOperation("Retain value must be a number".into()))? as u32;
                
            if retain > *current_len - *cursor_pos {
                return Err(DocError::InvalidOperation("Retain exceeds text length".into()).into());
            }
            
            if retain == 0 {
                return Ok(Delta::Retain(0, None));
            }
            
            *cursor_pos += retain;
            
            let attributes = Self::parse_attributes(d);
            Ok(Delta::Retain(retain, attributes))
            
        } else if d.contains_key(DELETE) {
            // Handle delete operation
            let delete = d.get(DELETE)
                .and_then(|v| v.as_u64())
                .ok_or_else(|| DocError::InvalidOperation("Delete value must be a number".into()))? as u32;
                
            if delete > *current_len {
                return Err(DocError::InvalidOperation("Delete exceeds text length".into()).into());
            }
            
            if delete == 0 {
                return Ok(Delta::Deleted(0));
            }
            
            *current_len -= delete;
            *cursor_pos = (*cursor_pos).saturating_sub(delete);
            
            Ok(Delta::Deleted(delete))
        } else {
            Err(DocError::InvalidOperation("Invalid delta operation".into()).into())
        }
    }

    fn parse_attributes(d: &HashMap<String, Value>) -> Option<Box<HashMap<Arc<str>, yrs::Any>>> {
        d.get(ATTRIBUTES).map(|a| {
            Box::new(
                a.as_object()
                    .unwrap_or(&JsonMap::new())
                    .iter()
                    .map(|(k, v)| (Arc::from(k.as_str()), Self::json_value_to_yrs_any(v)))
                    .collect::<HashMap<Arc<str>, yrs::Any>>()
            )
        })
    }

    pub fn deltas_to_json<T: ReadTxn>(
        txn: &T,
        deltas: Vec<Delta<yrs::Out>>
    ) -> Result<Value, CustomRustError> {
        log_info!("deltas_to_json: Converting {} deltas", deltas.len());
        
        let json_deltas: Result<Vec<Value>, CustomRustError> = deltas
            .into_iter()
            .map(|delta| Self::delta_to_json(txn, delta))
            .collect();
            
        json_deltas.map(Value::Array)
    }

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
                        .map(|(k, v)| (k.to_string(), Self::any_to_json(v)))
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
                        .map(|(k, v)| (k.to_string(), Self::any_to_json(v)))
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
    
    /// Convert a yjs Any value to JSON
    pub fn any_to_json(any: &yrs::Any) -> Value {
        match any {
            yrs::Any::Null => Value::Null,
            yrs::Any::Undefined => Value::Null,
            yrs::Any::Bool(b) => Value::Bool(*b),
            yrs::Any::Number(n) => {
                Value::Number(serde_json::Number::from_f64(*n).unwrap_or(0.into()))
            }
            yrs::Any::String(s) => Value::String(s.to_string()),
            yrs::Any::Array(arr) => Value::Array(arr.iter().map(Self::any_to_json).collect()),
            yrs::Any::Map(map) => Value::Object(
                map.iter()
                    .map(|(k, v)| (k.to_string(), Self::any_to_json(v)))
                    .collect()
            ),
            yrs::Any::BigInt(i) => Value::Number((*i).into()),
            yrs::Any::Buffer(_) => Value::String("<buffer>".to_string()),
        }
    }
    
    /// Convert JSON value to yjs Any
    pub fn json_value_to_yrs_any(val: &Value) -> yrs::Any {
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
            Value::Array(arr) => yrs::Any::Array(
                Arc::from(arr.iter().map(Self::json_value_to_yrs_any).collect::<Vec<_>>())
            ),
            Value::Object(obj) => yrs::Any::Map(
                Arc::from(
                    obj.iter()
                        .map(|(k, v)| (k.clone(), Self::json_value_to_yrs_any(v)))
                        .collect::<HashMap<_, _>>()
                )
            ),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use yrs::{Doc, Text};

    #[test]
    fn test_json_conversion_roundtrip() {
        // Test that JSON conversion is reversible
        let original_value = Value::Object({
            let mut map = JsonMap::new();
            map.insert("string".to_string(), Value::String("hello".to_string()));
            map.insert("number".to_string(), Value::Number(42.into()));
            map.insert("bool".to_string(), Value::Bool(true));
            map.insert("null".to_string(), Value::Null);
            
            let mut nested = JsonMap::new();
            nested.insert("nested_key".to_string(), Value::String("nested_value".to_string()));
            map.insert("object".to_string(), Value::Object(nested));
            
            map.insert("array".to_string(), Value::Array(vec![
                Value::String("one".to_string()),
                Value::String("two".to_string()),
            ]));
            
            map
        });
        
        // Convert to Yrs Any
        let yrs_any = DeltaOperations::json_value_to_yrs_any(&original_value);
        
        // Convert back to JSON
        let roundtrip_value = DeltaOperations::any_to_json(&yrs_any);
        
        // Compare (ignoring some precision issues with floating point)
        assert_eq!(original_value.to_string(), roundtrip_value.to_string());
    }

    #[test]
    fn test_parse_delta_operation_insert() {
        let mut current_len = 0;
        let mut cursor_pos = 0;
        
        let mut operation = HashMap::new();
        operation.insert(INSERT.to_string(), Value::String("hello".to_string()));
        
        let result = DeltaOperations::parse_delta_operation(&operation, &mut cursor_pos, &mut current_len);
        
        assert!(result.is_ok());
        if let Ok(Delta::Inserted(text, _)) = result {
            assert_eq!(text, "hello");
            assert_eq!(current_len, 5);
            assert_eq!(cursor_pos, 5);
        } else {
            panic!("Expected Inserted delta");
        }
    }

    #[test]
    fn test_parse_delta_operation_retain() {
        let mut current_len = 10;
        let mut cursor_pos = 2;
        
        let mut operation = HashMap::new();
        operation.insert(RETAIN.to_string(), Value::Number(3.into()));
        
        let result = DeltaOperations::parse_delta_operation(&operation, &mut cursor_pos, &mut current_len);
        
        assert!(result.is_ok());
        if let Ok(Delta::Retain(length, _)) = result {
            assert_eq!(length, 3);
            assert_eq!(current_len, 10); // Unchanged
            assert_eq!(cursor_pos, 5);   // Advanced by 3
        } else {
            panic!("Expected Retain delta");
        }
    }

    #[test]
    fn test_parse_delta_operation_delete() {
        let mut current_len = 10;
        let mut cursor_pos = 5;
        
        let mut operation = HashMap::new();
        operation.insert(DELETE.to_string(), Value::Number(3.into()));
        
        let result = DeltaOperations::parse_delta_operation(&operation, &mut cursor_pos, &mut current_len);
        
        assert!(result.is_ok());
        if let Ok(Delta::Deleted(length)) = result {
            assert_eq!(length, 3);
            assert_eq!(current_len, 7);  // Reduced by 3
            assert_eq!(cursor_pos, 2);   // Reduced by 3
        } else {
            panic!("Expected Deleted delta");
        }
    }

    #[test]
    fn test_retain_exceeds_length() {
        let mut current_len = 5;
        let mut cursor_pos = 3;
        
        let mut operation = HashMap::new();
        operation.insert(RETAIN.to_string(), Value::Number(10.into())); // Too large
        
        let result = DeltaOperations::parse_delta_operation(&operation, &mut cursor_pos, &mut current_len);
        
        assert!(result.is_err());
    }
}