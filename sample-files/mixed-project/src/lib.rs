//! Library module for the sample project.

/// Calculate the sum of two numbers.
pub fn add(a: i32, b: i32) -> i32 {
    a + b
}

/// Calculate the product of two numbers.
pub fn multiply(a: i32, b: i32) -> i32 {
    a * b
}

/// A simple counter struct.
pub struct Counter {
    value: i32,
}

impl Counter {
    /// Create a new counter starting at zero.
    pub fn new() -> Self {
        Self { value: 0 }
    }

    /// Increment the counter by one.
    pub fn increment(&mut self) {
        self.value += 1;
    }

    /// Get the current value.
    pub fn get(&self) -> i32 {
        self.value
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_add() {
        assert_eq!(add(2, 3), 5);
    }

    #[test]
    fn test_counter() {
        let mut counter = Counter::new();
        counter.increment();
        assert_eq!(counter.get(), 1);
    }
}
