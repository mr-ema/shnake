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

# TODO: Find a way to read input without blocking to improve performance 
# TODO: If read does not block try to implement target fps

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

###################### CONSTANTS ######################
PROGRAM="SHNAKE"
VERSION="1.0"

WHITE_CANVAS=""

SCREEN_WIDTH=$(tput cols)
SCREEN_HEIGHT=$(tput lines)
BOARD_WIDTH=$((SCREEN_WIDTH / 2))
BOARD_HEIGHT=$((SCREEN_HEIGHT / 2))

# This coordinates will center the board
START_BOARD_X=$((BOARD_WIDTH / 2))
START_BOARD_Y=$((BOARD_HEIGHT / 2))
END_BOARD_X=$((BOARD_WIDTH + START_BOARD_X))
END_BOARD_Y=$((BOARD_HEIGHT + START_BOARD_Y))

MATRIX_CHAR="."
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

direction="RIGHT"
pressed_key=""
score=0

###################### FUNCTIONS ######################
read_char() {
        # Set the terminal to raw mode to read single characters
        stty -icanon -echo
  
        # https://unix.stackexchange.com/questions/10698/timing-out-in-a-shell-script#18711
        char=$(sh -ic "exec 3>&1 2>/dev/null; { cat 1>&3; kill 0; } | { sleep $1; kill 0; }")

        echo "$char"
}

# This function draws the given text string onto a canvas represented by a string,
# starting from the specified position (start_x, start_y). The text will be inserted
# character by character at the provided coordinates, moving from left to right along
# the x-axis. The canvas is assumed to be a single string with newline escape '\n' used
# as a row separator.
#
# Parameters:
#   canvas     - The original canvas represented as a single string.
#   canvas_cols - The number of columns in the canvas.
#   str        - The text string to be drawn on the canvas.
#   start_x    - The x-coordinate (column) of the starting position for drawing the text.
#   start_y    - The y-coordinate (row) of the starting position for drawing the text.
#
# Returns:
#   The modified canvas with the text drawn at the specified position.
#
draw_text() {
        local_canvas="$1"
        local_canvas_cols="$2"
        local_str="$3"
        local_start_x="$4"
        local_start_y="$5"

        while [ -n "$local_str" ]; do
                char="${local_str%"${local_str#?}"}" # extract first char

                text_idx=$((local_start_y * (local_canvas_cols + 2) + local_start_x))
                local_canvas=$(set_char_at_index "$local_canvas" "$text_idx" "$char")

                local_str="${local_str#?}" # remove first char
                local_start_x=$((local_start_x + 1))
        done

        printf "%s" "$local_canvas"
}

# This function takes an input string, an index, and a new character, and it returns
# the input string with the character at the specified index replaced by the new character.
# If the index is out of bounds (less than 0 or greater than the length of the string),
# the original string is returned without any modifications.
#
# Parameters:
#   str         - The input string where the character will be replaced.
#   idx         - The index of the character to be replaced (0-based index).
#   new_char    - The new character to be placed at the specified index.
#
# Returns:
#   The modified string with the character at the given index replaced,
#   or the original string if the index is out of bounds.
#
set_char_at_index() {
        local_str="$1"
        local_idx="$2"
        local_new_char="$3"

        if [ "$local_idx" -ge 0 ] && [ "$local_idx" -lt ${#local_str} ]; then
                printf "%s" "$local_str" | sed "s/./${local_new_char}/$((local_idx + 1))"
        else
                printf "%s" "$local_str"
        fi
}

# This function generates a character matrix using the provided character for all elements.
# The matrix is represented as a single string, with rows separated by newline characters ("\n").
# The number of rows and columns can be controlled using the parameters.
#
# Parameters:
#   char  - The character to be used for all elements in the matrix.
#   rows  - The number of rows in the matrix.
#   cols  - The number of columns in the matrix.
#
# Returns:
#   The generated character matrix with the specified number of rows and columns,
#   where each element is represented by the provided character.
#
generate_char_matrix() {
        local_char="$1"
        local_rows="$2"
        local_cols="$3"

        local_matrix=""
        for i in $(seq 1 $((local_cols))); do
                local_matrix="${local_matrix}${local_char}"
        done

        local_row_chars="$local_matrix"
        for i in $(seq 2 $((local_rows))); do
                local_matrix="${local_matrix}\n${local_row_chars}"
        done

        printf "%s" "$local_matrix"
}

# This function inserts a smaller submatrix represented by the provided character
# into a larger matrix (canvas). The submatrix is positioned within the canvas
# starting from the specified top-left corner coordinates (start_x, start_y).
#
# Parameters:
#   matrix          - The original matrix (canvas) where the submatrix will be inserted.
#   matrix_cols     - The number of columns in the original matrix (canvas).
#   submatrix_char  - The character representing the submatrix elements.
#   start_x         - The x-coordinate (column) of the top-left corner of the submatrix.
#   start_y         - The y-coordinate (row) of the top-left corner of the submatrix.
#   end_x           - The x-coordinate (column) of the bottom-right corner of the submatrix.
#   end_y           - The y-coordinate (row) of the bottom-right corner of the submatrix.
#
# Returns:
#   The modified canvas with the submatrix inserted at the specified position.
#
insert_submatrix() {
        local_matrix="$1"
        local_matrix_cols="$2"
        local_submatrix_char="$3"
        local_start_x="$4"
        local_start_y="$5"
        local_end_x="$6"
        local_end_y="$7"

        for y in $(seq $((local_start_y)) $((local_end_y - 1))); do
                for x in $(seq $((local_start_x)) $((local_end_x - 1))); do
                        # We do (local_matrix_cols + 2) because of the newline escape '\n',
                        # which serves as a separator between rows in the matrix.
                        local_matrix_idx=$((y * (local_matrix_cols + 2) + x))
                        local_matrix=$(set_char_at_index "$local_matrix" "$local_matrix_idx" "$local_submatrix_char")
                done
        done

        printf "%s" "$local_matrix"
}

draw_game_interface() {
        score_x="$START_BOARD_X"
        score_y=$((START_BOARD_Y - 2))

        game_canvas=$(draw_text "$game_canvas" "$SCREEN_WIDTH" "Score: $score" "$score_x" "$score_y")
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
        game_canvas="$WHITE_CANVAS"
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
        game_canvas=$(set_char_at_index "$game_canvas" "$last_segment_idx" "$MATRIX_CHAR")

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
        if [ -n "$RANDOM" ]; then
                fruit_x=$((RANDOM % BOARD_WIDTH + START_BOARD_X))
                fruit_y=$((RANDOM % BOARD_HEIGHT + START_BOARD_Y))
        else
                current_time=$(date +%s%3N)

                fruit_x=$((current_time % BOARD_WIDTH + START_BOARD_X))
                fruit_y=$((current_time % BOARD_HEIGHT + START_BOARD_Y))
        fi
}

check_collition() {
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
        echo "$PROGRAM VERSION: $VERSION"
        echo ""
        echo "Generating game canvas..."
        WHITE_CANVAS=$(generate_char_matrix " " "$SCREEN_HEIGHT" "$SCREEN_WIDTH")
        echo "Game canvas generated"
        echo ""

        # Draw board
        echo "Generating game board..."
        game_canvas=$(insert_submatrix "$WHITE_CANVAS" "$SCREEN_WIDTH" "$MATRIX_CHAR" "$START_BOARD_X" "$START_BOARD_Y" "$END_BOARD_X" "$END_BOARD_Y")
        echo "Game board generated"
}
init_game

# Main loop
while true; do
        draw_game

        pressed_key=$(read_char 0.1)
        update_snake_body
        move_snake "$pressed_key"

        check_collition
done
