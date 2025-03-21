use std::fmt;
use crate::doc::document_types::CustomRustError;

#[derive(Debug)]
pub enum DocError {
    InvalidOperation(String),
    DecodingError(String),
    EncodingError(String),
    ValidationError(String),
    StateError(String),
    BlockNotFound(String),
    MergeError(String),
    UpdateDecodingFailed(String),
    StateEncodingFailed(String),
}

impl fmt::Display for DocError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidOperation(msg) => write!(f, "Invalid operation: {}", msg),
            Self::DecodingError(msg) => write!(f, "Decoding error: {}", msg),
            Self::EncodingError(msg) => write!(f, "Encoding error: {}", msg),
            Self::ValidationError(msg) => write!(f, "Validation error: {}", msg),
            Self::StateError(msg) => write!(f, "State error: {}", msg),
            Self::BlockNotFound(msg) => write!(f, "Block not found: {}", msg),
            Self::MergeError(msg) => write!(f, "Merge error: {}", msg),
            Self::UpdateDecodingFailed(msg) => write!(f, "Update decoding failed: {}", msg),
            Self::StateEncodingFailed(msg) => write!(f, "State encoding failed: {}", msg),
        }
    }
}

impl From<DocError> for CustomRustError {
    fn from(error: DocError) -> Self {
        CustomRustError::new(&error.to_string())
    }
}