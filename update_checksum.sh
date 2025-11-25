#!/bin/bash

set -e

# ==========
# 工作目录调整
# ==========
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# ==========
# 基本配置
# ==========
PACKAGE_FILE="Package.swift"
CLEAN_TEMP=${CLEAN_TEMP:-false}
TEMP_DIR="checksums_temp"
CLEAN_TEMP=${CLEAN_TEMP:-false}

# ==========
# 准备目录
# ==========
mkdir -p "$TEMP_DIR"

echo "🧩 开始更新 xcframework checksums..."
echo "-------------------------------------"

# ==========
# 从 Package.swift 解析 binary targets
# ==========
TARGETS=$(
python3 - <<'PY' "$PACKAGE_FILE"
import re
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

pattern = re.compile(r"\.binaryTarget\((.*?)\)", re.S)
entries = []
for block in pattern.findall(content):
    name_match = re.search(r'name:\s*"([^"]+)"', block)
    url_match = re.search(r'url:\s*"([^"]+)"', block)
    if name_match and url_match:
        entries.append(f"{name_match.group(1)}|{url_match.group(1)}")

print("\n".join(entries))
PY
)

if [ -z "$TARGETS" ]; then
  echo "❌ 未在 $PACKAGE_FILE 中找到任何 binaryTarget 配置"
  exit 1
fi

# ==========
# 计算并缓存 checksum
# ==========
UPDATES_FILE="${TEMP_DIR}/checksums.list"
: > "$UPDATES_FILE"
while IFS='|' read -r FRAMEWORK ZIP_URL; do
  if [ -z "$FRAMEWORK" ] || [ -z "$ZIP_URL" ]; then
    continue
  fi

  ZIP_BASENAME=$(basename "$ZIP_URL")
  ZIP_FILE="$TEMP_DIR/${ZIP_BASENAME}"

  if [ -f "$ZIP_FILE" ] && [ -s "$ZIP_FILE" ]; then
    echo "♻️  使用已缓存的 ${ZIP_BASENAME}，跳过下载"
  else
    echo "⬇️  下载 ${FRAMEWORK}.xcframework.zip..."
    if ! curl --fail --location --retry 5 --retry-delay 5 --retry-max-time 300 --retry-all-errors --silent --show-error --http1.1 -o "$ZIP_FILE" "$ZIP_URL"; then
      echo "   ⚠️  HTTP/1.1 下载失败，尝试使用 HTTP/1.0..."
      curl --fail --location --retry 5 --retry-delay 5 --retry-max-time 300 --retry-all-errors --silent --show-error --http1.0 -o "$ZIP_FILE" "$ZIP_URL"
    fi
  fi

  if [ ! -s "$ZIP_FILE" ]; then
    echo "❌ 下载失败或文件为空: $ZIP_FILE"
    exit 1
  fi

  echo "🔢 正在计算 ${FRAMEWORK} 的 checksum..."
  CHECKSUM=$(swift package compute-checksum "$ZIP_FILE")

  echo "✅ ${FRAMEWORK} checksum = $CHECKSUM"

  printf "%s|%s\n" "$FRAMEWORK" "$CHECKSUM" >> "$UPDATES_FILE"
done <<< "$TARGETS"

# 若没有任何更新则提前退出
if [ ! -s "$UPDATES_FILE" ]; then
  echo "❌ 未生成任何 checksum，无法更新 $PACKAGE_FILE"
  exit 1
fi

# ==========
# 更新 Package.swift 中的 checksum 字段
# ==========
python3 - <<'PY' "$PACKAGE_FILE" "$UPDATES_FILE"
import sys
import re

package_path = sys.argv[1]
updates_path = sys.argv[2]
updates = {}
with open(updates_path, "r", encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        name, checksum = line.split("|", 1)
        updates[name] = checksum

with open(package_path, "r", encoding="utf-8") as f:
    content = f.read()

def update_checksum(text, name, checksum):
    pattern = re.compile(
        r'(\.binaryTarget\(\s*name:\s*"' + re.escape(name) + r'".*?checksum:\s*")([^"]*)(")',
        re.S,
    )
    replacement = r"\g<1>" + checksum + r"\g<3>"
    new_text, count = pattern.subn(replacement, text, count=1)
    if count == 0:
        raise SystemExit(f"未能在 Package.swift 中找到 {name} 的 checksum 字段")
    return new_text

for name, checksum in updates.items():
    content = update_checksum(content, name, checksum)

with open(package_path, "w", encoding="utf-8") as f:
    f.write(content)
PY

rm -f "$UPDATES_FILE"

# ==========
# 完成提示
# ==========
echo "-------------------------------------"
echo "✅ 所有 checksum 已更新到 $PACKAGE_FILE"
echo ""

# ==========
# 清理临时文件 / 缓存提示
# ==========
if [ -d "$TEMP_DIR" ]; then
  if [ "$CLEAN_TEMP" = "true" ] || [ "$CLEAN_TEMP" = "1" ]; then
    rm -rf "$TEMP_DIR"
    echo "🧹 已清理临时目录 $TEMP_DIR"
  else
    echo "📦 已保留缓存目录 $TEMP_DIR（如需自动清理，运行时设定 CLEAN_TEMP=true）"
  fi
fi
