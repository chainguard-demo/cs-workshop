#!/usr/bin/env python3
"""
worker_process.py

Lightweight subprocess worker for safe image operations.
Performs simple transformations (thumbnail, metadata extraction) only.
"""

import sys
import json
from PIL import Image, UnidentifiedImageError

def main(path: str) -> int:
    try:
        # Verify and reopen image
        with Image.open(path) as img:
            img.verify()  # quick structural check

        with Image.open(path) as img:
            # Example safe operation: make a thumbnail
            img = img.convert("RGB")
            img.thumbnail((512, 512))
            out = {
                "format": img.format or "UNKNOWN",
                "size": img.size,
                "mode": img.mode,
            }
            print(json.dumps(out))
            return 0

    except UnidentifiedImageError:
        print(json.dumps({"error": "unrecognized_image"}))
        return 2
    except Exception as e:
        print(json.dumps({"error": "processing_failed", "detail": str(e)}))
        return 3

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: worker_process.py <path>", file=sys.stderr)
        sys.exit(1)
    sys.exit(main(sys.argv[1]))
