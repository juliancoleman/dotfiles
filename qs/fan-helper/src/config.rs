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

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Policy {
    pub schema_version: u32,
    pub lease_seconds: u32,
    pub renewal_seconds: u32,
    pub devices: Vec<DevicePolicy>,
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
    fn validate(&self) -> Result<()> {
        if self.schema_version != 2 {
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
        if self.devices.is_empty() {
            return Err(Error::policy("at least one fan device is required"));
        }

        let mut device_identities = HashSet::new();
        for device in &self.devices {
            // Only chips whose pwmN_enable semantics (1 manual, 5 firmware auto) are known.
            if device.identity != "nct6797" {
                return Err(Error::policy(format!(
                    "unsupported fan device identity {}",
                    device.identity
                )));
            }
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
                if fan.minimum_percent == 0 || fan.minimum_percent > 100 {
                    return Err(Error::policy("minimumPercent must be between 1 and 100"));
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
                if !sensor.warning_celsius.is_finite()
                    || !sensor.critical_celsius.is_finite()
                    || !(-40.0..=150.0).contains(&sensor.warning_celsius)
                    || !(-40.0..=150.0).contains(&sensor.critical_celsius)
                    || sensor.warning_celsius >= sensor.critical_celsius
                {
                    return Err(Error::policy("thermal sensor thresholds are invalid"));
                }
            }
        }
        Ok(())
    }
}

impl DevicePolicy {
    pub fn fan_id(&self, fan: &FanChannel) -> String {
        format!("{}:pwm{}", self.identity, fan.channel)
    }
}

impl ThermalSensor {
    pub fn warning_millidegrees(&self) -> i64 {
        (self.warning_celsius * 1000.0).round() as i64
    }

    pub fn critical_millidegrees(&self) -> i64 {
        (self.critical_celsius * 1000.0).round() as i64
    }
}

fn validate_identity(identity: &str) -> Result<()> {
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

    pub fn policy_json(identity: &str, warning: f64, critical: f64) -> String {
        serde_json::json!({
            "schemaVersion": 2,
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
    fn accepts_emitted_nix_schema() {
        let policy = parse(policy_json("nct6797", 75.0, 90.0).as_bytes()).unwrap();
        let device = &policy.devices[0];
        assert_eq!(device.fan_id(&device.channels[0]), "nct6797:pwm1");
    }

    #[test]
    fn rejects_non_nct_control_device() {
        assert!(parse(policy_json("macsmc_hwmon", 75.0, 90.0).as_bytes()).is_err());
    }

    #[test]
    fn rejects_inverted_thermal_thresholds() {
        assert!(parse(policy_json("nct6797", 95.0, 90.0).as_bytes()).is_err());
    }

    #[test]
    fn rejects_unknown_fields() {
        let json = policy_json("nct6797", 75.0, 90.0).replace(
            "\"leaseSeconds\"",
            "\"authorizedUsers\":[],\"leaseSeconds\"",
        );
        assert!(parse(json.as_bytes()).is_err());
    }
}
