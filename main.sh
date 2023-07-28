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

# TODO(future me): Clean the messy code and rename things like (replace_char) to (replace_char_at_index)

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
GRID_WIDTH=$((SCREEN_WIDTH / 2))
GRID_HEIGHT=$((SCREEN_HEIGHT / 2))
WHITE_CANVAS=""

# This coordinates will center the board
START_BOARD_X=$((GRID_WIDTH / 2))
START_BOARD_Y=$((GRID_HEIGHT / 2))
END_BOARD_X=$((GRID_WIDTH + START_BOARD_X))
END_BOARD_Y=$((GRID_HEIGHT + START_BOARD_Y))

MATRIX_CHAR="."
HEAD_CHAR="O"
TAIL_CHAR="o"
FRUIT_CHAR="F"

LEFT_KEY="h"
RIGHT_KEY="l"
UP_KEY="k"
DOWN_KEY="j"

# Variables
snake_x="$START_BOARD_X"
snake_y="$START_BOARD_Y"
fruit_x=0
fruit_y=0
tail_x="$START_BOARD_X"
tail_y="$START_BOARD_Y"
score_x="$START_BOARD_X"
score_y=$((START_BOARD_Y - 2))

# since POSIX does not specify arrays, the body will be represent as a string
# from head to tail example: [xy: "x0y1 x1y0 x2y3 x5y5"]
snake_body_xy=""

direction="RIGHT"
matrix=""
pressed_key=""
score=0

# TODO: Try to use a sub-shell for the whole live of the program to read input without blocking.
#       If not possible fix forced exit ( ctr-c does not work correctly )
read_char() {
        # Set the terminal to raw mode to read single characters
        stty -icanon -echo
  
        # https://unix.stackexchange.com/questions/10698/timing-out-in-a-shell-script#18711
        char=$(sh -ic "exec 3>&1 2>/dev/null; { cat 1>&3; kill 0; } | { sleep $1; kill 0; }")

        echo "$char"
}

draw_text() {
        local_canvas="$1"
        str="$2"
        local_x="$3"
        local_y="$4"

        while [ -n "$str" ]; do
                char="${str%"${str#?}"}" # extract first char

                text_idx=$((local_y * (SCREEN_WIDTH + 2) + local_x))
                local_canvas=$(replace_char "$local_canvas" "$text_idx" "$char")

                str="${str#?}" # remove first char
                local_x=$((local_x + 1))
        done

        printf "%s" "$local_canvas"
}

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

init_canvas() {
        for _ in $(seq 0 $((SCREEN_HEIGHT - 1))); do
                for _ in $(seq 0 $((SCREEN_WIDTH - 1))); do
                        WHITE_CANVAS="${WHITE_CANVAS} "
                done

                WHITE_CANVAS="${WHITE_CANVAS}\n"
        done
}

draw_centered_matrix() {
        matrix="$WHITE_CANVAS"
        for y in $(seq $((START_BOARD_Y)) $((END_BOARD_Y - 1))); do
                for x in $(seq $((START_BOARD_X)) $((END_BOARD_X - 1))); do
                        matrix_idx=$((y * (SCREEN_WIDTH + 2) + x))
                        matrix=$(replace_char "$matrix" "$matrix_idx" "$MATRIX_CHAR")
                done
        done
}

draw_interface() {
        matrix=$(draw_text "$matrix" "Score: $score" "$score_x" "$score_y")
}

update_body() {
        # remove last segment and then update tail
        if [ -n "$snake_body_xy" ]; then
                snake_body_xy=$(echo "$snake_body_xy" | awk -F 'x' 'NF>1{sub(/x[^x]*$/,"")}1')
                snake_body_xy="x${snake_x}y${snake_y} $snake_body_xy"
        else
                # keep track of the previous position of the head
                # while there is not body
                tail_x="$snake_x"
                tail_y="$snake_y"
        fi
}

draw_snake() {
        # Draw snake body
        if [ -n "$snake_body_xy" ]; then
                tail_xy=${snake_body_xy%%" "*}

                tail_x=$(echo "$tail_xy" | cut -d'x' -f2 | cut -d'y' -f1)
                tail_y=$(echo "$tail_xy" | cut -d'y' -f2 | cut -d'x' -f1)

                # We do 'GRID_WIDTH + 2' because of the new line escape '\n'
                tail_idx=$((tail_y * (SCREEN_WIDTH + 2) + tail_x))
                matrix=$(replace_char "$matrix" "$tail_idx" "$TAIL_CHAR")

                tail_xy=$(echo "$snake_body_xy" | awk '{print $NF}')

                tail_x=$(echo "$tail_xy" | cut -d'x' -f2 | cut -d'y' -f1)
                tail_y=$(echo "$tail_xy" | cut -d'y' -f2 | cut -d'x' -f1)
        fi

        head_idx=$((snake_y * (SCREEN_WIDTH + 2) + snake_x))
        matrix=$(replace_char "$matrix" "$head_idx" "$HEAD_CHAR")
}

draw_game_over() {
        matrix="$WHITE_CANVAS"
        local_msg="GAME OVER"
        local_msg_len=${#local_msg}
        center_x=$(( (GRID_WIDTH / 2 + START_BOARD_X) - (local_msg_len / 2) - 1 ))
        center_y=$((GRID_HEIGHT / 2 + START_BOARD_Y))

        matrix=$(draw_text "$matrix" "$local_msg" "$center_x" "$center_y")
        printf -- "$matrix"
}

draw_game() {
        # Simulate movement
        last_segment_idx=$((tail_y * (SCREEN_WIDTH + 2) + tail_x))
        matrix=$(replace_char "$matrix" "$last_segment_idx" "$MATRIX_CHAR")

        # Draw fruit
        fruit_idx=$((fruit_y * (SCREEN_WIDTH + 2) + fruit_x))
        matrix=$(replace_char "$matrix" "$fruit_idx" "$FRUIT_CHAR")

        draw_snake
        draw_interface
        printf -- "$matrix"
}

move_snake() {
        pressed_key=$1

        case "$pressed_key" in
                "$LEFT_KEY")
                        if [ "$direction" != "RIGHT" ]; then
                                direction="LEFT"
                        fi
                ;;
                "$RIGHT_KEY")
                        if [ "$direction" != "LEFT" ]; then
                                direction="RIGHT"
                        fi
                ;;
                "$UP_KEY")
                        if [ "$direction" != "DOWN" ]; then
                                direction="UP"
                        fi
                ;;
                "$DOWN_KEY")
                        if [ "$direction" != "UP" ]; then
                                direction="DOWN"
                        fi
                ;;
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
                fruit_x=$((RANDOM % GRID_WIDTH + START_BOARD_X))
                fruit_y=$((RANDOM % GRID_HEIGHT + START_BOARD_Y))
        else
                current_time=$(date +%s%3N)

                fruit_x=$((current_time % GRID_WIDTH + START_BOARD_X))
                fruit_y=$((current_time % GRID_HEIGHT + START_BOARD_Y))
        fi
}

check_collition() {
        local_snake_xy="x${snake_x}y${snake_y}"

        if [ "$snake_x" -lt "$START_BOARD_X" ] || [ "$snake_x" -ge "$END_BOARD_X" ] || [ "$snake_y" -lt "$START_BOARD_Y" ] || [ "$snake_y" -ge "$END_BOARD_Y" ]; then
                draw_game_over
                exit 0
        elif test "${snake_body_xy#*$local_snake_xy}" != "${snake_body_xy}"; then
                draw_game_over
                exit 0
        elif [ "$snake_x" -eq "$fruit_x" ] && [ "$snake_y" -eq "$fruit_y" ]; then
                snake_body_xy="x${snake_x}y${snake_y} $snake_body_xy"
                score=$((score + 1))
                generate_fruit
        fi
}

init_game() {
        echo " Generating game canvas..."
        generate_fruit # Spawn the fruit in a random position
        init_canvas
        draw_centered_matrix
}
init_game

# Main loop
while true; do
        draw_game

        pressed_key=$(read_char 0.1)
        update_body
        move_snake "$pressed_key"

        check_collition
done
