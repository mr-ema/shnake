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

########################### Source Files ##########################
source "./utils.sh"
source "./bot.sh"

SAVED_TTY_SETTINGS="$(stty -g)" # Save current terminal settings to restore them later

cleanup() {
        tput cnorm
        stty "$SAVED_TTY_SETTINGS"
        exit 0
}

trap cleanup EXIT
trap cleanup QUIT
trap cleanup INT 
tput civis

###################### DEFAULT VALUES ######################
PROGRAM="SHNAKE"
VERSION="1.0"

BLANK_CANVAS=""
TARGET_FPS=60
FRAME_INTERVAL=$(echo "scale=3; 1.0 / $TARGET_FPS" | bc)

SCREEN_WIDTH=$(tput cols)
SCREEN_HEIGHT=$(tput lines)
BOARD_WIDTH=$((SCREEN_WIDTH / 2))
BOARD_HEIGHT=$((SCREEN_HEIGHT / 2))

# This coordinates will center the board
START_BOARD_X=$((BOARD_WIDTH / 2))
START_BOARD_Y=$((BOARD_HEIGHT / 2))
END_BOARD_X=$((BOARD_WIDTH + START_BOARD_X))
END_BOARD_Y=$((BOARD_HEIGHT + START_BOARD_Y))

BOARD_CHAR="."
HEAD_CHAR="O"
TAIL_CHAR="o"
FRUIT_CHAR="F"

# Controls
LEFT_KEY="h"
RIGHT_KEY="l"
UP_KEY="k"
DOWN_KEY="j"

###################### VARIABLES ######################
game_canvas=""

snake_x="$START_BOARD_X"
snake_y="$START_BOARD_Y"
fruit_x=0
fruit_y=0
tail_x="$START_BOARD_X"
tail_y="$START_BOARD_Y"

# since POSIX does not specify arrays, the body will be represent as a string
# from head to tail example: [xy: "x0y1 x1y0 x2y3 x5y5"]
snake_body_xy=""

direction="RIGHT" # "RIGHT"|"LEFT"|"UP"|"DOWN"
pressed_key=""
score=0

###################### OVERWRITE DEFAULT VALUES ######################
while [ $# -gt 0 ]; do
        case "$1" in
                --set-target-fps=*)
                        TARGET_FPS="${1#*=}"
                        FRAME_INTERVAL=$(echo "scale=3; 1.0 / $TARGET_FPS" | bc)
                        shift 1
                ;;
                *)
                        echo "Unknown option: $1"
                        exit 1
                ;;
        esac
done

###################### FUNCTIONS ######################
draw_game_interface() {
        local_score_x="$START_BOARD_X"
        local_score_y=$((START_BOARD_Y - 2))

        game_canvas=$(draw_text "$game_canvas" "$SCREEN_WIDTH" "Score: $score" "$local_score_x" "$local_score_y")
}

update_snake_body() {
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

                # We only redraw the node next to the head
                tail_idx=$((tail_y * (SCREEN_WIDTH + 2) + tail_x))
                game_canvas=$(set_char_at_index "$game_canvas" "$tail_idx" "$TAIL_CHAR")

                # Set tail position to the last node
                tail_xy=$(echo "$snake_body_xy" | awk '{print $NF}')

                tail_x=$(echo "$tail_xy" | cut -d'x' -f2 | cut -d'y' -f1)
                tail_y=$(echo "$tail_xy" | cut -d'y' -f2 | cut -d'x' -f1)
        fi

        head_idx=$((snake_y * (SCREEN_WIDTH + 2) + snake_x))
        game_canvas=$(set_char_at_index "$game_canvas" "$head_idx" "$HEAD_CHAR")
}

draw_game_over() {
        game_canvas="$BLANK_CANVAS"
        local_msg="GAME OVER"
        local_msg_len=${#local_msg}
        center_x=$(( (BOARD_WIDTH / 2 + START_BOARD_X) - (local_msg_len / 2) - 1 ))
        center_y=$((BOARD_HEIGHT / 2 + START_BOARD_Y))

        game_canvas=$(draw_text "$game_canvas" "$SCREEN_WIDTH" "$local_msg" "$center_x" "$center_y")
        printf -- "$game_canvas"
}

draw_game() {
        # Simulate movement
        last_segment_idx=$((tail_y * (SCREEN_WIDTH + 2) + tail_x))
        game_canvas=$(set_char_at_index "$game_canvas" "$last_segment_idx" "$BOARD_CHAR")

        # Draw fruit
        fruit_idx=$((fruit_y * (SCREEN_WIDTH + 2) + fruit_x))
        game_canvas=$(set_char_at_index "$game_canvas" "$fruit_idx" "$FRUIT_CHAR")

        draw_snake
        draw_game_interface
        printf -- "$game_canvas"
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
        fruit_x=$(( $(random) % BOARD_WIDTH + START_BOARD_X ))
        fruit_y=$(( $(random) % BOARD_HEIGHT + START_BOARD_Y ))
}

check_collision() {
        local_snake_xy="x${snake_x}y${snake_y}"

        if [ "$snake_x" -lt "$START_BOARD_X" ] || [ "$snake_x" -ge "$END_BOARD_X" ] ||
           [ "$snake_y" -lt "$START_BOARD_Y" ] || [ "$snake_y" -ge "$END_BOARD_Y" ] ||
           test "${snake_body_xy#*$local_snake_xy}" != "${snake_body_xy}"; then
                draw_game_over
                exit 0
        elif [ "$snake_x" -eq "$fruit_x" ] && [ "$snake_y" -eq "$fruit_y" ]; then
                snake_body_xy="x${snake_x}y${snake_y} $snake_body_xy"
                score=$((score + 1))
                generate_fruit
        fi
}

init_game() {
        generate_fruit # Spawn the fruit in a random position

        # init canvas
        echo "$PROGRAM v$VERSION"
        echo ""
        echo "Generating game canvas..."
        BLANK_CANVAS=$(generate_char_matrix " " "$SCREEN_HEIGHT" "$SCREEN_WIDTH")
        echo "Game canvas generated"
        echo ""

        # Draw board
        echo "Generating game board..."
        game_canvas=$(insert_submatrix "$BLANK_CANVAS" "$SCREEN_WIDTH" "$BOARD_CHAR" "$START_BOARD_X" "$START_BOARD_Y" "$END_BOARD_X" "$END_BOARD_Y")
        echo "Game board generated"
}

player_mainloop() {
        while true; do
                start_time=$(get_current_seconds)

                draw_game
                pressed_key=$(read_char)
                update_snake_body
                move_snake "$pressed_key"
                check_collision

                end_time=$(get_current_seconds)
                elapsed_time=$(echo "$end_time - $start_time" | bc)

                # Calculate the time to sleep to achieve the target FPS
                sleep_time=$(echo "$FRAME_INTERVAL - $elapsed_time" | bc)
                if [ "$(echo "$sleep_time > 0" | bc)" -eq 1 ]; then
                        sleep "$sleep_time"
                fi
        done
}

bot_main_loop() {
        while true; do
                start_time=$(get_current_seconds)

                draw_game
                update_snake_body
                b0000
                move_bot
                check_collision

                end_time=$(get_current_seconds)
                elapsed_time=$(echo "$end_time - $start_time" | bc)

                # Calculate the time to sleep to achieve the target FPS
                sleep_time=$(echo "$FRAME_INTERVAL - $elapsed_time" | bc)
                if [ "$(echo "$sleep_time > 0" | bc)" -eq 1 ]; then
                        sleep "$sleep_time"
                fi
        done
}

################################# MAIN LOOP #################################
init_game
bot_main_loop
