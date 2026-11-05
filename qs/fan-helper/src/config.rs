use std::{
    collections::HashSet,
    fs,
    os::unix::fs::{MetadataExt, PermissionsExt},
    path::Path,
};

use serde::Deserialize;

use crate::error::{Error, Result};

const POLICY_PATH: &str = "/etc/qs/fan-policy.json";
const MAX_POLICY_BYTES: u64 = 64 * 1024;

/// Root-owned policy. With an empty `devices` list the helper discovers controllable fans and guard
/// sensors itself; a non-empty list is an explicit allowlist that replaces discovery entirely.
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Policy {
    pub schema_version: u32,
    pub lease_seconds: u32,
    pub renewal_seconds: u32,
    #[serde(default)]
    pub default_minimum_percent: u8,
    #[serde(default)]
    pub thermal: ThermalDefaults,
    #[serde(default)]
    pub devices: Vec<DevicePolicy>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ThermalDefaults {
    pub warning_celsius: f64,
    pub critical_celsius: f64,
}

impl Default for ThermalDefaults {
    fn default() -> Self {
        Self {
            warning_celsius: 85.0,
            critical_celsius: 95.0,
        }
    }
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct DevicePolicy {
    pub identity: String,
    pub channels: Vec<FanChannel>,
    pub thermal_sensors: Vec<ThermalSensor>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct FanChannel {
    pub name: String,
    pub channel: u8,
    pub minimum_percent: u8,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ThermalSensor {
    pub identity: String,
    pub input: u8,
    pub warning_celsius: f64,
    pub critical_celsius: f64,
}

pub fn load() -> Result<Policy> {
    let path = Path::new(POLICY_PATH);
    let link_metadata = fs::symlink_metadata(path)
        .map_err(|error| Error::policy(format!("cannot inspect {}: {error}", path.display())))?;
    if !link_metadata.file_type().is_file() && !link_metadata.file_type().is_symlink() {
        return Err(Error::policy("policy must be a regular file"));
    }
    if link_metadata.file_type().is_symlink() {
        let target = fs::canonicalize(path)?;
        if !target.starts_with("/nix/store") {
            return Err(Error::policy(
                "a policy symlink must resolve into the immutable Nix store",
            ));
        }
    }

    let metadata = fs::metadata(path)?;
    if metadata.uid() != 0 {
        return Err(Error::policy("policy must be owned by root"));
    }
    if metadata.permissions().mode() & 0o022 != 0 {
        return Err(Error::policy("policy must not be group- or world-writable"));
    }
    if metadata.len() > MAX_POLICY_BYTES {
        return Err(Error::policy("policy exceeds 64 KiB"));
    }

    parse(&fs::read(path)?)
}

pub fn parse(bytes: &[u8]) -> Result<Policy> {
    let policy: Policy = serde_json::from_slice(bytes)?;
    policy.validate()?;
    Ok(policy)
}

impl Policy {
    pub fn discovers(&self) -> bool {
        self.devices.is_empty()
    }

    fn validate(&self) -> Result<()> {
        if self.schema_version != 3 {
            return Err(Error::policy(format!(
                "unsupported policy schema version {}",
                self.schema_version
            )));
        }
        if !(2..=30).contains(&self.lease_seconds) {
            return Err(Error::policy("leaseSeconds must be between 2 and 30"));
        }
        if self.renewal_seconds == 0 || self.renewal_seconds >= self.lease_seconds {
            return Err(Error::policy(
                "renewalSeconds must be positive and shorter than leaseSeconds",
            ));
        }
        if self.default_minimum_percent > 100 {
            return Err(Error::policy("defaultMinimumPercent must be between 0 and 100"));
        }
        validate_thresholds(self.thermal.warning_celsius, self.thermal.critical_celsius)?;

        let mut device_identities = HashSet::new();
        for device in &self.devices {
            validate_identity(&device.identity)?;
            if !device_identities.insert(device.identity.as_str()) {
                return Err(Error::policy(format!(
                    "duplicate fan device identity {}",
                    device.identity
                )));
            }
            if device.channels.is_empty() || device.thermal_sensors.is_empty() {
                return Err(Error::policy(format!(
                    "device {} requires channels and thermalSensors",
                    device.identity
                )));
            }

            let mut channels = HashSet::new();
            for fan in &device.channels {
                if fan.name.trim().is_empty() || fan.name.len() > 80 {
                    return Err(Error::policy("fan name must contain 1 to 80 characters"));
                }
                if !(1..=16).contains(&fan.channel) || !channels.insert(fan.channel) {
                    return Err(Error::policy(
                        "fan channels must be unique and between 1 and 16",
                    ));
                }
                if fan.minimum_percent > 100 {
                    return Err(Error::policy("minimumPercent must be between 0 and 100"));
                }
            }

            let mut sensors = HashSet::new();
            for sensor in &device.thermal_sensors {
                validate_identity(&sensor.identity)?;
                if !(1..=64).contains(&sensor.input)
                    || !sensors.insert((sensor.identity.as_str(), sensor.input))
                {
                    return Err(Error::policy(
                        "thermal sensor identity/input pairs must be unique and inputs 1 to 64",
                    ));
                }
                validate_thresholds(sensor.warning_celsius, sensor.critical_celsius)?;
            }
        }
        Ok(())
    }
}

fn validate_thresholds(warning: f64, critical: f64) -> Result<()> {
    if !warning.is_finite()
        || !critical.is_finite()
        || !(-40.0..=150.0).contains(&warning)
        || !(-40.0..=150.0).contains(&critical)
        || warning >= critical
    {
        return Err(Error::policy("thermal thresholds are invalid"));
    }
    Ok(())
}

pub fn validate_identity(identity: &str) -> Result<()> {
    if identity.is_empty()
        || identity.len() > 64
        || !identity
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'_' | b'-' | b'.'))
    {
        return Err(Error::policy(format!(
            "invalid hwmon identity {identity:?}"
        )));
    }
    Ok(())
}

#[cfg(test)]
pub(crate) mod tests {
    use super::parse;

    pub fn discovery_json() -> String {
        serde_json::json!({
            "schemaVersion": 3,
            "leaseSeconds": 5,
            "renewalSeconds": 2,
            "defaultMinimumPercent": 0,
            "thermal": { "warningCelsius": 75.0, "criticalCelsius": 90.0 }
        })
        .to_string()
    }

    pub fn explicit_json(identity: &str, warning: f64, critical: f64) -> String {
        serde_json::json!({
            "schemaVersion": 3,
            "leaseSeconds": 5,
            "renewalSeconds": 2,
            "devices": [{
                "identity": identity,
                "channels": [{
                    "name": "CPU",
                    "channel": 1,
                    "minimumPercent": 30
                }],
                "thermalSensors": [{
                    "identity": "k10temp",
                    "input": 1,
                    "warningCelsius": warning,
                    "criticalCelsius": critical
                }]
            }]
        })
        .to_string()
    }

    #[test]
    fn discovery_policy_uses_defaults() {
        let policy = parse(
            br#"{"schemaVersion":3,"leaseSeconds":5,"renewalSeconds":2}"#,
        )
        .unwrap();
        assert!(policy.discovers());
        assert_eq!(policy.default_minimum_percent, 0);
        assert_eq!(policy.thermal.critical_celsius, 95.0);
    }

    #[test]
    fn explicit_policy_accepts_any_hwmon_identity() {
        assert!(parse(explicit_json("macsmc_hwmon", 75.0, 90.0).as_bytes()).is_ok());
        assert!(parse(explicit_json("../etc", 75.0, 90.0).as_bytes()).is_err());
    }

    #[test]
    fn rejects_inverted_thermal_thresholds() {
        assert!(parse(explicit_json("nct6797", 95.0, 90.0).as_bytes()).is_err());
        let json = discovery_json().replace("90.0", "70.0");
        assert!(parse(json.as_bytes()).is_err());
    }

    #[test]
    fn rejects_unknown_fields() {
        let json = explicit_json("nct6797", 75.0, 90.0).replace(
            "\"leaseSeconds\"",
            "\"authorizedUsers\":[],\"leaseSeconds\"",
        );
        assert!(parse(json.as_bytes()).is_err());
    }
}
