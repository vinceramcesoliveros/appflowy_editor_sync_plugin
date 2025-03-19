use core::error;
use flutter_rust_bridge::{frb, DartFnFuture};
use std::{collections::HashMap};
use log::{info, error}; // Ensure log crate is included for logging

use crate::doc::document_types::FailedToDecodeUpdates;

use super::{document_types::{BlockActionDoc, DocumentState, CustomRustError}, utils::document_impl::{DocumentServiceImpl}};

// Public API struct (exposed to FRB)
#[frb]
pub struct DocumentService {
    inner: DocumentServiceImpl,
}

impl DocumentService {
    #[frb]
    pub fn new(doc_id: String) -> Self {
        info!("DocumentService::new: Creating new instance with doc_id: {}", doc_id);
        Self {
            inner: DocumentServiceImpl::new(doc_id),
        }
    }

    #[no_mangle]
    #[inline(never)]
    #[frb]
    pub fn apply_action(&mut self, actions: Vec<BlockActionDoc>, diff_deltas: impl Fn(String, String) -> DartFnFuture<String>) -> Result<Vec<u8>, CustomRustError> {
        info!("DocumentService::apply_action: Applying {} actions", actions.len());
        println!("Applying actions: {:?}", actions);

        let result = self.inner.apply_action_inner(actions, &diff_deltas)?;
        info!("DocumentService::apply_action: Successfully applied actions");
        Ok(result)
    }

    #[no_mangle]
    #[inline(never)]
    #[frb]
    pub fn get_document_json(&self) -> Result<DocumentState, CustomRustError> {
        info!("DocumentService::get_document_json: Retrieving document state");

        let state = self.inner.get_document_state()?;
        info!("DocumentService::get_document_json: Successfully retrieved state");
        Ok(state)
    }

    #[no_mangle]
    #[inline(never)]
    #[frb]
    pub fn merge_updates(&self, updates: Vec<Vec<u8>>) -> Result<Vec<u8>, CustomRustError> {
        info!("DocumentService::merge_updates: Merging {} updates", updates.len());
        let state = self.inner.merge_updates_inner(updates)?;
        Ok(state)
    }

    #[no_mangle]
    #[inline(never)]
    #[frb]
    pub fn apply_updates(&mut self, update: Vec<(String, Vec<u8>)>) -> Result<(), CustomRustError> {
        info!("DocumentService::apply_updates: Applying {} updates", update.len());

        let res =  self.inner.apply_updates_inner(update);
        info!("DocumentService::apply_updates: Successfully applied updates");
        res
    }

    #[no_mangle]
    #[inline(never)]
    #[frb]
    pub fn init_empty_doc(&mut self) -> Result<Vec<u8>, CustomRustError> {
        let result = self.inner.init_empty_doc_inner()?;
        info!("DocumentService::init_empty_doc: Successfully initialized empty doc");
        Ok(result)
    }
}