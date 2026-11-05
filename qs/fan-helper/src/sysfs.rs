use std::{
    collections::BTreeMap,
    fs::{self, OpenOptions},
    io::{Read, Write},
    os::unix::fs::{MetadataExt, PermissionsExt},
    path::{Path, PathBuf},
    sync::{Arc, Mutex},
};

use crate::{
    config::{Policy, ThermalSensor},
    error::{Error, Result},
};

const MAX_VALUE_BYTES: u64 = 128;
const MAX_PWM: u8 = 255;
const MAX_CHANNEL: u8 = 16;
const MAX_TEMP_INPUT: u8 = 64;
/// `pwmN_enable` = 1 means "driver takes the value written to pwmN" on every hwmon driver;
/// the automatic modes (2, 5, …) are chip-specific, so each channel's pre-touch value is recorded instead.
const MANUAL_MODE: u64 = 1;
/// `pwmN_enable` = 0 ("off"/"none") is also no firmware control: nct6775 even *reports* 0 for a manual
/// channel sitting at full duty, so 0 and 1 are one state as far as mode detection goes.
fn firmware_controls(mode: u64) -> bool {
    mode > MANUAL_MODE
}
const BASELINE_FILE: &str = "baseline.json";
/// hwmon drivers whose temperatures are trustworthy enough to guard manual control when the
/// policy doesn't name sensors. Super-I/O chips report unconnected inputs as garbage, so they're out.
const GUARD_SENSORS: &[&str] = &[
    "k10temp",
    "coretemp",
    "zenpower",
    "cpu_thermal",
    "soc_thermal",
    "amdgpu",
];

pub struct Sysfs {
    pub hwmon: PathBuf,
    pub devices: PathBuf,
    /// Where the per-channel firmware modes are remembered across helper restarts.
    pub state_dir: Option<PathBuf>,
    pub require_root_owner: bool,
}

impl Sysfs {
    pub fn system() -> Self {
        Self {
            hwmon: PathBuf::from("/sys/class/hwmon"),
            devices: PathBuf::from("/sys/devices"),
            state_dir: std::env::var_os("RUNTIME_DIRECTORY").map(PathBuf::from),
            require_root_owner: true,
        }
    }
}

struct Fan {
    id: String,
    label: String,
    base: PathBuf,
    channel: u8,
    minimum_percent: u8,
    /// The `pwmN_enable` value the firmware had before the helper touched the channel.
    /// `None` when the channel was already manual and no earlier run remembered it.
    auto_mode: Option<u64>,
}

struct Sensor {
    identity: String,
    base: PathBuf,
    input: u8,
    warning: i64,
    critical: i64,
}

struct Inventory {
    fans: Vec<Fan>,
    sensors: Vec<Sensor>,
}

pub struct Controller {
    policy: Policy,
    sysfs: Sysfs,
    inventory: Mutex<Option<Arc<Inventory>>>,
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
}

impl FanMode {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Auto => "auto",
            Self::Manual => "manual",
        }
    }
}

impl Controller {
    pub fn new(policy: Policy, sysfs: Sysfs) -> Self {
        Self {
            policy,
            sysfs,
            inventory: Mutex::new(None),
        }
    }

    pub fn policy(&self) -> &Policy {
        &self.policy
    }

    pub fn available(&self) -> Result<()> {
        let inventory = self.inventory()?;
        for fan in &inventory.fans {
            self.pwm_path(fan)?;
            self.mode_path(fan)?;
        }
        self.check_thermals(&inventory, true)
    }

    pub fn ensure_thermally_safe(&self) -> Result<()> {
        let inventory = self.inventory()?;
        self.check_thermals(&inventory, false)
    }

    fn check_thermals(&self, inventory: &Inventory, log_warning: bool) -> Result<()> {
        for sensor in &inventory.sensors {
            let temperature = self.read_temperature(sensor)?;
            if temperature >= sensor.critical {
                return Err(Error::thermal(format!(
                    "{} temp{} is at {} m°C (critical threshold {} m°C)",
                    sensor.identity, sensor.input, temperature, sensor.critical
                )));
            }
            if log_warning && temperature >= sensor.warning {
                eprintln!(
                    "warning: {} temp{} is at {temperature} m°C (warning threshold {} m°C)",
                    sensor.identity, sensor.input, sensor.warning
                );
            }
        }
        Ok(())
    }

    pub fn snapshots(&self) -> Result<Vec<FanSnapshot>> {
        let inventory = self.inventory()?;
        let result = (|| {
            let mut snapshots = Vec::with_capacity(inventory.fans.len());
            for fan in &inventory.fans {
                let raw_mode = read_u64(&self.mode_path(fan)?)?;
                let pwm = read_u64(&self.pwm_path(fan)?)?;
                let rpm = self
                    .rpm_path(fan)
                    .and_then(|path| read_u64(&path))
                    .unwrap_or(0);
                snapshots.push(FanSnapshot {
                    id: fan.id.clone(),
                    label: fan.label.clone(),
                    mode: if firmware_controls(raw_mode) {
                        FanMode::Auto
                    } else {
                        FanMode::Manual
                    },
                    percent: pwm_to_percent(pwm),
                    minimum_percent: fan.minimum_percent,
                    rpm: u32::try_from(rpm).unwrap_or(0),
                });
            }
            Ok(snapshots)
        })();
        if result.is_err() {
            // A channel vanished (driver unloaded, device gone): rediscover on the next request.
            *self.lock() = None;
        }
        result
    }

    pub fn set_percent(&self, fan_id: &str, percent: u8) -> Result<u8> {
        if percent > 100 {
            return Err(Error::request("fan percentage must be between 0 and 100"));
        }
        let inventory = self.inventory()?;
        self.check_thermals(&inventory, false)?;
        let fan = find_fan(&inventory, fan_id)?;
        let pwm = percent_to_pwm(percent).max(percent_to_pwm(fan.minimum_percent));

        let result = (|| {
            // Drivers such as nct6775 refuse pwmN writes until the channel is manual (EBUSY), and
            // switching keeps the duty the firmware was driving, so manual first, then the request.
            write_manual(&self.mode_path(fan)?)?;
            write_checked(&self.pwm_path(fan)?, u64::from(pwm))?;
            self.check_thermals(&inventory, false)?;
            Ok(pwm_to_percent(u64::from(pwm)))
        })();
        if result.is_err() {
            self.restore_all_best_effort();
        }
        result
    }

    pub fn restore_fan(&self, fan_id: &str) -> Result<()> {
        let inventory = self.inventory()?;
        self.restore_channel(find_fan(&inventory, fan_id)?)
    }

    pub fn restore_all(&self) -> Result<()> {
        let inventory = self.inventory()?;
        let mut first_error = None;
        for fan in &inventory.fans {
            if let Err(error) = self.restore_channel(fan) {
                first_error.get_or_insert(error);
            }
        }
        first_error.map_or(Ok(()), Err)
    }

    pub fn restore_all_best_effort(&self) {
        if let Err(error) = self.restore_all() {
            eprintln!("error: failed to restore every fan to safe control: {error}");
        }
    }

    fn restore_channel(&self, fan: &Fan) -> Result<()> {
        if let Some(auto_mode) = fan.auto_mode {
            if write_checked(&self.mode_path(fan)?, auto_mode).is_ok() {
                return Ok(());
            }
        }

        // If firmware control cannot be selected, leave the fan at maximum duty in manual mode.
        write_checked(&self.pwm_path(fan)?, u64::from(MAX_PWM))?;
        write_manual(&self.mode_path(fan)?)
    }

    fn read_temperature(&self, sensor: &Sensor) -> Result<i64> {
        let path = self.attribute(&sensor.base, &format!("temp{}_input", sensor.input), false)?;
        let value = read_text(&path)?.parse::<i64>().map_err(|_| {
            Error::thermal(format!(
                "{} temp{} returned an invalid value",
                sensor.identity, sensor.input
            ))
        })?;
        if !plausible_millidegrees(value) {
            return Err(Error::thermal(format!(
                "{} temp{} returned an out-of-range value",
                sensor.identity, sensor.input
            )));
        }
        Ok(value)
    }

    // ── Inventory ──

    fn lock(&self) -> std::sync::MutexGuard<'_, Option<Arc<Inventory>>> {
        self.inventory
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
    }

    fn inventory(&self) -> Result<Arc<Inventory>> {
        let mut slot = self.lock();
        if let Some(inventory) = &*slot {
            return Ok(Arc::clone(inventory));
        }
        let inventory = Arc::new(self.build_inventory()?);
        *slot = Some(Arc::clone(&inventory));
        Ok(inventory)
    }

    fn build_inventory(&self) -> Result<Inventory> {
        let remembered = self.read_baseline();
        let (mut fans, sensors) = if self.policy.discovers() {
            self.discover(&remembered)?
        } else {
            self.from_policy()?
        };
        for fan in &mut fans {
            let current = read_u64(&self.mode_path(fan)?)?;
            fan.auto_mode = if firmware_controls(current) {
                Some(current)
            } else {
                remembered.get(&fan.id).copied()
            };
            if fan.auto_mode.is_none() {
                eprintln!(
                    "warning: {} was already in manual mode; returning it to \"auto\" will hold full duty",
                    fan.id
                );
            }
        }
        self.write_baseline(&fans);
        Ok(Inventory { fans, sensors })
    }

    fn from_policy(&self) -> Result<(Vec<Fan>, Vec<Sensor>)> {
        let mut fans = Vec::new();
        let mut sensors = Vec::new();
        for device in &self.policy.devices {
            let base = self.resolve_identity(&device.identity)?;
            for channel in &device.channels {
                let fan = Fan {
                    id: fan_id(&device.identity, channel.channel),
                    label: channel.name.clone(),
                    base: base.clone(),
                    channel: channel.channel,
                    minimum_percent: channel.minimum_percent,
                    auto_mode: None,
                };
                self.pwm_path(&fan)?;
                self.mode_path(&fan)?;
                fans.push(fan);
            }
            for sensor in &device.thermal_sensors {
                sensors.push(self.policy_sensor(sensor)?);
            }
        }
        Ok((fans, sensors))
    }

    fn policy_sensor(&self, sensor: &ThermalSensor) -> Result<Sensor> {
        Ok(Sensor {
            identity: sensor.identity.clone(),
            base: self.resolve_identity(&sensor.identity)?,
            input: sensor.input,
            warning: millidegrees(sensor.warning_celsius),
            critical: millidegrees(sensor.critical_celsius),
        })
    }

    /// Every hwmon PWM channel with a spinning tachometer becomes a fan; every input on a trusted
    /// CPU/GPU sensor driver becomes a guard. A channel an earlier run drove (it may be stopped at
    /// 0 % right now) stays in so it can be restored.
    fn discover(&self, remembered: &BTreeMap<String, u64>) -> Result<(Vec<Fan>, Vec<Sensor>)> {
        let mut fans: Vec<Fan> = Vec::new();
        let mut sensors = Vec::new();
        for (identity, base) in self.hwmon_devices()? {
            for channel in 1..=MAX_CHANNEL {
                let fan = Fan {
                    id: fan_id(&identity, channel),
                    label: String::new(),
                    base: base.clone(),
                    channel,
                    minimum_percent: self.policy.default_minimum_percent,
                    auto_mode: None,
                };
                if self.pwm_path(&fan).is_err() || self.mode_path(&fan).is_err() {
                    continue;
                }
                let rpm = self
                    .rpm_path(&fan)
                    .and_then(|path| read_u64(&path))
                    .unwrap_or(0);
                if rpm == 0 && !remembered.contains_key(&fan.id) {
                    eprintln!("discovery: skipping {} (no fan detected on the header)", fan.id);
                    continue;
                }
                if fans.iter().any(|known| known.id == fan.id) {
                    eprintln!("discovery: skipping {} (duplicate hwmon identity)", fan.id);
                    continue;
                }
                let label = self
                    .attribute(&base, &format!("fan{channel}_label"), false)
                    .and_then(|path| read_text(&path))
                    .ok()
                    .filter(|label| !label.is_empty())
                    .unwrap_or_else(|| format!("Fan {channel}"));
                fans.push(Fan { label, ..fan });
            }

            if !GUARD_SENSORS.contains(&identity.as_str()) {
                continue;
            }
            for input in 1..=MAX_TEMP_INPUT {
                let sensor = Sensor {
                    identity: identity.clone(),
                    base: base.clone(),
                    input,
                    warning: millidegrees(self.policy.thermal.warning_celsius),
                    critical: millidegrees(self.policy.thermal.critical_celsius),
                };
                if self.read_temperature(&sensor).is_ok() {
                    sensors.push(sensor);
                }
            }
        }
        if fans.is_empty() {
            return Err(Error::unavailable(
                "no controllable fan found (no writable hwmon pwm channel with a spinning fan)",
            ));
        }
        if sensors.is_empty() {
            return Err(Error::unavailable(format!(
                "no temperature sensor to guard manual control (looked for {})",
                GUARD_SENSORS.join(", ")
            )));
        }
        Ok((fans, sensors))
    }

    fn hwmon_devices(&self) -> Result<Vec<(String, PathBuf)>> {
        let mut devices = Vec::new();
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
            let Ok(name_path) = self.attribute(&base, "name", false) else {
                continue;
            };
            let identity = read_text(&name_path)?;
            if crate::config::validate_identity(&identity).is_err() {
                continue;
            }
            devices.push((identity, base));
        }
        devices.sort();
        Ok(devices)
    }

    fn resolve_identity(&self, identity: &str) -> Result<PathBuf> {
        let mut matches: Vec<PathBuf> = self
            .hwmon_devices()?
            .into_iter()
            .filter(|(name, _)| name == identity)
            .map(|(_, base)| base)
            .collect();
        if matches.len() != 1 {
            return Err(Error::unavailable(format!(
                "hwmon identity {identity} resolved to {} devices",
                matches.len()
            )));
        }
        Ok(matches.pop().expect("length checked"))
    }

    fn read_baseline(&self) -> BTreeMap<String, u64> {
        let Some(dir) = &self.sysfs.state_dir else {
            return BTreeMap::new();
        };
        fs::read(dir.join(BASELINE_FILE))
            .ok()
            .and_then(|bytes| serde_json::from_slice(&bytes).ok())
            .unwrap_or_default()
    }

    fn write_baseline(&self, fans: &[Fan]) {
        let Some(dir) = &self.sysfs.state_dir else {
            return;
        };
        let baseline: BTreeMap<&str, u64> = fans
            .iter()
            .filter_map(|fan| fan.auto_mode.map(|mode| (fan.id.as_str(), mode)))
            .collect();
        let path = dir.join(BASELINE_FILE);
        let result = serde_json::to_vec(&baseline)
            .map_err(Error::from)
            .and_then(|bytes| {
                let tmp = dir.join(format!("{BASELINE_FILE}.tmp"));
                fs::write(&tmp, bytes)?;
                fs::rename(tmp, &path)?;
                Ok(())
            });
        if let Err(error) = result {
            eprintln!("warning: cannot remember firmware fan modes in {}: {error}", path.display());
        }
    }

    // ── Attributes ──

    fn pwm_path(&self, fan: &Fan) -> Result<PathBuf> {
        self.attribute(&fan.base, &format!("pwm{}", fan.channel), true)
    }

    fn mode_path(&self, fan: &Fan) -> Result<PathBuf> {
        self.attribute(&fan.base, &format!("pwm{}_enable", fan.channel), true)
    }

    fn rpm_path(&self, fan: &Fan) -> Result<PathBuf> {
        self.attribute(&fan.base, &format!("fan{}_input", fan.channel), false)
    }

    fn attribute(&self, base: &Path, name: &str, writable: bool) -> Result<PathBuf> {
        let canonical = fs::canonicalize(base.join(name)).map_err(|error| {
            Error::unavailable(format!("required attribute {name} is unavailable: {error}"))
        })?;
        if canonical.parent() != Some(base) {
            return Err(Error::unavailable(format!(
                "attribute {name} escapes its hwmon device"
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

fn find_fan<'a>(inventory: &'a Inventory, fan_id: &str) -> Result<&'a Fan> {
    inventory
        .fans
        .iter()
        .find(|fan| fan.id == fan_id)
        .ok_or_else(|| Error::request(format!("unknown fan {fan_id}")))
}

/// Select manual mode. nct6775 reads back 0 instead of 1 when pwm is already 255; either is manual.
fn write_manual(path: &Path) -> Result<()> {
    write!(
        OpenOptions::new().write(true).truncate(true).open(path)?,
        "{MANUAL_MODE}"
    )?;
    let actual = read_u64(path)?;
    if firmware_controls(actual) {
        return Err(Error::unavailable(format!(
            "{} still reports firmware mode {actual} after selecting manual",
            path.display()
        )));
    }
    Ok(())
}

fn fan_id(identity: &str, channel: u8) -> String {
    format!("{identity}:pwm{channel}")
}

fn millidegrees(celsius: f64) -> i64 {
    (celsius * 1000.0).round() as i64
}

fn plausible_millidegrees(value: i64) -> bool {
    (-40_000..=150_000).contains(&value)
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
    use crate::config::{
        parse,
        tests::{discovery_json, explicit_json},
    };

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
            fs::create_dir_all(root.join("run")).unwrap();
            std::os::unix::fs::symlink(&fan, root.join("class/hwmon/hwmon3")).unwrap();
            std::os::unix::fs::symlink(&sensor, root.join("class/hwmon/hwmon1")).unwrap();
            write(&fan, "name", "nct6797");
            write(&fan, "pwm1", "120");
            write(&fan, "pwm1_enable", "5");
            write(&fan, "fan1_input", "900");
            // An unpopulated header: controllable, but nothing spins.
            write(&fan, "pwm2", "255");
            write(&fan, "pwm2_enable", "5");
            write(&fan, "fan2_input", "0");
            write(&sensor, "name", "k10temp");
            write(&sensor, "temp1_input", "45000");
            write(&sensor, "temp1_label", "Tctl");
            Self { root, fan, sensor }
        }

        fn sysfs(&self) -> Sysfs {
            Sysfs {
                hwmon: self.root.join("class/hwmon"),
                devices: fs::canonicalize(self.root.join("devices")).unwrap(),
                state_dir: Some(self.root.join("run")),
                require_root_owner: false,
            }
        }

        pub fn controller(&self) -> Controller {
            Controller::new(
                parse(explicit_json("nct6797", 75.0, 90.0).as_bytes()).unwrap(),
                self.sysfs(),
            )
        }

        pub fn discovering(&self) -> Controller {
            Controller::new(parse(discovery_json().as_bytes()).unwrap(), self.sysfs())
        }

        pub fn read(&self, name: &str) -> String {
            fs::read_to_string(self.fan.join(name))
                .unwrap()
                .trim()
                .to_owned()
        }

        pub fn write_fan(&self, name: &str, value: &str) {
            write(&self.fan, name, value);
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
    fn restore_returns_to_the_firmware_mode_it_found() {
        let hw = FakeHwmon::new();
        hw.write_fan("pwm1_enable", "2");
        let controller = hw.controller();
        controller.set_percent("nct6797:pwm1", 80).unwrap();
        controller.restore_all().unwrap();
        assert_eq!(hw.read("pwm1_enable"), "2");
    }

    #[test]
    fn a_fresh_process_restores_from_the_remembered_baseline() {
        let hw = FakeHwmon::new();
        hw.controller().set_percent("nct6797:pwm1", 80).unwrap();
        assert_eq!(hw.read("pwm1_enable"), "1");
        // Simulates `--restore` after a crash: the new controller finds the channel manual.
        hw.controller().restore_all().unwrap();
        assert_eq!(hw.read("pwm1_enable"), "5");
    }

    #[test]
    fn off_mode_counts_as_manual_and_never_becomes_the_baseline() {
        // nct6775 reports pwm_enable=0 for a manual channel at full duty; a prior run remembered 5.
        let hw = FakeHwmon::new();
        hw.controller().set_percent("nct6797:pwm1", 100).unwrap();
        hw.write_fan("pwm1_enable", "0");
        let controller = hw.controller();
        assert_eq!(controller.snapshots().unwrap()[0].mode, FanMode::Manual);
        controller.restore_all().unwrap();
        assert_eq!(hw.read("pwm1_enable"), "5");
    }

    #[test]
    fn already_manual_channel_without_baseline_falls_back_to_full_duty() {
        let hw = FakeHwmon::new();
        hw.write_fan("pwm1_enable", "1");
        hw.write_fan("pwm1", "40");
        let controller = hw.controller();
        controller.restore_all().unwrap();
        assert_eq!(hw.read("pwm1_enable"), "1");
        assert_eq!(hw.read("pwm1"), "255");
    }

    #[test]
    fn discovery_finds_spinning_fans_and_trusted_sensors() {
        let hw = FakeHwmon::new();
        let controller = hw.discovering();
        controller.available().unwrap();
        let snapshots = controller.snapshots().unwrap();
        assert_eq!(snapshots.len(), 1);
        assert_eq!(snapshots[0].id, "nct6797:pwm1");
        assert_eq!(snapshots[0].label, "Fan 1");
        assert_eq!(snapshots[0].minimum_percent, 0);
        assert_eq!(controller.set_percent("nct6797:pwm1", 0).unwrap(), 0);
        assert_eq!(hw.read("pwm1"), "0");
        // The policy-wide critical threshold (90 °C here) guards discovered sensors.
        hw.set_temperature(90_000);
        assert!(controller.ensure_thermally_safe().is_err());
        controller.restore_all().unwrap();
        assert_eq!(hw.read("pwm1_enable"), "5");
    }

    #[test]
    fn discovery_without_a_guard_sensor_is_unavailable() {
        let hw = FakeHwmon::new();
        write(&hw.sensor, "name", "acpitz");
        assert!(hw.discovering().available().is_err());
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
