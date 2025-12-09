use ch57x_keyboard_tool::bridge::{
    example_config, supported_layouts, validate_config_yaml, KeyboardLayoutInfo, ValidationSummary,
};

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![
            cmd_supported_layouts,
            cmd_example_config,
            cmd_validate_config
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

#[tauri::command]
fn cmd_supported_layouts() -> Vec<KeyboardLayoutInfo> {
    supported_layouts()
}

#[tauri::command]
fn cmd_example_config() -> String {
    example_config()
}

#[tauri::command]
fn cmd_validate_config(yaml: String) -> Result<ValidationSummary, String> {
    validate_config_yaml(yaml).map_err(|e| e.to_string())
}
