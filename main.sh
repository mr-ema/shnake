#!/bin/sh

# -----------------------------------------------------------------------------
# Zero-Clause BSD
#
# Permission to use, copy, modify, and/or distribute this software for
# any purpose with or without fee is hereby granted.
# 
# THE SOFTWARE IS PROVIDED “AS IS” AND THE AUTHOR DISCLAIMS ALL
# WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE
# FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY
# DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN
# AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT
# OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
# -----------------------------------------------------------------------------

#ORIGINAL_IFS="$IFS"
saved_settings="$(stty -g)" # Save current terminal settings to restore them later

cleanup() {
        tput cnorm
        stty "$saved_settings"
        exit 0
}

trap cleanup EXIT
trap cleanup QUIT
trap cleanup INT 
tput civis

#VERSION="1.0"
#PROGRAM="shnake"

#FPS=60
#FRAME_DURATION=$($bc -I <<< "1 / $FPS")

SCREEN_WIDTH=$(tput cols)
SCREEN_HEIGHT=$(tput lines)
GRID_WIDTH=$((SCREEN_WIDTH - 1))
GRID_HEIGHT=$((SCREEN_HEIGHT - 1))

MATRIX_CHAR="."
HEAD_CHAR="O"
TAIL_CHAR="o"
FRUIT_CHAR="F"

LEFT_KEY="h"
RIGHT_KEY="l"
UP_KEY="k"
DOWN_KEY="j"

# Variables
snake_x=0
snake_y=0
fruit_x=0
fruit_y=0
tail_x=0
tail_y=0

# since POSIX does not specify arrays, the body will be represent as a string
# from head to tail example: [xy: "x0y1 x1y0 x2y3 x5y5"]
snake_body_xy=""

direction="RIGHT"
matrix=""
pressed_key=""
#score=0

replace_char() {
        str="$1"
        idx="$2"
        new_char="$3"

        if [ "$idx" -ge 0 ] && [ "$idx" -lt ${#str} ]; then
                printf "%s" "$str" | sed "s/./${new_char}/$((idx + 1))"
        else
                printf "%s" "$str"
        fi
}

update_tail() {
        # remove last segment and then update tail
        snake_body_xy=$(echo "$snake_tail_xy" |  awk -F 'x' 'NF>1{sub(/x[^x]*$/,"")}1')
        snake_body_xy="x${snake_x}y${snake_y} $snake_tail_xy"
}

draw_snake() {
        str="$snake_body_xy"
        # Draw snake body 
        while [ -n "$str" ]; do
                case "$str" in
                        *" "*)
                                tail_xy="${str%%' '*}"
                        ;;
                        *)
                                tail_xy="$str"
                        ;;
                esac

                tail_x=$(echo "$tail_xy" | cut -d'x' -f2 | cut -d'y' -f1)
                tail_y=$(echo "$tail_xy" | cut -d'y' -f2 | cut -d'x' -f1)

                # We do 'GRID_WIDTH + 2' because of the new line escape '\n'
                tail_idx=$((tail_y * (GRID_WIDTH + 2) + tail_x))
                matrix=$(replace_char "$matrix" "$tail_idx" "$TAIL_CHAR")

                str=${str#*" "}
        done

        head_idx=$((snake_y * (GRID_WIDTH + 2) + snake_x))
        matrix=$(replace_char "$matrix" "$head_idx" "$HEAD_CHAR")
}

draw_game() {
        # Draw matrix one time
        if [ -z "$matrix" ]; then
                for _ in $(seq 0 $((GRID_HEIGHT - 1))); do
                        for _ in $(seq 0 $((GRID_WIDTH - 1))); do
                                matrix="${matrix}$MATRIX_CHAR"
                        done
                        matrix="${matrix}\n"
                done
        else
                # Remove the last body segment to simulate movement
                last_segment_idx=$((tail_y * (GRID_WIDTH + 2) + tail_x))
                matrix=$(replace_char "$matrix" "$last_segment_idx" "$MATRIX_CHAR")
        fi

        # Draw fruit
        fruit_idx=$((fruit_y * (GRID_WIDTH + 2) + fruit_x))
        matrix=$(replace_char "$matrix" "$fruit_idx" "$FRUIT_CHAR")

        draw_snake
        printf -- "$matrix"
}

move_snake() {
        pressed_key=$1

        case "$pressed_key" in
                "$LEFT_KEY") direction="LEFT";;
                "$UP_KEY") direction="UP";;
                "$RIGHT_KEY") direction="RIGHT";;
                "$DOWN_KEY") direction="DOWN";;
        esac

        case "${direction}" in
                "UP") snake_y=$((snake_y - 1));;
                "DOWN") snake_y=$((snake_y + 1));;
                "LEFT") snake_x=$((snake_x - 1));;
                "RIGHT") snake_x=$((snake_x + 1));;
        esac
}

generate_fruit() {
        if [ -n "$RANDOM" ]; then
                fruit_x=$((RANDOM % GRID_WIDTH))
                fruit_y=$((RANDOM % GRID_HEIGHT))
        else
                current_time=$(date +%s%3N)

                fruit_x=$((current_time % GRID_WIDTH))
                fruit_y=$((current_time % GRID_HEIGHT))
        fi
}

check_collition() {
        if [ "$snake_x" -lt 0 ] || [ "$snake_x" -ge "$GRID_WIDTH" ] || [ "$snake_y" -lt 0 ] || [ "$snake_y" -ge "$GRID_HEIGHT" ]; then
                echo "GAME OVER"
                exit 0
        elif [ "$snake_x" -eq "$fruit_x" ] && [ "$snake_y" -eq "$fruit_y" ]; then
                snake_body_xy="x${snake_x}y${snake_y} $snake_tail_xy"
                generate_fruit
        fi
}

# TODO: Try to use a sub-shell for the whole live of the program to read input without blocking.
#       If not possible fix forced exit ( ctr-c does not work correctly )
read_char() {
        # Set the terminal to raw mode to read single characters
        stty -icanon -echo
  
        # https://unix.stackexchange.com/questions/10698/timing-out-in-a-shell-script#18711
        char=$(sh -ic "exec 3>&1 2>/dev/null; { cat 1>&3; kill 0; } | { sleep $1; kill 0; }")

        echo "$char"
}

# Main loop
generate_fruit # Spawn the fruit in a random position
while true; do
        draw_game

        check_collition

        pressed_key=$(read_char 0.1)
        move_snake "$pressed_key"
        update_tail
done