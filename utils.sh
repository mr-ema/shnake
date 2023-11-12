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

# This function retrieves the current time in seconds since midnight.
#
# Returns:
#   The total number of seconds from midnight to the current time.
#
get_current_seconds() {
        local_hour=$(date +%H)
        local_minute=$(date +%M)
        local_seconds=$(date +%S)

        # Preserve leading zeros for hour and minute components
        local_hour="${local_hour#0}"
        local_minute="${local_minute#0}"

        if [ "$local_hour" -lt 1 ]; then
                local_hour="12"
        fi

        local_total_seconds=$(echo "($local_hour * 3600) + ($local_minute * 60) + $local_seconds" | bc)

        echo "$local_total_seconds"
}

# This function reads a single character from the user input without requiring Enter to be pressed.
#
# Returns:
#   The single character read from the user input.
#
read_char() {
        # Set the terminal read single characters
        stty -icanon -echo min 0 time 0
  
        char=$(dd bs=1 count=1 2>/dev/null)

        echo "$char"
}

# This function draws the given text string onto a canvas represented by a string,
# starting from the specified position (start_x, start_y). The text will be inserted
# character by character at the provided coordinates, moving from left to right along
# the x-axis. The canvas is assumed to be a single string with newline escape '\n' used
# as a row separator.
#
# Parameters:
#   canvas      - The original canvas represented as a single string.
#   canvas_cols - The number of columns in the canvas.
#   str         - The text string to be drawn on the canvas.
#   start_x     - The x-coordinate (column) of the starting position for drawing the text.
#   start_y     - The y-coordinate (row) of the starting position for drawing the text.
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

# This function extracts the character at a specified index from a given string.
#
# Parameters:
#   index - The index of the character to be extracted (0-based index).
#   string - The input string from which the character will be extracted.
#
# Returns:
#   The character at the specified index in the input string.
#
get_char_at_index() {
        local_index="$1"
        shift
        local_string="$@"

        # Use 'sed' to extract the character at the specified index
        echo "$local_string" | sed 's/^.\{'$local_index'\}\(.\).*$/\1/'
}

#  This function checks if the $RANDOM variable is defined. If $RANDOM is available
#  (which is typically the case in POSIX-compliant shells), it prints a random number
#  between 0 and 32767. If $RANDOM is not available, it prints the current seconds
#  from the system clock, providing a non-cryptographic source of randomness.
#
# Return:
#   The function echoes the generated random number.
#
random() {
        if [ -n "$RANDOM" ]; then
                echo "$RANDOM"
        else
                echo "$(date +%S)"
        fi
}

#  This function generates a random number within the specified range [min_value, max_value].
#  It uses $RANDOM if available, or falls back to using current seconds if $RANDOM is not defined.
#
# Parameters:
#   min_value - The minimum value of the desired range (inclusive).
#   max_value - The maximum value of the desired range (inclusive).
#
# Return:
#   The function echoes the generated random number.
#
random_range() {
        min_value="$1"
        max_value="$2"

        # Generate a random number in the range [min_value, max_value]
        range=$((max_value - min_value + 1))

        if [ "$range" -eq 0 ]; then
                range=1
        fi

        random_number=$(( $(random) % range + min_value ))
        echo "$random_number"
}
