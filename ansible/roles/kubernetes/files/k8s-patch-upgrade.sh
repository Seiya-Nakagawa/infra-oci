#!/bin/bash
# 稼働中のマイナーバージョン内の最新パッチへ、Kubernetes を更新する。
# k8s-patch-upgrade.timer から毎日実行する。--dry-run は更新の有無と中止条件の判定結果のみを表示する。
set -euo pipefail

STATE_DIR="${STATE_DIR:-/var/lib/k8s-patch-upgrade}"
ADMIN_CONF="${ADMIN_CONF:-/etc/kubernetes/admin.conf}"
FAILED_MARKER="$STATE_DIR/failed"
PACKAGES=(kubelet kubeadm kubectl)

export KUBECONFIG="$ADMIN_CONF"
# systemd のサービスは HOME を持たない場合があるため、kubeadm・kubectl 向けに補う
export HOME="${HOME:-/root}"
export DEBIAN_FRONTEND=noninteractive
# 停止を伴う処理の途中で、needrestart が他のサービスを再起動しないようにする
export NEEDRESTART_SUSPEND=1

DRY_RUN=no
case "${1:-}" in
  "") ;;
  --dry-run) DRY_RUN=yes ;;
  *)
    echo "使い方: $0 [--dry-run]" >&2
    exit 2
    ;;
esac

log() { echo "$*"; }

apt_run() { apt-get -o DPkg::Lock::Timeout=300 "$@"; }

# 版 $1 が版 $2 より古ければ真
older_than() { [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ]; }

minor_of() { echo "${1%.*}"; }

node_status() {
  kubectl get nodes -o jsonpath='{.items[0].metadata.name} {.items[0].status.conditions[?(@.type=="Ready")].status}'
}

# 更新を中止する理由を出力する。中止しない場合は何も出力しない
abort_reason() {
  local props result state finished ready
  props=$(systemctl show mysql-backup.service --timestamp=unix \
    -p Result -p ActiveState -p ExecMainExitTimestamp)
  result=$(sed -n 's/^Result=//p' <<< "$props")
  state=$(sed -n 's/^ActiveState=//p' <<< "$props")
  finished=$(sed -n 's/^ExecMainExitTimestamp=@//p' <<< "$props")
  # 一度も実行していない場合も Result は success になるため、終了日時も確認する
  if [ "$result" != success ] || [ "$state" != inactive ] || [ -z "$finished" ] \
    || [ "$(date -d "@$finished" +%F)" != "$(date +%F)" ]; then
    echo "当日のデータベースのバックアップ（mysql-backup.service）が成功していません"
    return
  fi
  ready=$(node_status | awk '{print $2}')
  if [ "$ready" != True ]; then
    echo "ノードが Ready ではありません"
  fi
}

wait_api() {
  local i
  for i in $(seq 1 30); do
    if kubectl get --raw /readyz > /dev/null 2>&1; then
      return 0
    fi
    sleep 10
  done
  echo "API Server が正常になりません" >&2
  return 1
}

NODE=""
DRAINED=no

# 更新を開始した後の終了処理。失敗した場合も固定を戻し、drain したノードは uncordon する
finish() {
  local rc=$?
  trap - EXIT
  set +e
  apt-mark hold "${PACKAGES[@]}" || rc=1
  if [ "$DRAINED" = yes ]; then
    wait_api
    kubectl uncordon "$NODE" || rc=1
  fi
  if [ "$rc" -eq 0 ]; then
    rm -f "$FAILED_MARKER"
  else
    echo "更新に失敗しました。原因に対処してから ${FAILED_MARKER} を削除してください" >&2
  fi
  exit "$rc"
}

if [ ! -e "$ADMIN_CONF" ]; then
  log "クラスターが構築されていないため、何もしません"
  exit 0
fi

if [ -e "$FAILED_MARKER" ] && [ "$DRY_RUN" = no ]; then
  log "前回の更新失敗の記録（${FAILED_MARKER}）があるため、更新しません"
  exit 0
fi

# パッケージ一覧の取得のみで、インストール状態は変更しない
apt_run update --error-on=any

SERVER=$(kubectl get --raw /version | sed -n 's/.*"gitVersion": *"v\([0-9.]*\).*/\1/p')
KUBELET=$(kubelet --version | sed -n 's/^Kubernetes v\([0-9.]*\).*/\1/p')
if [ -z "$SERVER" ] || [ -z "$KUBELET" ]; then
  echo "稼働中のバージョンを取得できません" >&2
  exit 1
fi
if [ "$(minor_of "$SERVER")" != "$(minor_of "$KUBELET")" ]; then
  echo "control plane（${SERVER}）と kubelet（${KUBELET}）のマイナーバージョンが異なります。マイナーバージョンの更新（CD）を完了してください" >&2
  exit 1
fi

CANDIDATES=$(apt-cache madison kubeadm | awk '{print $3}' | sed 's/-.*//')
if [ -z "$CANDIDATES" ]; then
  echo "APT リポジトリに kubeadm の候補がありません" >&2
  exit 1
fi
MINOR_REGEX="^$(minor_of "$SERVER" | sed 's/\./\\./')\\."
TARGET=$(grep -E "$MINOR_REGEX" <<< "$CANDIDATES" | sort -V | tail -n1 || true)

if [ -z "$TARGET" ]; then
  log "APT リポジトリに $(minor_of "$SERVER") 系の版がないため、何もしません（マイナーバージョンは CD で更新します）"
  exit 0
fi

log "control plane: ${SERVER} / kubelet: ${KUBELET} / 最新パッチ: ${TARGET}"
if ! older_than "$SERVER" "$TARGET" && ! older_than "$KUBELET" "$TARGET"; then
  log "最新のパッチが適用されています"
  exit 0
fi

REASON=$(abort_reason)

if [ "$DRY_RUN" = yes ]; then
  log "更新があります: ${TARGET}"
  log "中止条件: ${REASON:-該当なし}"
  [ -e "$FAILED_MARKER" ] && log "前回の更新失敗の記録（${FAILED_MARKER}）があります"
  exit 0
fi

if [ -n "$REASON" ]; then
  echo "更新を中止します: ${REASON}" >&2
  exit 1
fi

NODE=$(node_status | awk '{print $1}')

# 途中で強制終了されても記録が残るように、変更の前に作成する
mkdir -p "$STATE_DIR"
date > "$FAILED_MARKER"
trap finish EXIT

apt-mark unhold kubeadm
apt_run install -y --allow-change-held-packages "kubeadm=${TARGET}-*"

if older_than "$SERVER" "$TARGET"; then
  kubeadm upgrade plan "v${TARGET}"
  kubeadm upgrade apply "v${TARGET}" -y
fi

if older_than "$KUBELET" "$TARGET"; then
  # drain が途中で失敗してもノードは cordon されるため、先に記録する
  DRAINED=yes
  kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data --timeout=300s
  apt-mark unhold kubelet kubectl
  apt_run install -y --allow-change-held-packages "kubelet=${TARGET}-*" "kubectl=${TARGET}-*"
  systemctl daemon-reload
  systemctl restart kubelet
  wait_api
  kubectl uncordon "$NODE"
  DRAINED=no
fi

wait_api
kubectl wait --for=condition=Ready "node/$NODE" --timeout=300s
log "更新が完了しました: ${TARGET}"
