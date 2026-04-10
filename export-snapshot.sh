#!/bin/bash
# export-snapshot.sh
# 把本地 WeWe RSS 数据导出为静态 JSON 快照，推送到 GitHub
# 用法：手动运行 或 cron 定时运行

set -e

WEWE_API="http://localhost:4000"
REPO_DIR="/Users/dingding/Desktop/competitor-monitor"
SNAPSHOT_DIR="$REPO_DIR/data-snapshot"
LOG="/tmp/wewe-snapshot.log"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 开始导出快照..." | tee -a "$LOG"

# 检查 WeWe RSS 是否在跑
if ! curl -s --max-time 5 "$WEWE_API/feeds" > /dev/null 2>&1; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ WeWe RSS 未运行，跳过" | tee -a "$LOG"
  exit 1
fi

mkdir -p "$SNAPSHOT_DIR"

# 1. 导出公众号列表
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 导出 feeds..." | tee -a "$LOG"
curl -s --max-time 30 "$WEWE_API/feeds" > "$SNAPSHOT_DIR/feeds.json"
FEED_COUNT=$(python3 -c "import json; d=json.load(open('$SNAPSHOT_DIR/feeds.json')); print(len(d))")
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ 共 $FEED_COUNT 个公众号" | tee -a "$LOG"

# 2. 导出每个公众号的文章
FEED_IDS=$(python3 -c "import json; d=json.load(open('$SNAPSHOT_DIR/feeds.json')); [print(f['id']) for f in d]")

for FID in $FEED_IDS; do
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 导出 $FID ..." | tee -a "$LOG"
  curl -s --max-time 30 "$WEWE_API/feeds/${FID}.json?limit=100" > "$SNAPSHOT_DIR/${FID}.json"
  sleep 0.3  # 避免请求过快
done

# 3. 写入快照时间戳
TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
echo "{\"snapshotTime\": \"$TIMESTAMP\", \"feedCount\": $FEED_COUNT}" > "$SNAPSHOT_DIR/meta.json"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ 快照导出完成，时间: $TIMESTAMP" | tee -a "$LOG"

# 4. 推送到 GitHub
cd "$REPO_DIR"
git add data-snapshot/
git diff --staged --quiet && echo "[$(date '+%Y-%m-%d %H:%M:%S')] 无变化，跳过推送" | tee -a "$LOG" && exit 0

git commit -m "chore: 更新数据快照 $TIMESTAMP"
git push origin main

echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ 已推送到 GitHub" | tee -a "$LOG"
