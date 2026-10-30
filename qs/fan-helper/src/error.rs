use std::io;

use thiserror::Error;

pub type Result<T> = std::result::Result<T, Error>;

#[derive(Debug, Error)]
pub enum Error {
    #[error("usage error: {0}")]
    Usage(String),
    #[error("policy error: {0}")]
    Policy(String),
    #[error("invalid request: {0}")]
    Request(String),
    #[error("fan control unavailable: {0}")]
    Unavailable(String),
    #[error("unsafe thermal state: {0}")]
    Thermal(String),
    #[error("lease error: {0}")]
    Lease(String),
    #[error("I/O error: {0}")]
    Io(#[from] io::Error),
    #[error("JSON error: {0}")]
    Json(#[from] serde_json::Error),
}

impl Error {
    pub fn usage(message: impl Into<String>) -> Self {
        Self::Usage(message.into())
    }

    pub fn policy(message: impl Into<String>) -> Self {
        Self::Policy(message.into())
    }

    pub fn request(message: impl Into<String>) -> Self {
        Self::Request(message.into())
    }

    pub fn unavailable(message: impl Into<String>) -> Self {
        Self::Unavailable(message.into())
    }

    pub fn thermal(message: impl Into<String>) -> Self {
        Self::Thermal(message.into())
    }

    pub fn lease(message: impl Into<String>) -> Self {
        Self::Lease(message.into())
    }
}
