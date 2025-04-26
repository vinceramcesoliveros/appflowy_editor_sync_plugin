// src/doc/document_types.rs
use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[frb]
#[derive(Serialize, Deserialize, Debug)]
pub enum BlockActionTypeDoc {
    Insert,
    Update,
    Delete,
    Move,
}

#[frb(unignore, dart_metadata=("freezed"), json_serializable)]
#[derive(Serialize, Deserialize, Debug)]
pub struct BlockDoc {
    pub id: String,
    pub ty: String,
    pub attributes: HashMap<String, String>,
    pub delta: Option<String>,
    #[serde(rename = "parentId")]
    pub parent_id: Option<String>,
    #[serde(rename = "prevId")]
    pub prev_id: Option<String>,
    #[serde(rename = "nextId")]
    pub next_id: Option<String>,
    #[serde(rename = "oldParentId")]
    pub old_parent_id: Option<String>, //For Move action
}

#[frb(unignore, dart_metadata=("freezed"), json_serializable)]
#[derive(Serialize, Deserialize, Debug)]
pub struct BlockActionDoc {
    pub action: BlockActionTypeDoc,
    pub block: BlockDoc,
    pub path: Vec<u32>,
    #[serde(rename = "oldPath")]
    pub old_path: Option<Vec<u32>>, //For Move action
}

#[frb(unignore, dart_metadata=("freezed"), json_serializable)]
#[derive(Serialize, Deserialize, Debug)]
pub struct FailedToDecodeUpdates {
    pub failed_updates_ids: Vec<String>,
}



// Define the document structure for Flutter
#[frb(unignore, dart_metadata=("freezed"), json_serializable)]
#[derive(Serialize, Deserialize, Debug)]
pub struct DocumentState {
    pub doc_id: String,
    pub blocks: HashMap<String, BlockDoc>,
    pub children_map: HashMap<String, Vec<String>>,
    pub root_id: String,
}


// Custom error for concurrent access issues
#[frb]
#[derive(Debug)]
pub struct CustomRustError {
    pub message: String,
}

impl CustomRustError {
    pub fn new(message: &str) -> Self {
        CustomRustError {
            message: message.to_string(),
        }
    }
}

impl std::fmt::Display for CustomRustError {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        write!(f, "{}", self.message)
    }
}