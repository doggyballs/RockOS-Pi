#!/bin/sh
# RockOS build cache maintenance.
#
#   ./scripts/ccache-maint.sh status   show current cache size and stats
#   ./scripts/ccache-maint.sh cap 12G  set the max cache size (default 12G)
#   ./scripts/ccache-maint.sh clean    empty the cache entirely
#
# Buildroot keeps its ccache at $HOME/.buildroot-ccache (outside the build
# tree, so it survives wiping output/). ccache evicts least-recently-used
# entries automatically once the cap is reached, so setting the cap once is
# all the "monitoring" this needs.

CCACHE_DIR="${BR2_CCACHE_DIR:-$HOME/.buildroot-ccache}"
CCACHE="$(command -v ccache || echo /home/agent/doggyballs/RockOS/buildroot-rpi5/output/host/bin/ccache)"

if [ ! -x "$CCACHE" ] && [ ! -x "$(command -v ccache)" ]; then
    echo "ccache not found yet (it is built during the build). Run again after a build."
    exit 1
fi

case "${1:-status}" in
    status)
        echo "== ccache dir =="
        du -sh "$CCACHE_DIR" 2>/dev/null || echo "(empty — no cache yet)"
        echo
        echo "== ccache stats =="
        CCACHE_DIR="$CCACHE_DIR" "$CCACHE" -s 2>/dev/null || echo "(no stats yet)"
        echo
        echo "== configured max size =="
        CCACHE_DIR="$CCACHE_DIR" "$CCACHE" --get-config max_size 2>/dev/null || echo "(unset)"
        ;;
    cap)
        SIZE="${2:-12G}"
        mkdir -p "$CCACHE_DIR"
        CCACHE_DIR="$CCACHE_DIR" "$CCACHE" --set-config max_size="$SIZE"
        echo "cache max_size set to $SIZE in $CCACHE_DIR"
        ;;
    clean)
        CCACHE_DIR="$CCACHE_DIR" "$CCACHE" -C
        echo "cache cleared"
        ;;
    *)
        echo "usage: $0 {status|cap [SIZE]|clean}" >&2
        exit 1
        ;;
esac
