#!/bin/bash
# 集群通知配置
CLAB_MASTER_IP="clab-notice.lcpu.dev"
CLAB_NOTIFICATIONS_URL="http://$CLAB_MASTER_IP/cluster_notifications"
CLAB_NOTIFICATIONS_CACHE_DIR="$HOME/.cluster_notifications"
CLAB_MAX_DISPLAY_COUNT=3  # 每个通知最多显示5次
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

# 现代化的颜色和样式配置
CLAB_COLOR_RED='\033[1;31m'
CLAB_COLOR_YELLOW='\033[1;33m'
CLAB_COLOR_GREEN='\033[1;32m'
CLAB_COLOR_BLUE='\033[1;34m'
CLAB_COLOR_CYAN='\033[1;36m'
CLAB_COLOR_MAGENTA='\033[1;35m'
CLAB_COLOR_WHITE='\033[1;37m'
CLAB_COLOR_GRAY='\033[0;37m'
CLAB_COLOR_DIM='\033[2m'
CLAB_COLOR_BOLD='\033[1m'
CLAB_COLOR_UNDERLINE='\033[4m'
CLAB_COLOR_NC='\033[0m'

# 图标定义（改用ASCII字符）
ICON_CRITICAL="[!]"
ICON_IMPORTANT="[*]"
ICON_INFO="[i]"
ICON_SUCCESS="[+]"
ICON_CLOCK="[T]"
ICON_STAR="[~]"

# 获取终端宽度，设置合适的通知框宽度
TERMINAL_WIDTH=$(tput cols 2>/dev/null || echo 80)
if [[ $TERMINAL_WIDTH -lt 60 ]]; then
    TERMINAL_WIDTH=80
fi

# 设置通知框的最大宽度，让它看起来更合理
if [[ $TERMINAL_WIDTH -gt 100 ]]; then
    CONTENT_WIDTH=80  # 在宽屏上限制为80字符
elif [[ $TERMINAL_WIDTH -gt 80 ]]; then
    CONTENT_WIDTH=70  # 中等宽度终端用70字符
else
    CONTENT_WIDTH=$((TERMINAL_WIDTH - 10))  # 窄终端留10字符边距
fi

# 创建分隔线
function create_line {
    local char="${1:--}"
    local width="${2:-$CONTENT_WIDTH}"
    printf "%0.s$char" $(seq 1 "$width")
}

# 计算显示宽度 - 更准确的中文处理
function display_width {
    local text="$1"
    # 移除ANSI颜色代码
    text=$(echo "$text" | sed 's/\x1B\[[0-9;]*[JKmsu]//g')
    
    # 使用Python计算准确的显示宽度（如果可用）
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import sys
text = sys.argv[1]
width = 0
for char in text:
    # 中文字符（包括全角符号）宽度为2，ASCII字符宽度为1
    if ord(char) > 127:
        # 简单判断：Unicode码点大于127的视为宽字符
        if ord(char) >= 0x1100 and (
            ord(char) <= 0x115f or  # Hangul Jamo
            ord(char) == 0x2329 or ord(char) == 0x232a or  # Angle brackets
            (0x2e80 <= ord(char) <= 0xa4cf and ord(char) != 0x303f) or  # CJK
            (0xac00 <= ord(char) <= 0xd7a3) or  # Hangul Syllables
            (0xf900 <= ord(char) <= 0xfaff) or  # CJK Compatibility Ideographs
            (0xfe10 <= ord(char) <= 0xfe19) or  # Vertical forms
            (0xfe30 <= ord(char) <= 0xfe6f) or  # CJK Compatibility Forms
            (0xff00 <= ord(char) <= 0xff60) or  # Fullwidth Forms
            (0xffe0 <= ord(char) <= 0xffe6) or  # Fullwidth Forms
            (0x20000 <= ord(char) <= 0x2fffd) or  # CJK Extension B
            (0x30000 <= ord(char) <= 0x3fffd)     # CJK Extension C
        ):
            width += 2
        else:
            width += 1
    else:
        width += 1
print(width)
" "$text" 2>/dev/null
    else
        # 回退方案：简单的字节计数估算
        local byte_count=${#text}
        local ascii_count=$(echo "$text" | tr -d '[\200-\377]' | wc -c)
        local multi_byte_chars=$(( (byte_count - ascii_count + 2) / 3 ))  # 估算中文字符数
        echo $((ascii_count + multi_byte_chars * 2 - 1))  # -1 是因为wc -c会计算换行符
    fi
}

# 更准确的按显示宽度换行函数
function wrap_by_display_width {
    local text="$1"
    local max_width="$2"
    
    # 如果有Python，使用Python处理
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import sys
text = sys.argv[1]
max_width = int(sys.argv[2])

def char_width(char):
    if ord(char) > 127:
        if ord(char) >= 0x1100 and (
            ord(char) <= 0x115f or
            ord(char) == 0x2329 or ord(char) == 0x232a or
            (0x2e80 <= ord(char) <= 0xa4cf and ord(char) != 0x303f) or
            (0xac00 <= ord(char) <= 0xd7a3) or
            (0xf900 <= ord(char) <= 0xfaff) or
            (0xfe10 <= ord(char) <= 0xfe19) or
            (0xfe30 <= ord(char) <= 0xfe6f) or
            (0xff00 <= ord(char) <= 0xff60) or
            (0xffe0 <= ord(char) <= 0xffe6) or
            (0x20000 <= ord(char) <= 0x2fffd) or
            (0x30000 <= ord(char) <= 0x3fffd)
        ):
            return 2
        else:
            return 1
    else:
        return 1

lines = text.split('\n')
for line in lines:
    if not line.strip():
        print('')
        continue
    
    current_line = ''
    current_width = 0
    
    for char in line:
        char_w = char_width(char)
        if current_width + char_w > max_width:
            if current_line:
                print(current_line)
            current_line = char
            current_width = char_w
        else:
            current_line += char
            current_width += char_w
    
    if current_line:
        print(current_line)
" "$text" "$max_width" 2>/dev/null
    else
        # 回退方案：使用简化的bash实现
        echo "$text" | while IFS= read -r line; do
            if [[ -z "$line" ]]; then
                echo ""
                continue
            fi
            
            local current_width=$(display_width "$line")
            if [[ $current_width -le $max_width ]]; then
                echo "$line"
                continue
            fi
            
            # 简单分割：按空格分割后重新组合
            local words=()
            local current_line=""
            
            # 如果行太长且没有空格，强制按字符分割
            if [[ "$line" != *" "* ]]; then
                local i=0
                local line_length=${#line}
                local current_line=""
                
                while [[ $i -lt $line_length ]]; do
                    local char="${line:$i:1}"
                    local test_line="${current_line}${char}"
                    local test_width=$(display_width "$test_line")
                    
                    if [[ $test_width -gt $max_width ]]; then
                        if [[ -n "$current_line" ]]; then
                            echo "$current_line"
                        fi
                        current_line="$char"
                    else
                        current_line="$test_line"
                    fi
                    i=$((i + 1))
                done
                
                if [[ -n "$current_line" ]]; then
                    echo "$current_line"
                fi
            else
                # 按空格分割
                read -ra words <<< "$line"
                current_line=""
                
                for word in "${words[@]}"; do
                    local test_line=""
                    if [[ -z "$current_line" ]]; then
                        test_line="$word"
                    else
                        test_line="$current_line $word"
                    fi
                    
                    local test_width=$(display_width "$test_line")
                    if [[ $test_width -gt $max_width ]]; then
                        if [[ -n "$current_line" ]]; then
                            echo "$current_line"
                        fi
                        current_line="$word"
                    else
                        current_line="$test_line"
                    fi
                done
                
                if [[ -n "$current_line" ]]; then
                    echo "$current_line"
                fi
            fi
        done
    fi
}

# 创建居中文本
function center_text {
    local text="$1"
    local width="${2:-$CONTENT_WIDTH}"
    local text_width=$(display_width "$text")
    local padding=$(( (width - text_width + 1) / 2 ))
    if [[ $padding -lt 0 ]]; then padding=0; fi
    printf "%*s%s\n" "$padding" "" "$text"
}

# 显示美化的通知框
function show_notification_box {
    local title="$1"
    local content="$2"
    local severity="$3"
    local expiry_date="$4"
    local icon=""
    local color=""
    
    # 根据严重程度设置颜色和图标
    case "$severity" in
        critical)
            color=$CLAB_COLOR_RED
            icon="[!]"
            ;;
        important)
            color=$CLAB_COLOR_YELLOW
            icon="[*]"
            ;;
        info)
            color=$CLAB_COLOR_CYAN
            icon="[i]"
            ;;
        success)
            color=$CLAB_COLOR_GREEN
            icon="[+]"
            ;;
        *)
            color=$CLAB_COLOR_BLUE
            icon="[~]"
            ;;
    esac
    
    echo ""
    # 顶部边框
    echo -e "${color}+$(create_line -)+"
    
    # 标题行
    local title_text="$icon $title"
    local title_width=$(display_width "$title_text")
    # 需要减去左边的空格（1个字符）和右边框前的空格位置
    local title_padding=$((CONTENT_WIDTH - title_width - 2))
    if [[ $title_padding -lt 0 ]]; then title_padding=0; fi
    echo -e "${color}|${CLAB_COLOR_BOLD}${CLAB_COLOR_WHITE} $title_text$(printf "%*s" "$title_padding" " ") ${color}|${CLAB_COLOR_NC}"
    
    # 分隔线
    echo -e "${color}+$(create_line -)+"
    
    # 内容
    if [[ -n "$content" && "$content" != "null" ]]; then
        echo -e "${color}|$(printf "%*s" "$CONTENT_WIDTH" " ")|${CLAB_COLOR_NC}"
        # 使用改进的换行函数处理内容
        wrap_by_display_width "$content" $((CONTENT_WIDTH - 4)) | while IFS= read -r line; do
            local line_width=$(display_width "$line")
            local line_padding=$((CONTENT_WIDTH - line_width - 2))
            if [[ $line_padding -lt 0 ]]; then line_padding=0; fi
            echo -e "${color}|${CLAB_COLOR_NC} $line$(printf "%*s" "$line_padding" " ") ${color}|${CLAB_COLOR_NC}"
        done
        echo -e "${color}|$(printf "%*s" "$CONTENT_WIDTH" " ")|${CLAB_COLOR_NC}"
    fi
    
    # 过期时间（如果有）
    if [[ -n "$expiry_date" && "$expiry_date" != "null" ]]; then
        echo -e "${color}+$(create_line -)+"
        local expiry_text="[T] 过期时间: $expiry_date"
        local expiry_width=$(display_width "$expiry_text")
        local expiry_padding=$((CONTENT_WIDTH - expiry_width - 2))
        if [[ $expiry_padding -lt 0 ]]; then expiry_padding=0; fi
        echo -e "${color}|${CLAB_COLOR_DIM} $expiry_text$(printf "%*s" "$expiry_padding" " ") ${color}|${CLAB_COLOR_NC}"
    fi
    
    # 底部边框
    echo -e "${color}+$(create_line -)+"
    echo ""
}

function show_clab_logo {
    echo ""
    echo -e "${CLAB_COLOR_BLUE}┌─────────────────────────────────────────────────────────────────┐${CLAB_COLOR_NC}"
    echo -e "${CLAB_COLOR_BLUE}│${CLAB_COLOR_NC}                                                                 ${CLAB_COLOR_BLUE}│${CLAB_COLOR_NC}"
    echo -e "${CLAB_COLOR_BLUE}│${CLAB_COLOR_BLUE}               ███████╗${CLAB_COLOR_BLUE} ██╗     ${CLAB_COLOR_BLUE} █████╗${CLAB_COLOR_BLUE} ██████╗ ${CLAB_COLOR_BLUE}                 │${CLAB_COLOR_NC}"
    echo -e "${CLAB_COLOR_BLUE}│${CLAB_COLOR_BLUE}               ██╔════╝${CLAB_COLOR_BLUE} ██║    ${CLAB_COLOR_BLUE} ██╔══██╗${CLAB_COLOR_BLUE}██╔══██╗${CLAB_COLOR_BLUE}                 │${CLAB_COLOR_NC}"
    echo -e "${CLAB_COLOR_BLUE}│${CLAB_COLOR_BLUE}               ██║     ${CLAB_COLOR_BLUE} ██║    ${CLAB_COLOR_BLUE} ███████║${CLAB_COLOR_BLUE}██████╔╝${CLAB_COLOR_BLUE}                 │${CLAB_COLOR_NC}"
    echo -e "${CLAB_COLOR_BLUE}│${CLAB_COLOR_BLUE}               ██║     ${CLAB_COLOR_BLUE} ██║    ${CLAB_COLOR_BLUE} ██╔══██║${CLAB_COLOR_BLUE}██╔══██╗${CLAB_COLOR_BLUE}                 │${CLAB_COLOR_NC}"
    echo -e "${CLAB_COLOR_BLUE}│${CLAB_COLOR_BLUE}               ╚██████╗${CLAB_COLOR_BLUE} ███████╗${CLAB_COLOR_BLUE}██║  ██║${CLAB_COLOR_BLUE}██████╔╝${CLAB_COLOR_BLUE}                 │${CLAB_COLOR_NC}"
    echo -e "${CLAB_COLOR_BLUE}│${CLAB_COLOR_BLUE}                ╚═════╝${CLAB_COLOR_BLUE} ╚══════╝${CLAB_COLOR_BLUE}╚═╝  ╚═╝${CLAB_COLOR_BLUE}╚═════╝ ${CLAB_COLOR_BLUE}                 │${CLAB_COLOR_NC}"
    echo -e "${CLAB_COLOR_BLUE}│${CLAB_COLOR_NC}                                                                 ${CLAB_COLOR_BLUE}│${CLAB_COLOR_NC}"
    echo -e "${CLAB_COLOR_BLUE}│${CLAB_COLOR_MAGENTA}                    ⚡ Powered By LCPU ⚡${CLAB_COLOR_BLUE}                        │${CLAB_COLOR_NC}"
    echo -e "${CLAB_COLOR_BLUE}│${CLAB_COLOR_NC}                                                                 ${CLAB_COLOR_BLUE}│${CLAB_COLOR_NC}"
    echo -e "${CLAB_COLOR_BLUE}└─────────────────────────────────────────────────────────────────┘${CLAB_COLOR_NC}"
    echo ""
}
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
        show_clab_logo
        local content=$(cat "$motd_file")
        show_notification_box "$title" "$content" "$severity"
        
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
    local is_manual_execution="${1:-false}"
    local index_file="$CLAB_NOTIFICATIONS_CACHE_DIR/clab-notify.json"
    if ! is_cache_fresh "$index_file" "$CLAB_CACHE_TTL"; then
        # 获取通知索引
        index_file="$CLAB_NOTIFICATIONS_CACHE_DIR/clab-notify.json"
        curl -s --connect-timeout 1 -o "$index_file" "$CLAB_NOTIFICATIONS_URL/clab-notify.json" 2>/dev/null
    fi
    
    # 确保显示计数文件存在且是有效的JSON
    if [[ ! -f "$CLAB_NOTIFICATIONS_CACHE_DIR/display_counts.json" ]]; then
        echo "{}" > "$CLAB_NOTIFICATIONS_CACHE_DIR/display_counts.json"
    fi
    
    # 检查index文件是否存在且有效
    if [[ ! -f "$index_file" ]]; then
        # 只在手动执行时显示连接失败信息
        if [[ "$is_manual_execution" == "true" ]]; then
            echo -e "${CLAB_COLOR_DIM}[!] 无法连接到通知服务器${CLAB_COLOR_NC}"
        fi
        return 0
    fi
    
    # 检查JSON文件是否有效
    if ! jq empty "$index_file" 2>/dev/null; then
        # 只在手动执行时显示格式错误信息
        if [[ "$is_manual_execution" == "true" ]]; then
            echo -e "${CLAB_COLOR_DIM}[!] 通知数据格式错误${CLAB_COLOR_NC}"
        fi
        return 0
    fi
    
    # 读取通知列表
    mapfile -t notices < <(jq -r '.notices[]?' "$index_file" 2>/dev/null)
    
    # 如果没有通知
    if [[ ${#notices[@]} -eq 0 ]]; then
        # 只在手动执行时显示"没有通知"信息
        if [[ "$is_manual_execution" == "true" ]]; then
            echo -e "${CLAB_COLOR_DIM}[i] 当前没有新的集群通知${CLAB_COLOR_NC}"
        fi
        return 0
    fi
    
    local notification_count=0
    local processed_count=0
    
    for notice_id in "${notices[@]}"; do
        # 跳过空的notice_id
        if [[ -z "$notice_id" || "$notice_id" == "null" ]]; then
            continue
        fi
        
        processed_count=$((processed_count + 1))
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
            show_notification_box "$title" "$content" "$severity" "$expiry_date"
            notification_count=$((notification_count + 1))
            
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
    
    # 如果处理了通知但没有显示任何内容
    if [[ $processed_count -gt 0 && $notification_count -eq 0 ]]; then
        # 只在手动执行时显示过期信息
        if [[ "$is_manual_execution" == "true" ]]; then
            echo -e "${CLAB_COLOR_DIM}[i] 所有通知都已过期或达到显示次数限制${CLAB_COLOR_NC}"
        fi
    fi
    
    # 如果有多个通知，显示一个友好的结束提示
    if [[ $notification_count -gt 1 ]]; then
        echo -e "${CLAB_COLOR_DIM}--- 共显示 $notification_count 条通知 ---${CLAB_COLOR_NC}"
        echo ""
    fi
}

# 检测脚本执行方式
function is_sourced {
    [[ "${BASH_SOURCE[0]}" != "${0}" ]]
}

# 主函数调用 - 确保Logo总是最先显示
function main {
    local is_manual_execution=false
    
    # 检查是否为手动执行
    if ! is_sourced; then
        is_manual_execution=true
    fi
    
    # 然后显示初始通知
    show_init_notification
    
    # 最后尝试显示集群通知
    show_cluster_notifications "$is_manual_execution"
}

# 调用主函数
main