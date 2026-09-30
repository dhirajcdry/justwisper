#!/usr/bin/env python3
"""Check local web/Markdown asset paths without depending on a live deployment."""
from pathlib import Path
from html.parser import HTMLParser
import re
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parent.parent
errors = []


def check(source, value):
    if not value or value.startswith(("#", "data:", "mailto:")):
        return
    parsed = urlsplit(value)
    if parsed.scheme or parsed.netloc:
        return
    target = (source.parent / unquote(parsed.path)).resolve()
    if not target.exists():
        errors.append(f"{source.relative_to(ROOT)}: missing {value}")


class Links(HTMLParser):
    def __init__(self, source):
        super().__init__()
        self.source = source

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        for key in ("href", "src", "poster"):
            if key in attrs:
                check(self.source, attrs[key])
        if tag == "img" and "alt" not in attrs:
            errors.append(f"{self.source.relative_to(ROOT)}: image lacks alt text")


files = [ROOT / "README.md", ROOT / "CONTRIBUTING.md", ROOT / "THIRD_PARTY_NOTICES.md"]
files += [ROOT / name for name in ("SUPPORT.md", "SECURITY.md", "ROADMAP.md", "CODE_OF_CONDUCT.md")]
files += sorted((ROOT / "docs").glob("*.md"))
for source in files:
    text = source.read_text()
    for value in re.findall(r"\]\(([^\s)]+)(?:\s+[^)]*)?\)", text):
        check(source, value)
    Links(source).feed(text)
for source in [ROOT / "site/index.html", ROOT / "scripts/visuals.html"]:
    Links(source).feed(source.read_text())
for value in re.findall(r"url\(['\"]?([^)'\"]+)", (ROOT / "site/style.css").read_text()):
    check(ROOT / "site/style.css", value)
if errors:
    raise SystemExit("\n".join(errors))
print("Local documentation links, web assets, and image alt attributes passed.")
