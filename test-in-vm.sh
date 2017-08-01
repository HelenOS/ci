#!/bin/bash

#
# Copyright (c) 2016 Vojtech Horky
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# - Redistributions of source code must retain the above copyright
#   notice, this list of conditions and the following disclaimer.
# - Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the distribution.
# - The name of the author may not be used to endorse or promote products
#   derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

#
# This code was originally inspired by "virtual testing lab" scripts created
# by Jan Buchar for testing his firewall implementation in HelenOS:
# https://code.launchpad.net/~teyras/hpf-virtlab/trunk
# 

xx_echo() {
    echo ">>" "$@"
}

xx_echo2() {
    echo "   -" "$@"
}

xx_debug() {
    $XX_DEBUG_ECHO "   :" "$@"
}

xx_run_debug() {
    xx_debug "$@"
    "$@"
}

xx_activity() {
    $XX_ACTIVITY_ECHO "     +" "$@"
}

xx_fatal() {
    echo "!!" "$@"
    xx_shutdown
}

## Prepares pipe to QEMU monitor.
# Feed QEMU commands to stdin of this function.
#
# Do not forget to check for return code as checking it inside pipe
# is not very useful (we cannot terminate the script from that).
#
# @param 1 Machine id.
xx_do_qemu_command_pipe() {
    socat STDIN "UNIX-CONNECT:$XX_TEMP/$1.monitor"
}

## Sends command to QEMU monitor.
# This function terminates the scenario on failure of the monitoring pipe.
#
# @param 1 Machine id.
# @param 2 Command to send.
xx_do_qemu_command() {
    xx_debug "echo '$2' | socat STDIN 'UNIX-CONNECT:$XX_TEMP/$1.monitor'"
    echo "$2" | socat STDIN "UNIX-CONNECT:$XX_TEMP/$1.monitor"
    res=$?
    if [ $res -ne 0 ]; then
        xx_shutdown
    fi
}

## Types the text to a specific machine.
#
# @param 1 Machine id.
# @param 2 Text to type.
xx_do_type() {
    ( echo "$2" | fold -w 1 | sed \
        -e 's/ /spc/' \
        -e 's/\./dot/' \
        -e 's/-/minus/' \
        -e 's/+/shift-equal/' \
        -e 's/_/shift-minus/' \
        -e 's/@/shift-2/' \
        -e 's/:/shift-semicolon/' \
        -e 's/\//slash/' \
        -e 's/=/equal/' \
        -e 's/|/shift-backslash/' \
        -e 's/\([[:upper:]]\)/shift-\L\1/' \
        -e 's/\\/backslash/' | \
        while read code; do
            xx_do_qemu_command "$1" "sendkey $code"
        done
    )
    res=$?
    if [ $res -ne 0 ]; then
        xx_shutdown
    fi
}

xx_get_var() {
    local varname="$1"
    local default="$2"
    shift 2
    local i
    for i in "$@"; do
        case $i in
            $varname=*)
                echo "$i" | cut '-d=' -f 2-
                return
                ;;
            *)
                ;;
        esac
    done
    echo "$default"
}

xx_get_def_var() {
    local i
    for i in "$@"; do
        echo "$i" | grep -v '^[a-zA-Z][a-zA-Z0-9_]*='
    done
    echo
}

xx_get_boolean_var() {
    value=`xx_get_var "$@" | tr 'A-Z' 'a-z'`
    if [ "$value" = "yes" -o "$value" = "true" ]; then
        echo "true"
    elif [ "$value" = "no" -o "$value" = "false" ]; then
        echo "false"
    else
        echo
    fi
}
    

xx_shutdown() {
    local i
    for i in $XX_KNOWN_MACHINES; do
        xx_stop_machine name="$i"
    done
    exit 1
}

xx_assert_var() {
    if [ -z "$2" ]; then
        xx_echo "Option $1 not specified or invalid, terminating."
        xx_shutdown
    fi
}    

xx_do_check_var() {
    if [ -z "$2" ]; then
        xx_fatal "Option $1 not specified with no suitable default."
    fi
    if [ -n "$3" ]; then
        if ! echo "$2" | grep -q "$3"; then
            xx_fatal "Option $1 does not match '$3' (got '$2')."
        fi
    fi
}

xx_do_compute_timeout() {
    echo $(( `date +%s` + 10 * $1 ))
}

# 
xx_start_machine() {
    local cdrom=`xx_get_var cdrom "$XX_CDROM_FILE" "$@"`
    local name=`xx_get_var name default "$@"`
    local wait_for_vterm=`xx_get_boolean_var vterm true "$@"`
    
    xx_do_check_var "xx_start_machine/name" "$name" '^[a-zA-Z][0-9a-zA-Z]*$'
    xx_do_check_var "xx_start_machine/cdrom" "$cdrom"
    
    local extra_opts=""
    if $XX_HEADLESS; then
        extra_opts="-display none"
    fi
    if $XX_USE_KVM; then
        extra_opts="$extra_opts -enable-kvm"
    fi
        
    xx_echo "Starting machine $name from $cdrom."
    
    local qemu_command=""
    if [ $XX_ARCH == "ia32" ]; then
        qemu_command=qemu-system-i386
    elif [ $XX_ARCH == "amd64" ]; then
        qemu_command=qemu-system-x86_64
    fi
    if [ -z "$qemu_command" ]; then
        xx_fatal "Unable to find proper emulator."
    fi
    
    xx_run_debug $qemu_command \
        $extra_opts \
        -device e1000,vlan=0 -net user \
        -redir udp:8080::8080 -redir udp:8081::8081 \
        -redir tcp:8080::8080 -redir tcp:8081::8081 \
        -redir tcp:2223::2223 \
        -usb \
        -m 256 \
        -daemonize -pidfile "$XX_TEMP/$name.pid" \
        -monitor "unix:$XX_TEMP/$name.monitor,server,nowait" \
        -boot d \
        -cdrom "$cdrom"
    sleep 1
    xx_do_qemu_command "$name" "sendkey ret"
    
    XX_LAST_MACHINE=$name
    
    XX_KNOWN_MACHINES="$XX_KNOWN_MACHINES $name"
    
    if $wait_for_vterm; then
        xx_echo2 "Waiting for OS to boot into GUI..."
        if ! xx_do_wait_for_text "$name" `xx_do_compute_timeout 15` "to see a few survival tips"; then
            xx_fatal "OS have not booted into a known state."
        fi
    fi
}



# 
xx_stop_machine() {
    local name=`xx_get_var name $XX_LAST_MACHINE "$@"`
    
    xx_echo "Forcefully killing machine $name."
    xx_do_qemu_command "$name" "quit"
    sleep 1
    
    if [ "$name" = "$XX_LAST_MACHINE" ]; then
        XX_LAST_MACHINE=""
    fi
}


## Wait for text to appear on machine console.
#
# @param 1 Machine id.
# @param 2 UNIX end-time (date %s + TIME_OUT).
# @param 3 Text to match.
xx_do_wait_for_text() {
    while true; do
        xx_activity "Taking screenshot, looking for '$3'."
        
        xx_do_screenshot "$1" "$XX_TEMP/$1-full.ppm" \
            "$XX_TEMP/$1-term.png" "$XX_TEMP/$1-term.txt"
        
        if grep -q "$3" <"$XX_TEMP/$1-term.txt"; then
            return 0
        fi
        
        if [ `date +%s` -gt $2 ]; then
            return 1
        fi
        
        sleep 1
    done
}

xx_assert() {
    local timeout=`xx_get_var timeout $XX_DEFAULT_TIMEOUT "$@"`
    local machine=`xx_get_var machine $XX_LAST_MACHINE "$@"`
    local error_msg=`xx_get_var error "" "$@"`
    local text=`xx_get_def_var "$@"`
    
    xx_echo "Checking that '$text' will appear on $machine within ${timeout}s."
    
    if ! xx_do_wait_for_text "$machine" `xx_do_compute_timeout $timeout` "$text"; then
        xx_fatal "Failed to recognize '$text' on $machine."
    fi
}

xx_die_on() {
    local timeout=`xx_get_var timeout $XX_DEFAULT_TIMEOUT "$@"`
    local machine=`xx_get_var machine $XX_LAST_MACHINE "$@"`
    local error_msg=`xx_get_var message "" "$@"`
    local text=`xx_get_def_var "$@"`
    
    xx_echo "Checking that '$text' will not appear on $machine within ${timeout}s."
    
    if xx_do_wait_for_text "$machine" `xx_do_compute_timeout $timeout` "$text"; then
        xx_fatal "Prohibited text '$text' spotted on $machine."
    fi    
}

xx_sleep() {
    local amount=`xx_get_def_var "$@"`
    
    xx_echo "Waiting for ${amount}s."
    sleep $amount
}


xx_cls() {
    local machine=`xx_get_var machine $XX_LAST_MACHINE "$@"`
    
    xx_echo "Clearing the screen on $machine."
    for i in `seq 1 35`; do
        xx_do_qemu_command "$machine" "sendkey ret"
    done
    sleep 1
}

xx_do_ocr_prepare() {
    convert "$1" -crop "8x16" +repage +adjoin txt:- \
        | sed -e 's|[0-9]*,[0-9]*: ([^)]*)[ ]*#\([0-9A-Fa-f]\{6\}\).*|\1|' -e 's:^#.*:@:' -e 's#000000#0#g' -e 's#FFFFFF#F#' \
        | sed -e ':a' -e 'N;s#\n##;s#^@##;/@$/{s#@$##p;d}' -e 't a'
}
    

xx_do_ocr() {
    xx_do_ocr_prepare "$1" | sed -f "$XX_MY_HOME/ocr.sed"
}

xx_do_screenshot() {
    xx_do_qemu_command "$1" "screendump $2"
    if [ -n "$3" ]; then
        # Looping as the screenshot might take some time to save
        local retries=3
        while true; do
            if convert "$2" -crop 640x480+4+24 +repage -colors 2 -monochrome "$3"; then
                break
            fi
            retries=$(( $retries - 1 ))
            if [ $retries -le 0 ]; then
                xx_fatal "Failed to convert screen to monochrome."
            fi
            sleep 1
        done
        
        if [ -n "$4" ]; then
            xx_do_ocr "$3" | paste -sd '' | fold -w 80 >"$4"
        fi
    fi
}

## Wait for text to appear on machine console.
#
# @param 1 Machine id.
# @param 2 UNIX end-time (date %s + TIME_OUT).
# @param 3 Text that shall not be matched.
# @param 4 Text that shall be matched before timeout.
# @param 5 Consider prompt as a success.
# @param 6 Check for standard Bdsh error messages.
# @retval 0 Expected text was matched.
# @retval 1 Prompt text was matched.
# @retval 2 Time-out, nothing matched.
# @retval 3 Unexpected text was matched.
# @retval 4 Standard Bdsh error message detected.
xx_do_complex_text_waiting() {
    xx_debug "waiting: $1/$2 match='$4', no-match='$3'"
    xx_debug "waiting: $1/$2 prompt_is_success=$5  check_for_bdsh_error=$6"
    
    while true; do
        xx_activity "Taking screenshot, checking for specific output."
        
        xx_do_screenshot "$1" "$XX_TEMP/$1-full.ppm" \
            "$XX_TEMP/$1-term.png" "$XX_TEMP/$1-term.txt"
        
        if [ -n "$3" ] && grep -q "$3" <"$XX_TEMP/$1-term.txt"; then
            return 3
        fi
        
        if [ -n "$4" ] && grep -q "$4" <"$XX_TEMP/$1-term.txt" ; then
            return 0
        fi
        
        if $5 && grep -q '^.*/ # _[ ]*$' <"$XX_TEMP/$1-term.txt" ; then
            return 0
        fi
        
        if $6 && grep -q -e 'Cannot spawn' -e 'Command failed' <"$XX_TEMP/$1-term.txt"; then
            return 4
        fi
        
        if [ `date +%s` -gt $2 ]; then
            return 2
        fi
        
        sleep 1
    done
}

xx_cmd() {
    local cmd=`xx_get_def_var "$@"`
    local timeout=`xx_get_var timeout $XX_DEFAULT_TIMEOUT "$@"`
    local machine=`xx_get_var machine $XX_LAST_MACHINE "$@"`
    local error_msg=`xx_get_var error "" "$@"`
    local text=`xx_get_var assert "" "$@"`
    local negtext=`xx_get_var die_on "" "$@"`
    local text_is_empty=`if [ -n "$text" ]; then echo false; else echo true; fi`
    
    xx_echo "Sending '$cmd' to $machine."
    xx_do_type "$machine" "$cmd"
    xx_do_qemu_command "$machine" "sendkey ret"
    
    
    xx_do_complex_text_waiting "$machine" `xx_do_compute_timeout $timeout` \
        "$negtext" "$text" $text_is_empty true
    local res=$?
    
    xx_debug "xx_do_complex_text_waiting = $res"
    
    case $res in
        0|1)
            return 0
            ;;
        2)
            if $text_is_empty; then
                xx_fatal "Command timed-out."
            else
                xx_fatal "Failed to match '$text'."
            fi
            ;;
        3|4)
            if [ -n "$error_msg" ]; then
                xx_fatal "$error_msg"
            else
                xx_fatal "Command failed."
            fi
            ;;
        *)
            xx_fatal "Internal error, we shall never reach this line."
            ;;
    esac
}



xx_do_print_help() {
    echo "Usage: $1 [options] scenario-file [scenarios-file ...]"
    cat <<'EOF_USAGE'
where [options] are:

--help          Print this help and exit.
--headless      Hide the screen of the virtual machine.
--root=DIR      Find HelenOS image in the source directory.
--image=FILE    File with main HelenOS image (specify --arch).
--arch=ARCH     Architecture of the image file (see --image).
--no-kvm        Do not try to run QEMU with KVM enabled.
--fail-fast      Exit with first error.
--debug         Print (a lot of) debugging messages.

EOF_USAGE
}


XX_MY_HOME=`which -- "$0" 2>/dev/null`
# Maybe, we are running Bash
[ -z "$XX_MY_HOME" ] && XX_MY_HOME=`which -- "$BASH_SOURCE" 2>/dev/null`
XX_MY_HOME=`dirname -- "$XX_MY_HOME"`

XX_DEBUG_ECHO=:
XX_ACTIVITY_ECHO=:
XX_TRAIN_OCR=false
XX_HEADLESS=false
XX_USE_KVM=true
XX_TEMP="$PWD/tmp-vm/"
XX_HELENOS_ROOT="."
XX_AUTODETECT_HELENOS=false
XX_ARCH=""
XX_CDROM_FILE=""
XX_FAIL_FAST=false

XX_KNOWN_MACHINES=""
XX_DEFAULT_TIMEOUT=5
XX_LAST_MACHINE=default


# Replace with getopt eventually.
while [ $# -gt 0 ]; do
    case "$1" in
        --headless)
            XX_HEADLESS=true
            ;;
        --train-ocr)
            XX_TRAIN_OCR=true
            ;;
        --train-ocr=*)
            XX_TRAIN_OCR=true
            XX_TRAIN_OCR_FILE=`echo "$1" | cut '-d=' -f 2-`
            ;;
        --debug)
            XX_DEBUG_ECHO=echo
            ;;
        --activity)
            XX_ACTIVITY_ECHO=echo
            ;;
        --root=*)
            XX_HELENOS_ROOT=`echo "$1" | cut '-d=' -f 2-`
            XX_AUTODETECT_HELENOS=true
            ;;
        --image=*)
            XX_CDROM_FILE=`echo "$1" | cut '-d=' -f 2-`
            XX_AUTODETECT_HELENOS=false
            ;;
        --arch=*)
            XX_ARCH=`echo "$1" | cut '-d=' -f 2-`
            XX_AUTODETECT_HELENOS=false
            ;;
        --temp=*)
            XX_TEMP=`echo "$1" | cut '-d=' -f 2-`
            ;;
        --no-kvm)
            XX_USE_KVM=false
            ;;
        --fail-fast)
            XX_FAIL_FAST=true
            ;;
        --help|-h|-?)
            xx_do_print_help "$0"
            exit 0
            ;;
        --*)
            xx_fatal "Unknown option $1."
            ;;
        *)
            break
            ;;
    esac
    shift
done

mkdir -p "$XX_TEMP"

if $XX_AUTODETECT_HELENOS; then
    if ! [ -r "$XX_HELENOS_ROOT/Makefile.config" ]; then
        xx_fatal "Cannot open $XX_HELENOS_ROOT/Makefile.config."
    fi
    XX_ARCH=`grep '^PLATFORM = ' "$XX_HELENOS_ROOT/Makefile.config" | cut '-d=' -f 2- | tr -d ' '`
    XX_CDROM_FILE=$XX_HELENOS_ROOT/`cat "$XX_HELENOS_ROOT/defaults/$XX_ARCH/output"`
fi


if $XX_TRAIN_OCR; then
    if [ -z "$XX_TRAIN_OCR_FILE" ]; then
        echo "Usage notes for --train-ocr command-line switch."
        echo
        echo "Prepare HelenOS image.iso with train-ocr.txt in its root."
        echo
        echo "Run this script with the ISO and with --train-ocr=out.sed"
        echo "where out.sed is output file with OCR commands."
        echo
        echo "If the script finishes with  no error you can replace the"
        echo "old OCR scheme (ocr.sed) with the new one in out.sed."
        echo
        exit
    fi
    
    # Set to false to debug the script below without running QEMU
    # all the time
    if true; then
        xx_start_machine name=ocr vterm=false
        xx_echo "Will display the training set on the VM screen"
        xx_echo "(this will take a while)."
        sleep 20
        xx_do_type ocr "cat train-ocr.txt"
        sleep 1
        xx_do_qemu_command ocr "sendkey ret"
        sleep 5
        xx_do_screenshot ocr "$XX_TEMP/ocr-full.ppm" "$XX_TEMP/ocr-term.png"
        xx_stop_machine
    fi
    
    xx_echo "Doing OCR..."
    xx_do_ocr_prepare "$XX_TEMP/ocr-term.png" \
        | (
        prev1_line=""
        prev2_line=""
        prev3_line=""
        counter=0
        while read current_line; do
            if [ $counter -gt 5 ]; then
                while read current_line; do
                    if ! [ "$current_line" = "$prev1_line" -o "$current_line" = "$prev2_line" ]; then
                        break
                    fi
                done
                alphabet=`sed -n 's#^\(.\)\(.\)\(\1\2\)\{4,\}##p' train-ocr.txt`
                alphabet_size=`echo "$alphabet" | wc -c`
                for i in `seq 1 $(( $alphabet_size - 1))`; do
                    symbol="`echo \"$alphabet\" | fold -w 1 | sed -n \"${i}p\" | sed 's#[*\.\&\\:\/\[]\|\]#\\\\&#g'`"
                    echo "s:$current_line:$symbol:" 
                    read current_line
                done
                echo "$current_line" | tr 'F' '0' | sed 's#.*#s:&:_:#'
                echo "$current_line" | tr '0F' '.' | sed 's#.*#s:&:?:#'
                break
            fi
            if [ "$current_line" = "$prev2_line" -a "$prev1_line" = "$prev3_line" -a "$prev1_line" != "$prev2_line" ]; then
                counter=$(( $counter + 1 ))
            else
                counter=0
            fi
            prev3_line="$prev2_line"
            prev2_line="$prev1_line"
            prev1_line="$current_line"
        done >"$XX_TRAIN_OCR_FILE"
        )
    xx_echo "New OCR scheme is in $XX_TRAIN_OCR_FILE."
    exit
fi
    

XX_RESULT_SUMMARY="$XX_TEMP/summary.$$.txt"

date '+# Execution started on %Y-%m-%d %H:%M.' >"$XX_RESULT_SUMMARY"
echo '# =======================================' >>"$XX_RESULT_SUMMARY"


# Run it
for i in "$@"; do
    echo "# Starting scenario $i..."
    (
        . $i
    )
    if [ $? -eq 0 ]; then
        res="OK"
    else
        res="FAIL"
    fi
    echo "# Scenario $i terminated, $res."
    printf '%-35s  %4s\n' "$i" "$res" >>"$XX_RESULT_SUMMARY"
    if $XX_FAIL_FAST && [ "$res" = "FAIL" ]; then
        exit 1
    fi
done


date '+# Execution finished on %Y-%m-%d %H:%M.' >>"$XX_RESULT_SUMMARY"

# Display the results.
echo

cat "$XX_RESULT_SUMMARY"
