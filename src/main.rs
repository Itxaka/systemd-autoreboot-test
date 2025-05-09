#![no_std]
#![no_main]

use r_efi::efi;

#[panic_handler]
fn panic(_info: &core::panic::PanicInfo) -> ! {
    loop {}
}

// Allocate a static buffer for panic messages
#[no_mangle]
static mut PANIC_BUFFER: [u8; 1024] = [0; 1024];

#[export_name = "efi_main"]
pub extern "win64" fn main(_image_handle: efi::Handle, system_table: *mut efi::SystemTable) -> efi::Status {
    // Print a message
    let stdout = unsafe { (*system_table).con_out };
    let message = "System will reboot in 5 seconds...\r\n\0".as_ptr();
    unsafe {
        ((*stdout).output_string)(stdout, message as *mut efi::Char16);
    }

    // Wait for 5 seconds (5 million microseconds)
    let boot_services = unsafe { (*system_table).boot_services };
    unsafe {
        ((*boot_services).stall)(5_000_000);
    }

    // Reboot the system using Runtime Services
    let runtime_services = unsafe { (*system_table).runtime_services };
    unsafe {
        ((*runtime_services).reset_system)(
            efi::RESET_COLD,
            efi::Status::SUCCESS,
            0,
            core::ptr::null_mut(),
        );
    }

    // Should never reach here, but if it does, return success
    efi::Status::SUCCESS
}