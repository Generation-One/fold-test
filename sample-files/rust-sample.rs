//! Sample Rust file for testing AST-based chunking.
//!
//! This file contains various Rust constructs that should be extracted
//! as separate chunks by the tree-sitter parser.

use std::collections::HashMap;

/// A user in the system.
#[derive(Debug, Clone)]
pub struct User {
    pub id: String,
    pub name: String,
    pub email: String,
    pub age: u32,
}

impl User {
    /// Create a new user with the given details.
    pub fn new(name: String, email: String) -> Self {
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            name,
            email,
            age: 0,
        }
    }

    /// Check if the user is an adult.
    pub fn is_adult(&self) -> bool {
        self.age >= 18
    }

    /// Update the user's email address.
    pub fn update_email(&mut self, email: String) {
        self.email = email;
    }
}

/// User roles in the system.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum UserRole {
    Admin,
    Editor,
    Viewer,
    Guest,
}

impl UserRole {
    /// Check if this role has admin privileges.
    pub fn is_admin(&self) -> bool {
        matches!(self, Self::Admin)
    }

    /// Get the permission level for this role.
    pub fn permission_level(&self) -> u8 {
        match self {
            Self::Admin => 100,
            Self::Editor => 50,
            Self::Viewer => 25,
            Self::Guest => 10,
        }
    }
}

/// Trait for entities that can be authenticated.
pub trait Authenticatable {
    /// Get the authentication token.
    fn get_token(&self) -> Option<String>;

    /// Validate the authentication.
    fn validate(&self) -> bool;

    /// Refresh the authentication.
    fn refresh(&mut self) -> Result<(), AuthError>;
}

/// Authentication error types.
#[derive(Debug)]
pub enum AuthError {
    InvalidToken,
    Expired,
    NotFound,
}

/// Authenticate a user with the given credentials.
pub fn authenticate_user(username: &str, password: &str) -> Result<User, AuthError> {
    // Simplified authentication logic
    if username.is_empty() || password.is_empty() {
        return Err(AuthError::InvalidToken);
    }

    Ok(User::new(username.to_string(), format!("{}@example.com", username)))
}

/// Hash a password for storage.
pub fn hash_password(password: &str) -> String {
    // Simplified - in reality use bcrypt or similar
    format!("hashed_{}", password)
}

/// Verify a password against a hash.
pub fn verify_password(password: &str, hash: &str) -> bool {
    hash == format!("hashed_{}", password)
}

/// Configuration for the authentication system.
pub mod config {
    /// Default token expiry in seconds.
    pub const TOKEN_EXPIRY: u64 = 3600;

    /// Maximum login attempts before lockout.
    pub const MAX_LOGIN_ATTEMPTS: u32 = 5;

    /// Get the secret key for signing tokens.
    pub fn get_secret_key() -> &'static str {
        "super-secret-key"
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_user_creation() {
        let user = User::new("Alice".to_string(), "alice@example.com".to_string());
        assert_eq!(user.name, "Alice");
        assert_eq!(user.email, "alice@example.com");
    }

    #[test]
    fn test_user_role_permissions() {
        assert!(UserRole::Admin.is_admin());
        assert!(!UserRole::Viewer.is_admin());
        assert_eq!(UserRole::Admin.permission_level(), 100);
    }
}
