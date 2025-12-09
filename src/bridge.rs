use anyhow::Result;
use flutter_rust_bridge::frb;
use serde::Serialize;

use crate::app;
use crate::config::Config;
use crate::options::DevelOptions;

#[derive(Clone, Debug, Serialize)]
pub struct KeyboardLayoutInfo {
    pub name: String,
    pub rows: u8,
    pub columns: u8,
    pub knobs: u8,
    pub description: String,
}

#[derive(Clone, Debug, Serialize)]
pub struct ValidationSummary {
    pub layers: usize,
    pub buttons: u8,
    pub knobs: u8,
}

#[frb(sync)]
pub fn supported_layouts() -> Vec<KeyboardLayoutInfo> {
    vec![
        KeyboardLayoutInfo {
            name: "3×4 with 2 knobs (Bluetooth)".to_string(),
            rows: 3,
            columns: 4,
            knobs: 2,
            description: "Most common Bluetooth model with two rotary encoders".to_string(),
        },
        KeyboardLayoutInfo {
            name: "3×3 with 2 knobs".to_string(),
            rows: 3,
            columns: 3,
            knobs: 2,
            description: "Compact grid with dual knobs".to_string(),
        },
        KeyboardLayoutInfo {
            name: "3×2 with 1 knob".to_string(),
            rows: 2,
            columns: 3,
            knobs: 1,
            description: "Six-key layout with a single encoder".to_string(),
        },
        KeyboardLayoutInfo {
            name: "3×1 with 1 knob".to_string(),
            rows: 1,
            columns: 3,
            knobs: 1,
            description: "Three keys plus knob (limited modifiers after first chord)".to_string(),
        },
        KeyboardLayoutInfo {
            name: "4×1 without knobs".to_string(),
            rows: 1,
            columns: 4,
            knobs: 0,
            description: "Straight row of four keys".to_string(),
        },
    ]
}

#[frb(sync)]
pub fn example_config() -> String {
    include_str!("../example-mapping.yaml").to_string()
}

#[frb]
pub fn validate_config_yaml(yaml: String) -> Result<ValidationSummary> {
    let config: Config = serde_yaml::from_str(&yaml)?;
    let buttons = config.rows * config.columns;
    let knobs = config.knobs;
    let layers = config.render()?;
    Ok(ValidationSummary {
        layers: layers.len(),
        buttons,
        knobs,
    })
}

#[frb]
pub fn upload_config_yaml(yaml: String, options: Option<DevelOptions>) -> Result<()> {
    let config: Config = serde_yaml::from_str(&yaml)?;
    let opts = options.unwrap_or_default();
    app::upload_config(config, &opts)
}
