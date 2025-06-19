#!/bin/bash
# 集群通知配置
CLAB_MASTER_IP="clab-notice.lcpu.dev"
CLAB_NOTIFICATIONS_URL="http://$CLAB_MASTER_IP/cluster_notifications"
CLAB_NOTIFICATIONS_CACHE_DIR="$HOME/.cluster_notifications"
CLAB_MAX_DISPLAY_COUNT=5  # 每个通知最多显示5次
CLAB_MAX_AGE_DAYS=14
CLAB_CACHE_TTL=43200  # 缓存TTL为12h

function is_cache_fresh {
    local file="$1"
    local ttl="$2"
    
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    local file_time=$(stat -c %Y "$file" 2>/dev/null || echo 0)
    local current_time=$(date +%s)
    local age=$((current_time - file_time))
    
    [[ $age -lt $ttl ]]
}

# 创建缓存目录
mkdir -p "$CLAB_NOTIFICATIONS_CACHE_DIR/notices"
# 确保display_counts.json存在并是有效的JSON
if [[ ! -f "$CLAB_NOTIFICATIONS_CACHE_DIR/display_counts.json" ]]; then
    echo "{}" > "$CLAB_NOTIFICATIONS_CACHE_DIR/display_counts.json"
fi

# 显示通知颜色配置
CLAB_COLOR_RED='\033[0;31m'
CLAB_COLOR_YELLOW='\033[0;33m'
CLAB_COLOR_GREEN='\033[0;32m'
CLAB_COLOR_BLUE='\033[0;34m'
CLAB_COLOR_NC='\033[0m' # No Color

# 显示初始通知
function show_init_notification {
    local motd_file="/usr/share/clab/motd"
    local config_file="/usr/share/clab/init-notification.json"
    
    # 检查文件是否存在
    if [[ ! -f "$motd_file" ]] || [[ ! -f "$config_file" ]]; then
        return 0
    fi
    
    # 读取配置
    local title=$(jq -r '.title' "$config_file" 2>/dev/null || echo "CLab 初始通知")
    local max_count=$(jq -r '.max_display_count' "$config_file" 2>/dev/null || echo "10")
    local severity=$(jq -r '.severity' "$config_file" 2>/dev/null || echo "info")
    
    # 检查显示次数
    local init_key="init-notification"
    local display_count=$(jq -r ".[\"$init_key\"] // 0" "$CLAB_NOTIFICATIONS_CACHE_DIR/display_counts.json" 2>/dev/null || echo "0")
    
    if [[ $display_count -lt $max_count ]]; then
        # 设置颜色
        case "$severity" in
            critical)
                color=$CLAB_COLOR_RED
                ;;
            important)
                color=$CLAB_COLOR_YELLOW
                ;;
            info)
                color=$CLAB_COLOR_BLUE
                ;;
            *)
                color=$CLAB_COLOR_GREEN
                ;;
        esac
        
        # 显示初始通知
        echo -e "\n${color}========== CLab通知 ==========${CLAB_COLOR_NC}"
        echo -e "${color}标题:${CLAB_COLOR_NC} $title"
        echo -e "${color}内容:${CLAB_COLOR_NC}"
        cat "$motd_file"
        echo -e "${color}============================${CLAB_COLOR_NC}\n"
        
        # 更新显示计数
        display_count=$((display_count + 1))
        
        tmp_file=$(mktemp)
        jq --arg id "$init_key" --arg count "$display_count" '.[$id] = ($count|tonumber)' \
           "$CLAB_NOTIFICATIONS_CACHE_DIR/display_counts.json" > "$tmp_file" 2>/dev/null
           
        if [[ -s "$tmp_file" ]]; then
            mv "$tmp_file" "$CLAB_NOTIFICATIONS_CACHE_DIR/display_counts.json"
        else
            rm "$tmp_file"
            echo "{\"$init_key\": $display_count}" > "$CLAB_NOTIFICATIONS_CACHE_DIR/display_counts.json"
        fi
    fi
}

# 获取并显示通知
function show_cluster_notifications {
    local index_file="$CLAB_NOTIFICATIONS_CACHE_DIR/clab-notify.json"
    if ! is_cache_fresh "$index_file" "$CLAB_CACHE_TTL"; then
        # 获取通知索引
        index_file="$CLAB_NOTIFICATIONS_CACHE_DIR/clab-notify.json"
        curl -s --connect-timeout 1 -o "$index_file" "$CLAB_NOTIFICATIONS_URL/clab-notify.json" 2>/dev/null
    fi
    
    if [[ ! -f "$index_file" ]]; then
        return 0
    fi
    
    # 确保显示计数文件存在且是有效的JSON
    if [[ ! -f "$CLAB_NOTIFICATIONS_CACHE_DIR/display_counts.json" ]]; then
        echo "{}" > "$CLAB_NOTIFICATIONS_CACHE_DIR/display_counts.json"
    fi
    
    # 读取通知列表
    mapfile -t notices < <(jq -r '.notices[]' "$index_file" 2>/dev/null)
    
    for notice_id in "${notices[@]}"; do
        # 获取通知文件
        notice_file="$CLAB_NOTIFICATIONS_CACHE_DIR/notices/$notice_id.json"
        curl -s -o "$notice_file" "$CLAB_NOTIFICATIONS_URL/$notice_id.json" 2>/dev/null
        
        if [[ ! -f "$notice_file" ]]; then
            continue
        fi
        
        # 解析通知内容
        title=$(jq -r '.title' "$notice_file")
        content=$(jq -r '.content' "$notice_file")
        severity=$(jq -r '.severity' "$notice_file")
        expiry_date=$(jq -r '.expiry_date' "$notice_file")
        
        # 检查是否过期
        current_date=$(date +%Y-%m-%d)
        if [[ "$expiry_date" < "$current_date" ]]; then
            rm -f "$notice_file"
            continue
        fi
        
        # 检查通知创建日期是否太早
        created_date=$(jq -r '.created_date' "$notice_file")
        days_old=$(( ( $(date -d "$current_date" +%s) - $(date -d "$created_date" +%s) ) / 86400 ))
        if [[ $days_old -gt $CLAB_MAX_AGE_DAYS ]]; then
            continue
        fi
        
        # 检查显示次数
        display_count=$(jq -r ".[\"$notice_id\"] // 0" "$CLAB_NOTIFICATIONS_CACHE_DIR/display_counts.json")
        
        if [[ $display_count -lt $CLAB_MAX_DISPLAY_COUNT ]]; then
            # 显示通知
            case "$severity" in
                critical)
                    color=$CLAB_COLOR_RED
                    ;;
                important)
                    color=$CLAB_COLOR_YELLOW
                    ;;
                info)
                    color=$CLAB_COLOR_BLUE
                    ;;
                *)
                    color=$CLAB_COLOR_GREEN
                    ;;
            esac
            
            echo -e "\n${color}========== CLab通知 ==========${CLAB_COLOR_NC}"
            echo -e "${color}标题:${CLAB_COLOR_NC} $title"
            echo -e "${color}内容:${CLAB_COLOR_NC} $content"
            echo -e "${color}过期日期:${CLAB_COLOR_NC} $expiry_date"
            echo -e "${color}============================${CLAB_COLOR_NC}\n"
            
            display_count=$((display_count + 1))
            
            tmp_file=$(mktemp)
            jq --arg id "$notice_id" --arg count "$display_count" '.[$id] = ($count|tonumber)' \
               "$CLAB_NOTIFICATIONS_CACHE_DIR/display_counts.json" > "$tmp_file"
               
            if [[ -s "$tmp_file" ]]; then
                mv "$tmp_file" "$CLAB_NOTIFICATIONS_CACHE_DIR/display_counts.json"
            else
                rm "$tmp_file"
                echo "{\"$notice_id\": $display_count}" > "$CLAB_NOTIFICATIONS_CACHE_DIR/display_counts.json"
            fi
        fi
    done
}

show_init_notification
show_cluster_notifications
