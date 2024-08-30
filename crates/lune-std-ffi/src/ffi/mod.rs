pub mod ffi_association;
mod ffi_box;
mod ffi_lib;
mod ffi_native;
mod ffi_raw;
mod ffi_ref;

pub use self::{
    ffi_box::FfiBox,
    ffi_lib::FfiLib,
    ffi_native::{
        native_num_cast, GetNativeDataHandle, NativeConvert, NativeDataHandle, NativeSignedness,
        NativeSize,
    },
    ffi_ref::{create_nullptr, FfiRef},
};

// Named registry table names
mod association_names {
    pub const REF_INNER: &str = "__ref_inner";
    pub const SYM_INNER: &str = "__syn_inner";
}

// Converts ffi status into &str
pub const FFI_STATUS_NAMES: [&str; 4] = [
    "ffi_status_FFI_OK",
    "ffi_status_FFI_BAD_TYPEDEF",
    "ffi_status_FFI_BAD_ABI",
    "ffi_status_FFI_BAD_ARGTYPE",
];

#[allow(unused)]
pub mod bit_mask {
    pub const U8_MASK1: u8 = 1;
    pub const U8_MASK2: u8 = 2;
    pub const U8_MASK3: u8 = 4;
    pub const U8_MASK4: u8 = 8;
    pub const U8_MASK5: u8 = 16;
    pub const U8_MASK6: u8 = 32;
    pub const U8_MASK7: u8 = 64;
    pub const U8_MASK8: u8 = 128;

    macro_rules! U8_TEST {
        ($val:expr, $mask:ident) => {
            ($val & $mask != 0)
        };
    }

    pub(crate) use U8_TEST;
}
