"""reportbot - generates the release status report."""

import importlib.metadata as md
import io

import yaml
from jinja2 import Template
from PIL import Image, ImageDraw
from pydantic import BaseModel
from rich.console import Console
from rich.table import Table

from . import __version__

MANIFEST = """
release: "2026.1"
channel: stable
components:
  - {name: api,       status: green}
  - {name: worker,    status: green}
  - {name: scheduler, status: amber}
"""

SUMMARY = Template(
    "Release {{ release }} ({{ channel }}): "
    "{{ green }}/{{ total }} components green."
)

TRACKED = [
    "flask", "jinja2", "werkzeug", "requests", "urllib3", "pyyaml",
    "pydantic", "python-dateutil", "celery", "pillow", "rich",
    "tabulate", "pyjokes",
]


class Component(BaseModel):
    name: str
    status: str


def render_badge(label: str) -> int:
    """Draw a PNG badge in memory and return its size in bytes."""
    img = Image.new("RGB", (240, 60), (20, 30, 48))
    ImageDraw.Draw(img).text((12, 24), label, fill=(120, 220, 160))
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return len(buf.getvalue())


def main() -> None:
    console = Console()
    manifest = yaml.safe_load(MANIFEST)
    components = [Component(**c) for c in manifest["components"]]

    console.rule(f"[bold]reportbot {__version__}")
    console.print(
        SUMMARY.render(
            release=manifest["release"],
            channel=manifest["channel"],
            total=len(components),
            green=sum(c.status == "green" for c in components),
        )
    )
    console.print(f"badge rendered: {render_badge(manifest['release'])} bytes\n")

    table = Table("package", "version", title="installed dependencies")
    for name in TRACKED:
        try:
            table.add_row(name, md.version(name))
        except md.PackageNotFoundError:
            table.add_row(name, "[red]missing[/]")
    console.print(table)


if __name__ == "__main__":
    main()
