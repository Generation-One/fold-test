"""
Sample Python file for testing AST-based chunking.

Contains classes, functions, and decorators that should be
extracted as separate chunks by the tree-sitter parser.
"""

from dataclasses import dataclass
from datetime import datetime
from enum import Enum
from typing import Optional, List, Dict, Any
import hashlib
import secrets


class UserRole(Enum):
    """Available user roles in the system."""
    ADMIN = "admin"
    EDITOR = "editor"
    VIEWER = "viewer"
    GUEST = "guest"


@dataclass
class User:
    """A user in the system."""
    id: str
    name: str
    email: str
    role: UserRole
    created_at: datetime
    updated_at: datetime

    def is_admin(self) -> bool:
        """Check if user has admin privileges."""
        return self.role == UserRole.ADMIN

    def to_dict(self) -> Dict[str, Any]:
        """Convert user to dictionary representation."""
        return {
            "id": self.id,
            "name": self.name,
            "email": self.email,
            "role": self.role.value,
            "created_at": self.created_at.isoformat(),
            "updated_at": self.updated_at.isoformat(),
        }


class UserService:
    """Service for managing user operations."""

    def __init__(self):
        """Initialize the user service."""
        self._users: Dict[str, User] = {}

    def create_user(
        self,
        name: str,
        email: str,
        role: UserRole = UserRole.VIEWER
    ) -> User:
        """Create a new user with the given details."""
        user_id = secrets.token_hex(16)
        now = datetime.utcnow()

        user = User(
            id=user_id,
            name=name,
            email=email,
            role=role,
            created_at=now,
            updated_at=now,
        )

        self._users[user_id] = user
        return user

    def get_user(self, user_id: str) -> Optional[User]:
        """Get a user by their ID."""
        return self._users.get(user_id)

    def update_user(self, user_id: str, **kwargs) -> Optional[User]:
        """Update an existing user."""
        user = self._users.get(user_id)
        if not user:
            return None

        for key, value in kwargs.items():
            if hasattr(user, key):
                setattr(user, key, value)

        user.updated_at = datetime.utcnow()
        return user

    def delete_user(self, user_id: str) -> bool:
        """Delete a user by their ID."""
        if user_id in self._users:
            del self._users[user_id]
            return True
        return False

    def list_users(self, role: Optional[UserRole] = None) -> List[User]:
        """List all users with optional role filtering."""
        users = list(self._users.values())

        if role:
            users = [u for u in users if u.role == role]

        return users


class AuthService:
    """Service for handling authentication."""

    def __init__(self, secret_key: str):
        """Initialize the auth service."""
        self._secret_key = secret_key
        self._tokens: Dict[str, str] = {}

    def login(self, email: str, password: str) -> Optional[str]:
        """Authenticate a user and return a token."""
        if not email or not password:
            return None

        # Simplified auth - in reality, verify against stored hash
        token = secrets.token_urlsafe(32)
        self._tokens[email] = token
        return token

    def logout(self, email: str) -> None:
        """Logout a user and invalidate their token."""
        self._tokens.pop(email, None)

    def validate_token(self, token: str) -> bool:
        """Check if a token is valid."""
        return token in self._tokens.values()


def hash_password(password: str, salt: Optional[str] = None) -> str:
    """Hash a password with optional salt."""
    if salt is None:
        salt = secrets.token_hex(16)

    combined = f"{password}{salt}"
    hashed = hashlib.sha256(combined.encode()).hexdigest()
    return f"{salt}${hashed}"


def verify_password(password: str, hashed: str) -> bool:
    """Verify a password against a hash."""
    try:
        salt, stored_hash = hashed.split("$")
        new_hash = hash_password(password, salt)
        return new_hash == hashed
    except ValueError:
        return False


def generate_id() -> str:
    """Generate a random ID."""
    return secrets.token_hex(16)


def format_datetime(dt: datetime) -> str:
    """Format a datetime to ISO string."""
    return dt.isoformat()


def can_edit(user: User) -> bool:
    """Check if a user has at least editor privileges."""
    return user.role in (UserRole.ADMIN, UserRole.EDITOR)


if __name__ == "__main__":
    # Example usage
    service = UserService()
    user = service.create_user("Alice", "alice@example.com", UserRole.ADMIN)
    print(f"Created user: {user.to_dict()}")
