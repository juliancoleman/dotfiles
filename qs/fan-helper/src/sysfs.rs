use std::{
    fs::{self, OpenOptions},
    io::{Read, Write},
    os::unix::fs::{MetadataExt, PermissionsExt},
    path::{Path, PathBuf},
};

use crate::{
    config::{DevicePolicy, FanChannel, Policy, ThermalSensor},
    error::{Error, Result},
};

const MAX_VALUE_BYTES: u64 = 128;
const MAX_PWM: u8 = 255;
const NCT_AUTO_MODE: u64 = 5;
const NCT_MANUAL_MODE: u64 = 1;

pub struct Sysfs {
    pub hwmon: PathBuf,
    pub devices: PathBuf,
    pub require_root_owner: bool,
}

impl Sysfs {
    pub fn system() -> Self {
        Self {
            hwmon: PathBuf::from("/sys/class/hwmon"),
            devices: PathBuf::from("/sys/devices"),
            require_root_owner: true,
        }
    }
}

pub struct Controller {
    policy: Policy,
    sysfs: Sysfs,
}

struct ResolvedDevice {
    base: PathBuf,
}

pub struct FanSnapshot {
    pub id: String,
    pub label: String,
    pub mode: FanMode,
    pub percent: u8,
    pub minimum_percent: u8,
    pub rpm: u32,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum FanMode {
    Auto,
    Manual,
    Unknown,
}

impl FanMode {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Auto => "auto",
            Self::Manual => "manual",
            Self::Unknown => "unknown",
        }
    }
}

impl Controller {
    pub fn new(policy: Policy, sysfs: Sysfs) -> Self {
        Self { policy, sysfs }
    }

    pub fn policy(&self) -> &Policy {
        &self.policy
    }

    pub fn available(&self) -> Result<()> {
        for device in &self.policy.devices {
            self.resolve_fan_device(device)?;
        }
        self.check_thermals(true)
    }

    pub fn ensure_thermally_safe(&self) -> Result<()> {
        self.check_thermals(false)
    }

    fn check_thermals(&self, log_warning: bool) -> Result<()> {
        for device in &self.policy.devices {
            for sensor in &device.thermal_sensors {
                let temperature = self.read_temperature(sensor)?;
                let warning = sensor.warning_millidegrees();
                let critical = sensor.critical_millidegrees();
                if temperature >= critical {
                    return Err(Error::thermal(format!(
                        "{} temp{} is at {} m°C (critical threshold {} m°C)",
                        sensor.identity, sensor.input, temperature, critical
                    )));
                }
                if log_warning && temperature >= warning {
                    eprintln!(
                        "warning: {} temp{} is at {temperature} m°C (warning threshold {warning} m°C)",
                        sensor.identity, sensor.input
                    );
                }
            }
        }
        Ok(())
    }

    pub fn snapshots(&self) -> Result<Vec<FanSnapshot>> {
        let mut snapshots = Vec::new();
        for device in &self.policy.devices {
            let resolved = self.resolve_fan_device(device)?;
            for fan in &device.channels {
                let raw_mode = read_u64(&self.mode_path(&resolved, fan)?)?;
                let pwm = read_u64(&self.pwm_path(&resolved, fan)?)?;
                let rpm = read_u64(&self.rpm_path(&resolved, fan)?)?;
                let mode = match raw_mode {
                    NCT_AUTO_MODE => FanMode::Auto,
                    NCT_MANUAL_MODE => FanMode::Manual,
                    _ => FanMode::Unknown,
                };
                snapshots.push(FanSnapshot {
                    id: device.fan_id(fan),
                    label: fan.name.clone(),
                    mode,
                    percent: pwm_to_percent(pwm),
                    minimum_percent: fan.minimum_percent,
                    rpm: u32::try_from(rpm).map_err(|_| {
                        Error::unavailable("fan RPM is outside the supported range")
                    })?,
                });
            }
        }
        Ok(snapshots)
    }

    pub fn set_percent(&self, fan_id: &str, percent: u8) -> Result<u8> {
        if percent > 100 {
            return Err(Error::request("fan percentage must be between 0 and 100"));
        }
        self.ensure_thermally_safe()?;
        let (device, fan) = self.find_fan(fan_id)?;
        let resolved = self.resolve_fan_device(device)?;
        let pwm = percent_to_pwm(percent).max(percent_to_pwm(fan.minimum_percent));

        let result = (|| {
            // Establish maximum cooling before entering manual mode, then apply the
            // bounded request.
            write_checked(&self.pwm_path(&resolved, fan)?, u64::from(MAX_PWM))?;
            write_checked(&self.mode_path(&resolved, fan)?, NCT_MANUAL_MODE)?;
            write_checked(&self.pwm_path(&resolved, fan)?, u64::from(pwm))?;
            self.ensure_thermally_safe()?;
            Ok(pwm_to_percent(u64::from(pwm)))
        })();
        if result.is_err() {
            self.restore_all_best_effort();
        }
        result
    }

    pub fn restore_fan(&self, fan_id: &str) -> Result<()> {
        let (device, fan) = self.find_fan(fan_id)?;
        self.restore_channel(device, fan)
    }

    pub fn restore_all(&self) -> Result<()> {
        let mut first_error = None;
        for device in &self.policy.devices {
            for fan in &device.channels {
                if let Err(error) = self.restore_channel(device, fan) {
                    first_error.get_or_insert(error);
                }
            }
        }
        first_error.map_or(Ok(()), Err)
    }

    pub fn restore_all_best_effort(&self) {
        if let Err(error) = self.restore_all() {
            eprintln!("error: failed to restore every configured fan to safe control: {error}");
        }
    }

    fn restore_channel(&self, device: &DevicePolicy, fan: &FanChannel) -> Result<()> {
        let resolved = self.resolve_fan_device(device)?;
        if write_checked(&self.mode_path(&resolved, fan)?, NCT_AUTO_MODE).is_ok() {
            return Ok(());
        }

        // If firmware control cannot be selected, leave the fan at maximum duty in manual mode.
        write_checked(&self.pwm_path(&resolved, fan)?, u64::from(MAX_PWM))?;
        write_checked(&self.mode_path(&resolved, fan)?, NCT_MANUAL_MODE)
    }

    fn find_fan(&self, fan_id: &str) -> Result<(&DevicePolicy, &FanChannel)> {
        for device in &self.policy.devices {
            for fan in &device.channels {
                if device.fan_id(fan) == fan_id {
                    return Ok((device, fan));
                }
            }
        }
        Err(Error::request(format!("unknown fan {fan_id}")))
    }

    fn read_temperature(&self, sensor: &ThermalSensor) -> Result<i64> {
        let device = self.resolve_identity(&sensor.identity)?;
        let path =
            self.checked_attribute(&device.base, &format!("temp{}_input", sensor.input), false)?;
        let value = read_text(&path)?.parse::<i64>().map_err(|_| {
            Error::thermal(format!(
                "{} temp{} returned an invalid value",
                sensor.identity, sensor.input
            ))
        })?;
        if !(-40_000..=150_000).contains(&value) {
            return Err(Error::thermal(format!(
                "{} temp{} returned an out-of-range value",
                sensor.identity, sensor.input
            )));
        }
        Ok(value)
    }

    fn resolve_fan_device(&self, device: &DevicePolicy) -> Result<ResolvedDevice> {
        let resolved = self.resolve_identity(&device.identity)?;
        for fan in &device.channels {
            self.pwm_path(&resolved, fan)?;
            self.mode_path(&resolved, fan)?;
            self.rpm_path(&resolved, fan)?;
        }
        Ok(resolved)
    }

    fn resolve_identity(&self, identity: &str) -> Result<ResolvedDevice> {
        let mut matches = Vec::new();
        for entry in fs::read_dir(&self.sysfs.hwmon)
            .map_err(|error| Error::unavailable(format!("cannot enumerate hwmon: {error}")))?
        {
            let entry = entry?;
            let file_name = entry.file_name();
            let Some(index) = file_name
                .to_str()
                .and_then(|name| name.strip_prefix("hwmon"))
            else {
                continue;
            };
            if index.is_empty() || !index.bytes().all(|byte| byte.is_ascii_digit()) {
                continue;
            }

            let base = fs::canonicalize(entry.path())?;
            if !base.starts_with(&self.sysfs.devices) {
                continue;
            }
            let name_path = self.checked_attribute(&base, "name", false)?;
            if read_text(&name_path)? == identity {
                matches.push(base);
            }
        }
        if matches.len() != 1 {
            return Err(Error::unavailable(format!(
                "hwmon identity {identity} resolved to {} devices",
                matches.len()
            )));
        }
        Ok(ResolvedDevice {
            base: matches.pop().expect("length checked"),
        })
    }

    fn pwm_path(&self, device: &ResolvedDevice, fan: &FanChannel) -> Result<PathBuf> {
        self.checked_attribute(&device.base, &format!("pwm{}", fan.channel), true)
    }

    fn mode_path(&self, device: &ResolvedDevice, fan: &FanChannel) -> Result<PathBuf> {
        self.checked_attribute(&device.base, &format!("pwm{}_enable", fan.channel), true)
    }

    fn rpm_path(&self, device: &ResolvedDevice, fan: &FanChannel) -> Result<PathBuf> {
        self.checked_attribute(&device.base, &format!("fan{}_input", fan.channel), false)
    }

    fn checked_attribute(&self, base: &Path, name: &str, writable: bool) -> Result<PathBuf> {
        let canonical = fs::canonicalize(base.join(name)).map_err(|error| {
            Error::unavailable(format!("required attribute {name} is unavailable: {error}"))
        })?;
        if canonical.parent() != Some(base) {
            return Err(Error::unavailable(format!(
                "attribute {name} escapes the allowlisted hwmon device"
            )));
        }
        let metadata = fs::metadata(&canonical)?;
        if !metadata.is_file() || (self.sysfs.require_root_owner && metadata.uid() != 0) {
            return Err(Error::unavailable(format!(
                "attribute {name} has unsafe metadata"
            )));
        }
        if writable && metadata.permissions().mode() & 0o222 == 0 {
            return Err(Error::unavailable(format!(
                "attribute {name} is not writable"
            )));
        }
        Ok(canonical)
    }
}

fn read_text(path: &Path) -> Result<String> {
    let mut value = String::new();
    fs::File::open(path)?
        .take(MAX_VALUE_BYTES + 1)
        .read_to_string(&mut value)?;
    if value.len() as u64 > MAX_VALUE_BYTES {
        return Err(Error::unavailable(format!(
            "{} returned an oversized value",
            path.display()
        )));
    }
    Ok(value.trim().to_owned())
}

fn read_u64(path: &Path) -> Result<u64> {
    read_text(path)?
        .parse()
        .map_err(|_| Error::unavailable(format!("{} contains an invalid number", path.display())))
}

fn write_checked(path: &Path, value: u64) -> Result<()> {
    write!(
        OpenOptions::new().write(true).truncate(true).open(path)?,
        "{value}"
    )?;
    let actual = read_u64(path)?;
    if actual != value {
        return Err(Error::unavailable(format!(
            "{} readback mismatch: wrote {value}, read {actual}",
            path.display()
        )));
    }
    Ok(())
}

fn percent_to_pwm(percent: u8) -> u8 {
    (u16::from(percent) * u16::from(MAX_PWM)).div_ceil(100) as u8
}

fn pwm_to_percent(pwm: u64) -> u8 {
    (((pwm.min(u64::from(MAX_PWM)) * 100) + 127) / u64::from(MAX_PWM)) as u8
}

#[cfg(test)]
pub(crate) mod tests {
    use std::{
        fs,
        path::{Path, PathBuf},
        sync::atomic::{AtomicU32, Ordering},
    };

    use super::{Controller, FanMode, Sysfs, percent_to_pwm, pwm_to_percent};
    use crate::config::{parse, tests::policy_json};

    pub struct FakeHwmon {
        pub root: PathBuf,
        pub fan: PathBuf,
        pub sensor: PathBuf,
    }

    impl FakeHwmon {
        pub fn new() -> Self {
            static NEXT: AtomicU32 = AtomicU32::new(0);
            let root = std::env::temp_dir().join(format!(
                "qs-fan-helper-test-{}-{}",
                std::process::id(),
                NEXT.fetch_add(1, Ordering::Relaxed)
            ));
            let _ = fs::remove_dir_all(&root);
            let fan = root.join("devices/platform/nct6775.656/hwmon/hwmon3");
            let sensor = root.join("devices/pci0000:00/0000:00:18.3/hwmon/hwmon1");
            fs::create_dir_all(&fan).unwrap();
            fs::create_dir_all(&sensor).unwrap();
            fs::create_dir_all(root.join("class/hwmon")).unwrap();
            std::os::unix::fs::symlink(&fan, root.join("class/hwmon/hwmon3")).unwrap();
            std::os::unix::fs::symlink(&sensor, root.join("class/hwmon/hwmon1")).unwrap();
            write(&fan, "name", "nct6797");
            write(&fan, "pwm1", "120");
            write(&fan, "pwm1_enable", "5");
            write(&fan, "fan1_input", "900");
            write(&sensor, "name", "k10temp");
            write(&sensor, "temp1_input", "45000");
            Self { root, fan, sensor }
        }

        pub fn controller(&self) -> Controller {
            Controller::new(
                parse(policy_json("nct6797", 75.0, 90.0).as_bytes()).unwrap(),
                Sysfs {
                    hwmon: self.root.join("class/hwmon"),
                    devices: fs::canonicalize(self.root.join("devices")).unwrap(),
                    require_root_owner: false,
                },
            )
        }

        pub fn read(&self, name: &str) -> String {
            fs::read_to_string(self.fan.join(name))
                .unwrap()
                .trim()
                .to_owned()
        }

        pub fn set_temperature(&self, millidegrees: i64) {
            write(&self.sensor, "temp1_input", &millidegrees.to_string());
        }
    }

    impl Drop for FakeHwmon {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.root);
        }
    }

    fn write(dir: &Path, name: &str, value: &str) {
        fs::write(dir.join(name), value).unwrap();
    }

    #[test]
    fn percentage_conversion_is_bounded_and_monotonic() {
        assert_eq!(percent_to_pwm(0), 0);
        assert_eq!(percent_to_pwm(100), 255);
        assert_eq!(pwm_to_percent(0), 0);
        assert_eq!(pwm_to_percent(255), 100);
        assert_eq!(pwm_to_percent(999), 100);
        for percent in 0..100 {
            assert!(percent_to_pwm(percent) <= percent_to_pwm(percent + 1));
        }
    }

    #[test]
    fn set_enters_manual_and_clamps_to_minimum() {
        let hw = FakeHwmon::new();
        let controller = hw.controller();
        controller.available().unwrap();
        assert_eq!(controller.set_percent("nct6797:pwm1", 10).unwrap(), 30);
        assert_eq!(hw.read("pwm1_enable"), "1");
        assert_eq!(hw.read("pwm1"), percent_to_pwm(30).to_string());
        let snapshot = &controller.snapshots().unwrap()[0];
        assert_eq!(snapshot.mode, FanMode::Manual);
        assert_eq!(snapshot.rpm, 900);
    }

    #[test]
    fn restore_returns_to_firmware_auto() {
        let hw = FakeHwmon::new();
        let controller = hw.controller();
        controller.set_percent("nct6797:pwm1", 80).unwrap();
        controller.restore_all().unwrap();
        assert_eq!(hw.read("pwm1_enable"), "5");
    }

    #[test]
    fn critical_temperature_refuses_manual_control() {
        let hw = FakeHwmon::new();
        let controller = hw.controller();
        hw.set_temperature(91_000);
        assert!(controller.set_percent("nct6797:pwm1", 60).is_err());
        assert_eq!(hw.read("pwm1_enable"), "5");
    }

    #[test]
    fn unknown_fan_is_rejected() {
        let hw = FakeHwmon::new();
        assert!(hw.controller().set_percent("nct6797:pwm9", 60).is_err());
    }
}
