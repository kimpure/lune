mod c_arr;
mod c_fn;
pub mod c_helper;
mod c_ptr;
mod c_string;
mod c_struct;
mod c_type;
mod types;

pub use self::{
    c_arr::CArr,
    c_fn::CFn,
    c_ptr::CPtr,
    c_struct::CStruct,
    c_type::{CType, CTypeCast, CTypeStatic},
};

pub use types::create_all_c_types;
pub use types::create_all_types;

// Named registry table names
mod association_names {
    pub const CPTR_INNER: &str = "__cptr_inner";
    pub const CARR_INNER: &str = "__carr_inner";
    pub const CSTRUCT_INNER: &str = "__cstruct_inner";
    pub const CTYPE_STATIC: &str = "__ctype_static";
}
