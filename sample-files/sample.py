"""
Sample Python file for Fold indexing tests.
This file demonstrates data processing patterns.
"""

from dataclasses import dataclass
from typing import List, Optional
import json


@dataclass
class DataPoint:
    """Represents a single data point for analysis."""
    id: str
    value: float
    timestamp: str
    tags: List[str]


class DataProcessor:
    """Processes and analyzes data points."""

    def __init__(self, threshold: float = 0.5):
        self.threshold = threshold
        self.data: List[DataPoint] = []

    def add_point(self, point: DataPoint) -> None:
        """Add a data point to the processor."""
        self.data.append(point)

    def filter_by_threshold(self) -> List[DataPoint]:
        """Return points above the threshold."""
        return [p for p in self.data if p.value > self.threshold]

    def calculate_average(self) -> Optional[float]:
        """Calculate average value of all data points."""
        if not self.data:
            return None
        return sum(p.value for p in self.data) / len(self.data)

    def export_json(self, filepath: str) -> None:
        """Export data points to JSON file."""
        data = [
            {
                "id": p.id,
                "value": p.value,
                "timestamp": p.timestamp,
                "tags": p.tags,
            }
            for p in self.data
        ]
        with open(filepath, 'w') as f:
            json.dump(data, f, indent=2)


def main():
    """Example usage of DataProcessor."""
    processor = DataProcessor(threshold=0.7)

    # Add sample data
    processor.add_point(DataPoint("1", 0.8, "2024-01-15", ["sensor", "temp"]))
    processor.add_point(DataPoint("2", 0.5, "2024-01-15", ["sensor", "humidity"]))
    processor.add_point(DataPoint("3", 0.9, "2024-01-16", ["sensor", "temp"]))

    # Process
    above_threshold = processor.filter_by_threshold()
    avg = processor.calculate_average()

    print(f"Points above threshold: {len(above_threshold)}")
    print(f"Average value: {avg:.2f}")


if __name__ == "__main__":
    main()
