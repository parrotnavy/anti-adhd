#!/usr/bin/env bash
set -euo pipefail

die() {
  echo "ERROR: $*" >&2
  exit 1
}

require_env() {
  local name="$1"
  local value="${!name-}"
  if [[ -z "${value}" ]]; then
    die "Missing required env var: ${name}"
  fi
}

require_env APPCAST_XML
require_env VERSION
require_env DOWNLOAD_URL
require_env SIGNATURE
require_env LENGTH

RELEASE_PAGE_URL_VALUE="${RELEASE_PAGE_URL:-}"

MARKER='<!-- Add new releases above this comment -->'

[[ -f "$APPCAST_XML" ]] || die "Appcast XML not found: $APPCAST_XML"
command -v python3 >/dev/null 2>&1 || die "python3 not found (required)"

python3 - "$APPCAST_XML" "$VERSION" "$DOWNLOAD_URL" "$SIGNATURE" "$LENGTH" "$RELEASE_PAGE_URL_VALUE" "$MARKER" <<'PY'
import os
import re
import sys
import tempfile
import xml.etree.ElementTree as ET
from xml.sax.saxutils import escape


def die(msg: str) -> None:
    raise SystemExit(f"ERROR: {msg}")


appcast_path = sys.argv[1]
version = sys.argv[2]
download_url = sys.argv[3]
signature = sys.argv[4]
length = sys.argv[5]
release_page_url = sys.argv[6]
marker = sys.argv[7]

with open(appcast_path, "r", encoding="utf-8") as f:
    xml = f.read()

def remove_items_for_version(xml_text: str, v: str) -> str:
    # Very small heuristic block removal: drop ALL <item>..</item> blocks
    # that reference this version (by enclosure attribute or tag).
    needle_attr = f'sparkle:version="{v}"'
    needle_tag = f"<sparkle:version>{v}</sparkle:version>"

    out = []
    i = 0
    while True:
        start = xml_text.find("<item", i)
        if start == -1:
            out.append(xml_text[i:])
            break

        end = xml_text.find("</item>", start)
        if end == -1:
            # Malformed XML; keep remainder and let XML validation fail later.
            out.append(xml_text[i:])
            break

        end = end + len("</item>")
        block = xml_text[start:end]
        keep = (needle_attr not in block) and (needle_tag not in block)
        out.append(xml_text[i:start])
        if keep:
            out.append(block)
        i = end

    return "".join(out)


xml = remove_items_for_version(xml, version)

marker_re = re.compile(rf"^(?P<indent>[ \t]*){re.escape(marker)}[ \t]*$", re.MULTILINE)
m = marker_re.search(xml)
if not m:
    die(f"Marker not found in appcast as a standalone line: {marker}")
indent = m.group("indent")


def attr(s: str) -> str:
    # Escape for XML attribute values wrapped in double-quotes.
    return (
        s.replace("&", "&amp;")
        .replace("\"", "&quot;")
        .replace("'", "&apos;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )

parts = [
    f"{indent}<item>",
    f"{indent}    <title>Version {escape(version)}</title>",
]

if release_page_url:
    parts.append(f"{indent}    <link>{escape(release_page_url)}</link>")

parts.extend(
    [
        f"{indent}    <description>Release {escape(version)}</description>",
        f"{indent}    <enclosure",
        f"{indent}        url=\"{attr(download_url)}\"",
        f"{indent}        sparkle:version=\"{attr(version)}\"",
        f"{indent}        sparkle:shortVersionString=\"{attr(version)}\"",
        f"{indent}        length=\"{attr(length)}\"",
        f"{indent}        type=\"application/octet-stream\"",
        f"{indent}        sparkle:edSignature=\"{attr(signature)}\" />",
        f"{indent}</item>",
        "",
    ]
)

item = "\n".join(parts)

xml = xml[: m.start()] + item + xml[m.start() :]

count = xml.count(f'sparkle:version="{version}"')
if count != 1:
    die(f"Expected exactly 1 item with sparkle:version=\"{version}\" after update, found {count}")

# Validate resulting XML before writing.
try:
    ET.fromstring(xml)
except Exception as e:
    die(f"Updated appcast is not valid XML: {e}")

dst_dir = os.path.dirname(os.path.abspath(appcast_path)) or "."
fd, tmp_path = tempfile.mkstemp(prefix=".macos-appcast.", suffix=".xml", dir=dst_dir)
try:
    with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as f:
        f.write(xml)
    os.replace(tmp_path, appcast_path)
finally:
    try:
        os.unlink(tmp_path)
    except FileNotFoundError:
        pass
PY

if command -v xmllint >/dev/null 2>&1; then
  xmllint --noout "$APPCAST_XML"
else
  python3 - "$APPCAST_XML" <<'PY'
import sys
import xml.etree.ElementTree as ET

ET.parse(sys.argv[1])
PY
fi

if ! grep -qF "$MARKER" "$APPCAST_XML"; then
  die "Marker disappeared after update (bug): $MARKER"
fi

version_count="$(grep -c "sparkle:version=\"$VERSION\"" "$APPCAST_XML" || true)"
if [[ "$version_count" != "1" ]]; then
  die "Expected exactly one matching sparkle:version=\"$VERSION\"; found $version_count"
fi

echo "Updated appcast: $APPCAST_XML (version $VERSION)"
