//! Main entry point for the sample project.

mod config;
mod handlers;

use std::net::SocketAddr;

/// Application configuration.
pub struct AppConfig {
    pub host: String,
    pub port: u16,
}

impl Default for AppConfig {
    fn default() -> Self {
        Self {
            host: "127.0.0.1".to_string(),
            port: 3000,
        }
    }
}

/// Initialize the application.
pub fn init() -> AppConfig {
    AppConfig::default()
}

/// Run the main server loop.
pub async fn run(config: AppConfig) -> Result<(), Box<dyn std::error::Error>> {
    let addr: SocketAddr = format!("{}:{}", config.host, config.port).parse()?;
    println!("Server starting on {}", addr);
    Ok(())
}

fn main() {
    let config = init();
    println!("Starting with config: {}:{}", config.host, config.port);
}
