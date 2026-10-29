#!/usr/bin/env bash
#
# lab8-subnet-tour.sh -- Computer Networks, Lab 8
#
# Copyright (c) 2026 Dr. Ronny L. Bull, Ph.D. All rights reserved.
#
# Draws the line. Given an address and a mask it prints the address and the
# mask in binary, one under the other, marks where the mask stops being ones,
# and derives the network address, the first and last usable hosts, the
# broadcast address and the host count from the bits alone.
#
# It is a CHECKER, not a calculator to lean on. Work each case by hand first,
# on paper, then run this and compare. If you run it first you will learn the
# command and not the method, and the exam is the method.
#
# READ THIS SCRIPT. Every value it prints is computed here, in shell
# arithmetic, from the same 32 bits you are working with by hand. There is no
# library doing it for you, and nothing in it you cannot follow.
#
# Usage:
#   ./lab8-subnet-tour.sh                          your own interface
#   ./lab8-subnet-tour.sh 192.168.20.130 /26       address and prefix
#   ./lab8-subnet-tour.sh 192.168.20.130 255.255.255.192
#   ./lab8-subnet-tour.sh -p A/m B/m               do two, and say whether
#                                                  they share a subnet
#
set -u

c_ok=$'\033[0;32m'; c_warn=$'\033[0;33m'; c_err=$'\033[0;31m'
c_hdr=$'\033[1;36m'; c_dim=$'\033[0;90m'; c_net=$'\033[1;34m'
c_hst=$'\033[0;33m'; c_off=$'\033[0m'

head1(){ printf '\n%s========== %s ==========%s\n' "$c_hdr" "$*" "$c_off"; }
warn() { printf '  %s[warn]%s %s\n' "$c_warn" "$c_off" "$*"; }
die()  { printf '  %s[fail]%s %s\n' "$c_err"  "$c_off" "$*"; exit 1; }

# ---------------------------------------------------------------- conversions
# An IPv4 address is one 32-bit number. Dotted quad is a display convention and
# nothing more, which is the whole point of this lab, so the first thing this
# script does is throw the dots away.
to_int() {
    local IFS=. ; local -a o=($1)
    [ "${#o[@]}" -eq 4 ] || return 1
    local n
    for n in "${o[@]}"; do
        case "$n" in ''|*[!0-9]*) return 1 ;; esac
        [ "$n" -le 255 ] || return 1
    done
    echo $(( (o[0]<<24) | (o[1]<<16) | (o[2]<<8) | o[3] ))
}

to_quad() {
    local v=$1
    printf '%d.%d.%d.%d' $(( (v>>24)&255 )) $(( (v>>16)&255 )) \
                         $(( (v>>8)&255 ))  $(( v&255 ))
}

# 32 characters, most significant bit first. No dots -- the caller inserts them
# where it wants them, because where the dots go is exactly what is at issue.
to_bits() {
    local v=$1 i out=''
    for (( i=31; i>=0; i-- )); do out+=$(( (v>>i)&1 )); done
    echo "$out"
}

# A mask is legal only if it is a run of ones followed by a run of zeros.
# 255.255.244.0 looks like a mask and is not one; this is the check that says so.
prefix_of_mask() {
    local m=$1 p=0 i
    for (( i=31; i>=0; i-- )); do
        if (( (m>>i)&1 )); then (( p++ )); else break; fi
    done
    (( m == ( p==0 ? 0 : (0xFFFFFFFF << (32-p)) & 0xFFFFFFFF ) )) || return 1
    echo "$p"
}

# ---------------------------------------------------------------- the drawing
# Prints one 32-bit row, dotted, with everything left of the boundary in one
# color and everything right of it in another. That colored seam IS the line.
row() {
    local label=$1 bits=$2 bound=$3 i
    printf '  %-9s %s' "$label" "$c_net"
    for (( i=0; i<32; i++ )); do
        (( i == bound )) && printf '%s' "$c_hst"
        printf '%s' "${bits:i:1}"
        (( (i+1) % 8 == 0 && i != 31 )) && printf '.'
    done
    printf '%s\n' "$c_off"
}

# The boundary sits between two bits, so its column is the bit column plus one
# separator for each whole octet already passed.
ruler() {
    local bound=$1
    local col=$(( bound + bound/8 ))
    printf '  %-9s %*s\n' '' $(( col+1 )) '^'
    printf '  %-9s %*s\n' '' $(( col+1 )) '|'
}

# ---------------------------------------------------------------- one case
solve() {
    local addr=$1 mask=$2
    local ai mi p

    ai=$(to_int "$addr")   || die "not an address: $addr"
    if [[ $mask == /* ]]; then
        p=${mask#/}
        case "$p" in ''|*[!0-9]*) die "not a prefix: $mask" ;; esac
        [ "$p" -le 32 ] || die "not a prefix: $mask"
        mi=$(( p==0 ? 0 : (0xFFFFFFFF << (32-p)) & 0xFFFFFFFF ))
    else
        mi=$(to_int "$mask") || die "not a mask: $mask"
        p=$(prefix_of_mask "$mi") || die \
"$mask is not a legal subnet mask -- a mask is a run of 1s then a run of 0s,
       and this one has a 0 before its last 1. Write it in binary and look."
    fi

    local net=$(( ai & mi ))
    local wild=$(( ~mi & 0xFFFFFFFF ))
    local bc=$(( net | wild ))
    local h=$(( 32 - p ))

    head1 "$addr  mask $(to_quad "$mi")  (/$p)"

    row 'address'   "$(to_bits "$ai")"  "$p"
    row 'mask'      "$(to_bits "$mi")"  "$p"
    ruler "$p"
    row 'network'   "$(to_bits "$net")" "$p"
    row 'broadcast' "$(to_bits "$bc")"  "$p"

    printf '\n  %sblue = network bits (mask 1s)   yellow = host bits (mask 0s)%s\n' \
           "$c_dim" "$c_off"

    printf '\n'
    printf '  network address    %s\n' "$(to_quad "$net")"
    if (( h >= 2 )); then
        printf '  first usable host  %s\n' "$(to_quad $(( net+1 )) )"
        printf '  last usable host   %s\n' "$(to_quad $(( bc-1 )) )"
        printf '  broadcast address  %s\n' "$(to_quad "$bc")"
        printf '  host bits          %d   usable hosts  2^%d - 2 = %d\n' \
               "$h" "$h" $(( (1<<h) - 2 ))
    elif (( h == 1 )); then
        printf '  broadcast address  %s\n' '(none -- see RFC 3021)'
        printf '  the two addresses  %s and %s\n' \
               "$(to_quad "$net")" "$(to_quad "$bc")"
        printf '  host bits          1   usable hosts  2 (point-to-point only)\n'
    else
        printf '  host bits          0   a single address, not a subnet\n'
    fi

    LAST_NET=$net
    LAST_P=$p
}

# ---------------------------------------------------------------- your machine
own_interface() {
    local addr='' mask='' cidr=''
    if command -v ip >/dev/null 2>&1; then
        # The first global IPv4 that is not loopback. Printed as a.b.c.d/nn.
        cidr=$(ip -o -4 addr show scope global 2>/dev/null \
               | awk '{print $4}' | head -1)
    elif command -v ifconfig >/dev/null 2>&1; then
        # macOS prints the mask in hex: "netmask 0xffffff00".
        addr=$(ifconfig 2>/dev/null | awk '/inet /&&$2!="127.0.0.1"{print $2; exit}')
        mask=$(ifconfig 2>/dev/null | awk '/inet /&&$2!="127.0.0.1"{print $4; exit}')
        if [[ $mask == 0x* ]]; then
            local v=$(( mask ))
            mask=$(to_quad "$v")
        fi
        [ -n "$addr" ] && cidr="$addr/$(prefix_of_mask "$(to_int "$mask")")"
    fi
    [ -n "$cidr" ] || die "could not read an interface address -- pass one on the command line"
    printf 'Reading your own interface: %s\n' "$cidr"
    solve "${cidr%%/*}" "/${cidr##*/}"
    m='This is the subnet your machine thinks it is on. Every destination'
    printf '\n  %s%s%s\n' "$c_dim" "$m" "$c_off"
    printf '  %sinside it goes out directly; everything else goes to the gateway.%s\n' "$c_dim" "$c_off"
}

# ---------------------------------------------------------------- two cases
pair() {
    local a=$1 b=$2
    [[ $a == */* && $b == */* ]] || die "-p wants two arguments of the form address/mask"
    solve "${a%%/*}" "/${a##*/}" ; local na=$LAST_NET pa=$LAST_P
    solve "${b%%/*}" "/${b##*/}" ; local nb=$LAST_NET pb=$LAST_P
    head1 'same subnet?'
    if (( na == nb && pa == pb )); then
        printf '  %sSAME%s -- both reduce to %s/%d, so the bits left of the line agree.\n' \
               "$c_ok" "$c_off" "$(to_quad "$na")" "$pa"
        printf '  Neither one needs a router to reach the other.\n'
    else
        printf '  %sDIFFERENT%s -- %s/%d and %s/%d.\n' \
               "$c_err" "$c_off" "$(to_quad "$na")" "$pa" "$(to_quad "$nb")" "$pb"
        printf '  Traffic between them has to go through a router, even if the two\n'
        printf '  machines are plugged into the same switch.\n'
    fi
}

# ---------------------------------------------------------------- go
case "${1:-}" in
    -p) shift; [ $# -eq 2 ] || die "usage: $0 -p A/mask B/mask"; pair "$1" "$2" ;;
    -h|--help)
        sed -n '3,25p' "$0" | sed 's/^# \{0,1\}//' ;;
    '') own_interface ;;
    *)  [ $# -eq 2 ] || die "usage: $0 <address> <mask-or-/prefix>"
        solve "$1" "$2" ;;
esac

printf '\n%sNow check it against the work you did by hand. If they disagree, the\n' "$c_dim"
printf 'interesting question is which one is wrong and why -- find that out\n'
printf 'before you move on.%s\n' "$c_off"
