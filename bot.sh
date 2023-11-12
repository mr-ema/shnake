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

############################ [ SOURCE FILES ] ############################
source "./utils.sh"

############################# [ VARIABLES ] ##############################
VISION_POWER=2

############################# [ FUNCTIONS ] ##############################

wall_proximity() {
        case "$direction" in
                "RIGHT")
                        echo "$((END_BOARD_X - snake_x))"
                ;;
                "LEFT")
                        echo "$((snake_x - START_BOARD_X))"
                ;;
                "UP")
                        echo "$((snake_y - START_BOARD_Y))"
                ;;
                "DOWN")
                        echo "$((END_BOARD_Y - snake_y))"
                ;;
        esac
}

look_around() {
        local_bot_pos="$snake_x$snake_y"

        # Since we working with a matrix we will return
        # a matrix of the surrended area based on our vision power

        #
        # ******w
        # ***x**w
        # wwwwwww
}

move_bot() {
        case "${direction}" in
                "UP") snake_y=$((snake_y - 1));;
                "DOWN") snake_y=$((snake_y + 1));;
                "LEFT") snake_x=$((snake_x - 1));;
                "RIGHT") snake_x=$((snake_x + 1));;
        esac
}

################################## [ Bots ] ##################################
# TODO: Create some kinda metadata for bot like bot name. And print it in the game canvas

# Example Bot
b0000() {
        local_bot_name="TONTOIDE"

        # Square silly movement
        if [ "$direction" = "RIGHT" ] && [ "$snake_x" -ge "$((END_BOARD_X - 1))" ]; then
                direction="DOWN"
        elif [ "$direction" = "DOWN" ] && [ "$snake_y" -ge "$((END_BOARD_Y - 1))" ]; then
                direction="LEFT"
        elif [ "$direction" = "LEFT" ] && [ "$snake_x" -le "$((START_BOARD_X + 1))" ]; then
                direction="UP"
        elif [ "$direction" = "UP" ] && [ "$snake_y" -le "$((START_BOARD_Y + 1))" ]; then
                direction="RIGHT"
        fi

        echo "[$local_bot_name] (Direction: $direction)"
}

#b0001() {}
