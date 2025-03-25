use std::collections::HashMap;

use std::sync::Arc;

use flutter_rust_bridge::frb;
use yrs::branch::BranchPtr;
use yrs::types::text::YChange;
use yrs::types::{DefaultPrelim, Delta};
use yrs::{
  Any, Array, ArrayPrelim, ArrayRef, Map, MapPrelim, MapRef, Out, ReadTxn, Text, TextPrelim,
  TextRef, TransactionMut,
};




#[frb(ignore)]
pub trait MapExt: Map {
  fn as_map(&self) -> MapRef {
    MapRef::from(BranchPtr::from(self.as_ref()))
  }

  fn get_id(&self, txn: &impl ReadTxn) -> Option<Arc<str>> {
    let out = self.get(txn, "id")?;
    if let Out::Any(Any::String(str)) = out {
      Some(str)
    } else {
      None
    }
  }

  fn get_with_txn<T, V>(&self, txn: &T, key: &str) -> Option<V>
  where
    T: ReadTxn,
    V: TryFrom<Out, Error = Out>,
  {
    let value = self.get(txn, key)?;
    V::try_from(value).ok()
  }

  fn get_or_init_map<S: Into<Arc<str>>>(&self, txn: &mut TransactionMut, key: S) -> MapRef {
    let key = key.into();
    match self.get(txn, &key) {
      Some(Out::YMap(map)) => map,
      _ => self.insert(txn, key, MapPrelim::default()),
    }
  }

  fn get_or_init_array<S: Into<Arc<str>>>(&self, txn: &mut TransactionMut, key: S) -> ArrayRef {
    let key = key.into();
    match self.get(txn, &key) {
      Some(Out::YArray(array)) => array,
      _ => self.insert(txn, key, ArrayPrelim::default()),
    }
  }

  fn get_or_init_text<S: Into<Arc<str>>>(&self, txn: &mut TransactionMut, key: S) -> TextRef {
    let key = key.into();
    match self.get(txn, &key) {
      Some(Out::YText(text)) => text,
      _ => self.insert(txn, key, TextPrelim::new("")),
    }
  }

  fn get_text<S: Into<Arc<str>>>(&self, txn: &mut TransactionMut, key: S) -> Option<TextRef> {
    let key = key.into();
    match self.get(txn, &key) {
      Some(Out::YText(text)) => Some(text),
      _ => None,
    }
  }

  
}

impl MapExt for MapRef {}

#[frb(ignore)]
pub trait TextExt: Text {
  fn delta<T: ReadTxn>(&self, tx: &T) -> Vec<Delta> {
    let changes = self.diff(tx, YChange::identity);
    let mut deltas = vec![];
    for change in changes {
      let delta = Delta::Inserted(change.insert, change.attributes);
      deltas.push(delta);
    }
    deltas
  }
}

impl TextExt for TextRef {}


/// Converts a Yrs ArrayRef to a Vec<String> for easier comparison in tests
pub fn array_to_vec<T: ReadTxn>(txn: &T, array: &ArrayRef) -> Vec<String> {
    let mut result = Vec::new();
    for i in 0..array.len(txn) {
        if let Some(item) = array.get(txn, i) {
            result.push(item.to_string(txn));
        }
    }
    result
}

#[frb(ignore)]
pub trait ArrayExt: Array {

  //Implement get map or init by index u32
  fn get_or_init_map_by_index(&self, txn: &mut TransactionMut, index: u32) -> MapRef {
    match self.get(txn, index) {
      Some(Out::YMap(map)) => map,
      _ => self.insert(txn, index, MapPrelim::default()),
    }
  }
  
  //Implement get array or init by index u32
  fn get_or_init_array_by_index(&self, txn: &mut TransactionMut, index: u32) -> ArrayRef {
    match self.get(txn, index) {
      Some(Out::YArray(array)) => array,
      _ => self.insert(txn, index, ArrayPrelim::default()),
    }
  }

  fn clear(&self, txn: &mut TransactionMut) {
    let len = self.len(txn);
    self.remove_range(txn, 0, len);
  }

  /// Removes the first element that satisfies the predicate.
  fn remove_one<F, V>(&self, txn: &mut TransactionMut, predicate: F)
  where
    F: Fn(V) -> bool,
    V: TryFrom<Out>,
  {
    let mut i = 0;
    while let Some(out) = self.get(txn, i) {
      if let Ok(value) = V::try_from(out) {
        if predicate(value) {
          self.remove(txn, i);
          break;
        }
      }
      i += 1;
    }
  }

  //fn update_map<F>(&self, txn: &mut TransactionMut, id: &str, f: F)
  //where
  //  F: FnOnce(&mut HashMap<String, Any>),
  //{
  //  let map_ref: MapRef = self.upsert(txn, id);
  //  let mut map = map_ref.to_json(txn).into_map().unwrap();
  //  f(&mut map);
  //  Any::from(map).fill(txn, &map_ref).unwrap();
  //}

  fn index_by_id<T: ReadTxn>(&self, txn: &T, id: &str) -> Option<u32> {
    let i = self.iter(txn).position(|value| {
      if let Ok(value) = value.cast::<MapRef>() {
        if let Some(current_id) = value.get_id(txn) {
          return &*current_id == id;
        }
      }
      false
    })?;
    Some(i as u32)
  }

  fn upsert<V>(&self, txn: &mut TransactionMut, id: &str) -> V
  where
    V: DefaultPrelim + TryFrom<Out>,
  {
    match self.index_by_id(txn, id) {
      None => self.push_back(txn, V::default_prelim()),
      Some(i) => {
        let out = self.get(txn, i).unwrap();
        match V::try_from(out) {
          Ok(shared_ref) => shared_ref,
          Err(_) => {
            self.remove(txn, i);
            self.push_back(txn, V::default_prelim())
          },
        }
      },
    }
  }
}

impl<T> ArrayExt for T where T: Array {}

#[frb(ignore)]
pub trait AnyExt {
  fn into_map(self) -> Option<HashMap<String, Any>>;
  fn into_array(self) -> Option<Vec<Any>>;
}

impl AnyExt for Any {
  fn into_map(self) -> Option<HashMap<String, Any>> {
    match self {
      Any::Map(map) => Arc::into_inner(map),
      _ => None,
    }
  }

  fn into_array(self) -> Option<Vec<Any>> {
    match self {
      Any::Array(array) => Some(array.to_vec()),
      _ => None,
    }
  }
}

#[frb(ignore)]
pub trait AnyMapExt {
  fn get_as<V>(&self, key: &str) -> Option<V>
  where
    V: TryFrom<Any, Error = Any>;
}

impl AnyMapExt for HashMap<String, Any> {
  fn get_as<V>(&self, key: &str) -> Option<V>
  where
    V: TryFrom<Any, Error = Any>,
  {
    let value = self.get(key)?.clone();
    value.cast().ok()
  }
}

impl AnyMapExt for Any {
  fn get_as<V>(&self, key: &str) -> Option<V>
  where
    V: TryFrom<Any, Error = Any>,
  {
    match self {
      Any::Map(map) => map.get_as(key),
      _ => None,
    }
  }
}
