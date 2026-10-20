#!/usr/bin/env bash
# チームの見張り。全員が待機のまま止まらないようにする（POA が常駐で起動する）。
#   使い方: watchdog.sh <team-key> <状態を置くディレクトリ>
#   例:     nohup setsid watchdog.sh wb-t1 ~/myrepo-notes/team-wb-t1 >/dev/null 2>&1 < /dev/null &
# - 全員が idle/done のまま IDLE_LIMIT 秒続いたら、Lead に次の作業を出すよう自動で促す
# - 促してから ESCALATE_AFTER 秒たっても全員が待機なら、ESCALATE を記録する（POA が拾う）
# - 誰かが blocked（許可・質問の画面）になったら、BLOCKED を記録する（POA が拾う）
# - <ディレクトリ>/watchdog.pause があるあいだは何もしない（終業・使用量の上限のとき）
set -u
KEY="${1:?team-key を指定する（例 wb-t1）}"
DIR="${2:?状態を置くディレクトリを指定する}"
LOG="$DIR/watchdog-events.log"
PID_FILE="$DIR/watchdog.pid"
MEMBERS="lead-$KEY dev1-$KEY dev2-$KEY qa-$KEY"
INTERVAL="${WATCHDOG_INTERVAL:-30}"
IDLE_LIMIT="${WATCHDOG_IDLE_LIMIT:-180}"
ESCALATE_AFTER="${WATCHDOG_ESCALATE_AFTER:-300}"

mkdir -p "$DIR"
echo $$ > "$PID_FILE"
log() { echo "$(date '+%F %T') $*" >> "$LOG"; }
status_of() {
  herdr agent get "$1" 2>/dev/null |
    python3 -c 'import sys,json;print(json.load(sys.stdin)["result"]["agent"]["agent_status"])' 2>/dev/null || echo unknown
}

idle_since=0; prodded_at=0; escalated=0; blocked_seen=""
log "START pid=$$ key=$KEY"
while true; do
  if [ -e "$DIR/watchdog.pause" ]; then idle_since=0; prodded_at=0; escalated=0; sleep "$INTERVAL"; continue; fi
  now=$(date +%s); working=0; blocked=""
  for m in $MEMBERS; do
    case "$(status_of "$m")" in
      working) working=1 ;;
      blocked) blocked="$blocked $m" ;;
    esac
  done

  if [ -n "$blocked" ] && [ "$blocked" != "$blocked_seen" ]; then log "BLOCKED$blocked"; fi
  blocked_seen="$blocked"

  if [ "$working" = 1 ] || [ -n "$blocked" ]; then
    idle_since=0; prodded_at=0; escalated=0
  else
    [ "$idle_since" = 0 ] && idle_since=$now
    if [ "$prodded_at" = 0 ] && [ $((now - idle_since)) -ge "$IDLE_LIMIT" ]; then
      herdr agent prompt "lead-$KEY" "【見張り（自動）】Lead・Dev1・Dev2・QA の全員が $((IDLE_LIMIT / 60)) 分以上待機している。いま出せる作業を各メンバーに出すこと（PR のレビュー、統合ブランチ全体の確認、次の段階の下調べと Issue の下書き、テストの補強など）。PO の判断に見えるものは、推しの案で POA に回し、答えを待たずに進めること。本当に出せる作業が無いときだけ、その理由を POA に 1 行で知らせること。" >/dev/null 2>&1
      prodded_at=$now; log "PRODDED lead (idle $((now - idle_since))s)"
    elif [ "$prodded_at" != 0 ] && [ "$escalated" = 0 ] && [ $((now - prodded_at)) -ge "$ESCALATE_AFTER" ]; then
      escalated=1; log "ESCALATE all idle $((now - idle_since))s after prodding lead"
    fi
  fi
  sleep "$INTERVAL"
done
