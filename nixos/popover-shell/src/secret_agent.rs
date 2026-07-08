//! NetworkManager secret agent.
//!
//! Implements `org.freedesktop.NetworkManager.SecretAgent` on the session bus
//! at the well-known object path `/org/freedesktop/NetworkManager/SecretAgent`.
//! When NM needs credentials for a connection, it calls `GetSecrets`; we surface
//! a Slint password dialog and return the typed password.
//!
//! Architecture note: NM allows only one agent per identifier per user. On a
//! minimal niri session with no `nm-applet` / `gnome-keyring` agent competing,
//! registering here makes us the sole agent — the clean configuration that
//! full DEs can't assume.

use std::collections::HashMap;
use std::sync::Arc;

use parking_lot::Mutex;
use tokio::sync::oneshot;
use zbus::zvariant::{OwnedValue, Str, Value};
use zbus::{interface, Connection};

/// Callback the shell registers: given a connection name + SSID, show a Slint
/// password dialog and resolve with the user's input (or None if cancelled).
pub type PromptFn = Arc<
    Mutex<
        Option<
            Box<
                dyn Fn(&str, &str) -> oneshot::Receiver<Option<String>>
                    + Send
                    + Sync,
            >,
        >,
    >,
>;

pub struct SecretAgent {
    /// Set by the shell after startup. `None` until the Slint surface is wired.
    prompt: PromptFn,
}

impl SecretAgent {
    pub fn new() -> Self {
        Self {
            prompt: Arc::new(Mutex::new(None)),
        }
    }

    /// Register a callback that surfaces the Slint password dialog.
    pub fn set_prompt<F>(&self, f: F)
    where
        F: Fn(&str, &str) -> oneshot::Receiver<Option<String>> + Send + Sync + 'static,
    {
        *self.prompt.lock() = Some(Box::new(f));
    }

    /// Publish the agent object on the session bus (NM calls GetSecrets here)
    /// and register it with NM's AgentManager on the system bus.
    ///
    /// NM's agent protocol is split across two buses:
    ///   - System bus: AgentManager.Register (NM daemon lives here)
    ///   - Session bus: the SecretAgent D-Bus object (NM calls back here)
    ///
    /// NM discovers the agent's session-bus address via the unique D-Bus name
    /// of the registering client, so we must register from the *same* connection
    /// that exported the object — but that connection must be the session bus,
    /// while the Register call goes to the system bus.
    pub async fn register(
        self,
        session_conn: &Connection,
        system_conn: &Connection,
    ) -> zbus::Result<()> {
        // Export the SecretAgent object on the session bus.
        session_conn
            .object_server()
            .at("/org/freedesktop/NetworkManager/SecretAgent", self)
            .await?;

        // Register with NM's AgentManager on the system bus. NM will call
        // back to our session-bus object when it needs secrets.
        let proxy = AgentManagerProxyProxy::new(system_conn).await?;
        proxy
            .register("popover-shell")
            .await
            .map_err(|e| zbus::Error::Failure(format!("agent register: {e}")))?;
        Ok(())
    }
}

#[interface(name = "org.freedesktop.NetworkManager.SecretAgent")]
impl SecretAgent {
    /// NM calls this when it needs secrets for `connection_path`.
    async fn get_secrets(
        &mut self,
        connection: HashMap<String, HashMap<String, OwnedValue>>,
        _connection_path: zbus::zvariant::OwnedObjectPath,
        _setting_name: String,
        hints: Vec<String>,
        _flags: u32,
    ) -> zbus::fdo::Result<HashMap<String, HashMap<String, OwnedValue>>> {
        // Extract SSID bytes from the 802-11-wireless setting if present.
        let ssid = connection
            .get("802-11-wireless")
            .and_then(|w| w.get("ssid"))
            .and_then(|v| {
                // OwnedValue for an array of bytes → cast to Value → to array
                let val: &Value<'_> = v;
                if let Value::Array(arr) = val {
                    let bytes: Vec<u8> = arr.iter().filter_map(|v| v.try_into().ok()).collect();
                    Some(String::from_utf8_lossy(&bytes).into_owned())
                } else {
                    None
                }
            })
            .unwrap_or_default();

        // Connection id (human name) from the connection setting.
        let id = connection
            .get("connection")
            .and_then(|c| c.get("id"))
            .and_then(|v| {
                let val: &Value<'_> = v;
                if let Value::Str(s) = val {
                    Some(s.to_string())
                } else {
                    None
                }
            })
            .unwrap_or_else(|| ssid.clone());

        let kind = hints.first().map(String::as_str).unwrap_or("password");

        let rx = {
            let guard = self.prompt.lock();
            match &*guard {
                Some(prompt) => prompt(&id, &ssid),
                None => {
                    return Err(zbus::fdo::Error::Failed(
                        "no prompt handler registered".into(),
                    ))
                }
            }
        };

        match rx.await {
            Ok(Some(password)) => {
                let mut out = connection;
                let sec = out
                    .entry("802-11-wireless-security".to_string())
                    .or_insert_with(HashMap::new);
                let key = match kind {
                    "psk" => "psk",
                    "wep-passphrase" => "wep-passphrase",
                    _ => "password",
                };
                sec.insert(key.to_string(), OwnedValue::from(Str::from(password)));
                Ok(out)
            }
            _ => Err(zbus::fdo::Error::Failed(
                "user cancelled secret request".into(),
            )),
        }
    }

    /// NM calls this to cancel a pending GetSecrets.
    async fn cancel_get_secrets(
        &mut self,
        _connection_path: zbus::zvariant::OwnedObjectPath,
        _setting_name: String,
    ) -> zbus::fdo::Result<()> {
        Ok(())
    }

    /// NM calls this when secrets are no longer needed. No-op for us.
    async fn save_secrets(
        &mut self,
        _connection: HashMap<String, HashMap<String, OwnedValue>>,
        _connection_path: zbus::zvariant::OwnedObjectPath,
    ) -> zbus::fdo::Result<()> {
        Ok(())
    }

    /// NM calls this to delete secrets. No-op — we store nothing.
    async fn delete_secrets(
        &mut self,
        _connection: HashMap<String, HashMap<String, OwnedValue>>,
        _connection_path: zbus::zvariant::OwnedObjectPath,
    ) -> zbus::fdo::Result<()> {
        Ok(())
    }
}

/// Proxy for `org.freedesktop.NetworkManager.AgentManager.Register`.
/// The `#[proxy]` macro generates `AgentManagerProxyProxy` (double Proxy).
#[zbus::proxy(
    interface = "org.freedesktop.NetworkManager.AgentManager",
    default_service = "org.freedesktop.NetworkManager",
    default_path = "/org/freedesktop/NetworkManager/AgentManager"
)]
trait AgentManagerProxy {
    fn register(&self, identifier: &str) -> zbus::Result<()>;
}
