//! NetworkManager D-Bus client.
//!
//! Talks to NM via `zbus` to: request a wifi scan, enumerate access points,
//! and initiate a connection. The secret-agent side (separate module) handles
//! the credential prompt when NM asks for one.

use std::collections::HashMap;
use std::time::Duration;

use zbus::{proxy, Connection};
use zbus::zvariant::{OwnedObjectPath, OwnedValue, Str};
#[derive(Debug, Clone)]
pub struct AccessPoint {
    pub ssid: String,
    pub signal: u8,
    pub security: Security,
    pub in_use: bool,
    /// NM device path for `Connect`.
    pub device_path: OwnedObjectPath,
    /// NM AP object path (may be empty for hidden networks).
    pub ap_path: OwnedObjectPath,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Security {
    Open,
    Wpa2,
    Wpa3,
    Enterprise,
}

impl Security {
    pub fn label(self) -> &'static str {
        match self {
            Security::Open => "Open",
            Security::Wpa2 => "WPA2",
            Security::Wpa3 => "WPA3",
            Security::Enterprise => "802.1X",
        }
    }
}

#[proxy(
    interface = "org.freedesktop.NetworkManager",
    default_service = "org.freedesktop.NetworkManager",
    default_path = "/org/freedesktop/NetworkManager"
)]
trait NetworkManager {
    fn get_devices(&self) -> zbus::Result<Vec<OwnedObjectPath>>;
    fn activate_connection(
        &self,
        connection: OwnedObjectPath,
        device: OwnedObjectPath,
        specific_object: OwnedObjectPath,
    ) -> zbus::Result<(OwnedObjectPath, OwnedObjectPath)>;
    fn add_and_activate_connection(
        &self,
        connection: HashMap<String, HashMap<String, OwnedValue>>,
        device: OwnedObjectPath,
        specific_object: OwnedObjectPath,
    ) -> zbus::Result<(OwnedObjectPath, OwnedObjectPath)>;
}

#[proxy(
    interface = "org.freedesktop.NetworkManager.Device.Wireless",
    default_service = "org.freedesktop.NetworkManager",
    default_path = "/org/freedesktop/NetworkManager/Devices/0"
)]
trait WirelessDevice {
    fn request_scan(&self, options: HashMap<String, OwnedValue>) -> zbus::Result<()>;
    fn get_access_points(&self) -> zbus::Result<Vec<OwnedObjectPath>>;
    fn get_all_access_points(&self) -> zbus::Result<Vec<OwnedObjectPath>>;
}

#[proxy(
    interface = "org.freedesktop.NetworkManager.AccessPoint",
    default_service = "org.freedesktop.NetworkManager",
    default_path = "/org/freedesktop/NetworkManager/AccessPoint/0"
)]
trait AccessPoint {
    #[zbus(property)]
    fn ssid(&self) -> zbus::Result<Vec<u8>>;
    #[zbus(property)]
    fn strength(&self) -> zbus::Result<u8>;
    #[zbus(property)]
    fn flags(&self) -> zbus::Result<u32>;
    #[zbus(property)]
    fn wpa_flags(&self) -> zbus::Result<u32>;
    #[zbus(property)]
    fn rsn_flags(&self) -> zbus::Result<u32>;
}

#[proxy(
    interface = "org.freedesktop.NetworkManager.Device",
    default_service = "org.freedesktop.NetworkManager",
    default_path = "/org/freedesktop/NetworkManager/Devices/0"
)]
trait Device {
    #[zbus(property)]
    fn device_type(&self) -> zbus::Result<u32>;
    #[zbus(property)]
    fn state(&self) -> zbus::Result<u32>;
    #[zbus(property)]
    fn active_connection(&self) -> zbus::Result<OwnedObjectPath>;
}

/// NM AP flags. From `NetworkManager.h` — `NM_802_11_AP_FLAGS_*`.
const NM_802_11_AP_FLAGS_PRIVACY: u32 = 0x1;

/// NM AP security flags. `NM_802_11_AP_SEC_*` bitfield.
const NM_802_11_AP_SEC_KEY_MGMT_PSK: u32 = 0x200;
const NM_802_11_AP_SEC_KEY_MGMT_802_1X: u32 = 0x100;
/// SAE bit (WPA3) in rsn flags.
const NM_802_11_AP_SEC_KEY_MGMT_SAE: u32 = 0x400;

/// Top-level NM client. Cheap to clone (zbus proxies are Arc-backed).
#[derive(Clone)]
pub struct Nm {
    nm: NetworkManagerProxy<'static>,
    conn: Connection,
}

impl Nm {
    pub async fn new(conn: &Connection) -> zbus::Result<Self> {
        let nm = NetworkManagerProxy::new(conn).await?;
        Ok(Self {
            nm,
            conn: conn.clone(),
        })
    }

    /// Trigger a wifi scan on the first wireless device. Non-fatal if it
    /// fails — NM throttles scans; the caller falls back to the cached AP list.
    pub async fn request_scan(&self) -> zbus::Result<()> {
        let wifi = self.wifi_device().await?;
        let opts = HashMap::new();
        wifi.request_scan(opts).await
    }

    /// Enumerate visible APs, deduped by SSID (strongest signal retained).
    pub async fn list_access_points(&self) -> zbus::Result<Vec<AccessPoint>> {
        let wifi = self.wifi_device().await?;
        let ap_paths = wifi.get_all_access_points().await?;
        log::info!("NM returned {} AP paths", ap_paths.len());

        let device_path = self.wifi_device_path().await?;
        log::info!("wifi device path: {}", device_path.as_str());

        let mut best: HashMap<String, AccessPoint> = HashMap::new();
        for path in ap_paths {
            let ap = AccessPointProxy::builder(&self.conn)
                .path(path.clone())?
                .build()
                .await?;
            let ssid_bytes = ap.ssid().await?;
            if ssid_bytes.is_empty() {
                continue; // hidden
            }
            let ssid = String::from_utf8_lossy(&ssid_bytes).into_owned();
            let signal = ap.strength().await.unwrap_or(0);
            let flags = ap.flags().await.unwrap_or(0);
            let wpa = ap.wpa_flags().await.unwrap_or(0);
            let rsn = ap.rsn_flags().await.unwrap_or(0);
            let security = classify(flags, wpa, rsn);
            let in_use = false; // simplified: real impl reads active connection

            let entry = AccessPoint {
                ssid: ssid.clone(),
                signal,
                security,
                in_use,
                device_path: device_path.clone(),
                ap_path: path,
            };

            best.entry(ssid)
                .and_modify(|existing| {
                    if signal > existing.signal {
                        *existing = entry.clone();
                    }
                })
                .or_insert(entry);
        }

        let mut aps: Vec<_> = best.into_values().collect();
        aps.sort_by(|a, b| {
            b.signal
                .cmp(&a.signal)
                .then_with(|| a.ssid.cmp(&b.ssid))
        });
        Ok(aps)
    }

    /// Connect to an AP. If a saved connection exists NM reuses it; otherwise
    /// we build a fresh 802-11-wireless connection dict and let the secret
    /// agent supply the password.
    pub async fn connect(&self, ap: &AccessPoint) -> zbus::Result<()> {
        let mut conn_settings: HashMap<String, HashMap<String, OwnedValue>> = HashMap::new();

        let mut connection = HashMap::new();
        connection.insert("id".to_string(), OwnedValue::from(Str::from(ap.ssid.as_str())));
        connection.insert(
            "type".to_string(),
            OwnedValue::from(Str::from("802-11-wireless")),
        );
        conn_settings.insert("connection".to_string(), connection);

        let mut wireless = HashMap::new();
        // SSID is an array of bytes (ay).
        let ssid_val: zbus::zvariant::Value<'_> =
            zbus::zvariant::Value::from(ap.ssid.as_bytes());
        wireless.insert("ssid".to_string(), OwnedValue::try_from(&ssid_val)?);
        wireless.insert("mode".to_string(), OwnedValue::from(Str::from("infrastructure")));
        conn_settings.insert("802-11-wireless".to_string(), wireless);

        // Security setting only if not open.
        if ap.security != Security::Open {
            let mut sec = HashMap::new();
            let key_mgmt = match ap.security {
                Security::Wpa2 | Security::Wpa3 => "wpa-psk",
                Security::Enterprise => "ieee8021x",
                Security::Open => "",
            };
            sec.insert("key-mgmt".to_string(), OwnedValue::from(Str::from(key_mgmt)));
            conn_settings.insert("802-11-wireless-security".to_string(), sec);
        }

        self.nm
            .add_and_activate_connection(
                conn_settings,
                ap.device_path.clone(),
                ap.ap_path.clone(),
            )
            .await?;
        Ok(())
    }

    async fn wifi_device_path(&self) -> zbus::Result<OwnedObjectPath> {
        let devices = self.nm.get_devices().await?;
        for path in devices {
            let dev = DeviceProxy::builder(&self.conn)
                .path(path.clone())?
                .build()
                .await?;
            // device_type 2 == WIFI
            if dev.device_type().await? == 2 {
                return Ok(path);
            }
        }
        Err(zbus::Error::Failure("no wifi device".into()))
    }

    async fn wifi_device(&self) -> zbus::Result<WirelessDeviceProxy<'static>> {
        let path = self.wifi_device_path().await?;
        WirelessDeviceProxy::builder(&self.conn)
            .path(path)?
            .build()
            .await
    }
}

fn classify(flags: u32, wpa: u32, rsn: u32) -> Security {
    if wpa & NM_802_11_AP_SEC_KEY_MGMT_802_1X != 0
        || rsn & NM_802_11_AP_SEC_KEY_MGMT_802_1X != 0
    {
        return Security::Enterprise;
    }
    if flags & NM_802_11_AP_FLAGS_PRIVACY == 0 {
        return Security::Open;
    }
    // WPA3 implies RSN with SAE.
    if rsn & NM_802_11_AP_SEC_KEY_MGMT_SAE != 0 {
        return Security::Wpa3;
    }
    if rsn & NM_802_11_AP_SEC_KEY_MGMT_PSK != 0 || wpa & NM_802_11_AP_SEC_KEY_MGMT_PSK != 0 {
        return Security::Wpa2;
    }
    Security::Wpa2 // privacy flag set but no recognized key-mgmt — assume WPA2
}

/// Wait for a scan to settle. NM throttles to ~every 10s; a brief sleep lets
/// the cached AP list refresh after `request_scan`.
pub async fn scan_settle() {
    tokio::time::sleep(Duration::from_millis(800)).await;
}
