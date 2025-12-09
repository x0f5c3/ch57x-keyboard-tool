use super::*;
// Section: wire functions

#[no_mangle]
pub extern "C" fn wire_supported_layouts(port_: i64) {
    wire_supported_layouts_impl(port_)
}

#[no_mangle]
pub extern "C" fn wire_example_config(port_: i64) {
    wire_example_config_impl(port_)
}

#[no_mangle]
pub extern "C" fn wire_validate_config_yaml(port_: i64, yaml: *mut wire_uint_8_list) {
    wire_validate_config_yaml_impl(port_, yaml)
}

#[no_mangle]
pub extern "C" fn wire_upload_config_yaml(
    port_: i64,
    yaml: *mut wire_uint_8_list,
    options: *mut wire_DevelOptions,
) {
    wire_upload_config_yaml_impl(port_, yaml, options)
}

// Section: allocate functions

#[no_mangle]
pub extern "C" fn new_box_autoadd___record__u8_u8_0() -> *mut wire___record__u8_u8 {
    support::new_leak_box_ptr(wire___record__u8_u8::new_with_null_ptr())
}

#[no_mangle]
pub extern "C" fn new_box_autoadd_devel_options_0() -> *mut wire_DevelOptions {
    support::new_leak_box_ptr(wire_DevelOptions::new_with_null_ptr())
}

#[no_mangle]
pub extern "C" fn new_box_autoadd_u16_0(value: u16) -> *mut u16 {
    support::new_leak_box_ptr(value)
}

#[no_mangle]
pub extern "C" fn new_box_autoadd_u8_0(value: u8) -> *mut u8 {
    support::new_leak_box_ptr(value)
}

#[no_mangle]
pub extern "C" fn new_uint_8_list_0(len: i32) -> *mut wire_uint_8_list {
    let ans = wire_uint_8_list {
        ptr: support::new_leak_vec_ptr(Default::default(), len),
        len,
    };
    support::new_leak_box_ptr(ans)
}

// Section: related functions

// Section: impl Wire2Api

impl Wire2Api<String> for *mut wire_uint_8_list {
    fn wire2api(self) -> String {
        let vec: Vec<u8> = self.wire2api();
        String::from_utf8_lossy(&vec).into_owned()
    }
}
impl Wire2Api<(u8, u8)> for wire___record__u8_u8 {
    fn wire2api(self) -> (u8, u8) {
        (self.field0.wire2api(), self.field1.wire2api())
    }
}
impl Wire2Api<(u8, u8)> for *mut wire___record__u8_u8 {
    fn wire2api(self) -> (u8, u8) {
        let wrap = unsafe { support::box_from_leak_ptr(self) };
        Wire2Api::<(u8, u8)>::wire2api(*wrap).into()
    }
}
impl Wire2Api<DevelOptions> for *mut wire_DevelOptions {
    fn wire2api(self) -> DevelOptions {
        let wrap = unsafe { support::box_from_leak_ptr(self) };
        Wire2Api::<DevelOptions>::wire2api(*wrap).into()
    }
}
impl Wire2Api<u16> for *mut u16 {
    fn wire2api(self) -> u16 {
        unsafe { *support::box_from_leak_ptr(self) }
    }
}
impl Wire2Api<u8> for *mut u8 {
    fn wire2api(self) -> u8 {
        unsafe { *support::box_from_leak_ptr(self) }
    }
}
impl Wire2Api<DevelOptions> for wire_DevelOptions {
    fn wire2api(self) -> DevelOptions {
        DevelOptions {
            vendor_id: self.vendor_id.wire2api(),
            product_id: self.product_id.wire2api(),
            address: self.address.wire2api(),
            endpoint_address: self.endpoint_address.wire2api(),
            interface_number: self.interface_number.wire2api(),
        }
    }
}

impl Wire2Api<Vec<u8>> for *mut wire_uint_8_list {
    fn wire2api(self) -> Vec<u8> {
        unsafe {
            let wrap = support::box_from_leak_ptr(self);
            support::vec_from_leak_ptr(wrap.ptr, wrap.len)
        }
    }
}
// Section: wire structs

#[repr(C)]
#[derive(Clone)]
pub struct wire___record__u8_u8 {
    field0: u8,
    field1: u8,
}

#[repr(C)]
#[derive(Clone)]
pub struct wire_DevelOptions {
    vendor_id: u16,
    product_id: *mut u16,
    address: *mut wire___record__u8_u8,
    endpoint_address: *mut u8,
    interface_number: *mut u8,
}

#[repr(C)]
#[derive(Clone)]
pub struct wire_uint_8_list {
    ptr: *mut u8,
    len: i32,
}

// Section: impl NewWithNullPtr

pub trait NewWithNullPtr {
    fn new_with_null_ptr() -> Self;
}

impl<T> NewWithNullPtr for *mut T {
    fn new_with_null_ptr() -> Self {
        std::ptr::null_mut()
    }
}

impl NewWithNullPtr for wire___record__u8_u8 {
    fn new_with_null_ptr() -> Self {
        Self {
            field0: Default::default(),
            field1: Default::default(),
        }
    }
}

impl Default for wire___record__u8_u8 {
    fn default() -> Self {
        Self::new_with_null_ptr()
    }
}

impl NewWithNullPtr for wire_DevelOptions {
    fn new_with_null_ptr() -> Self {
        Self {
            vendor_id: Default::default(),
            product_id: core::ptr::null_mut(),
            address: core::ptr::null_mut(),
            endpoint_address: core::ptr::null_mut(),
            interface_number: core::ptr::null_mut(),
        }
    }
}

impl Default for wire_DevelOptions {
    fn default() -> Self {
        Self::new_with_null_ptr()
    }
}

// Section: sync execution mode utility

#[no_mangle]
pub extern "C" fn free_WireSyncReturn(ptr: support::WireSyncReturn) {
    unsafe {
        let _ = support::box_from_leak_ptr(ptr);
    };
}
