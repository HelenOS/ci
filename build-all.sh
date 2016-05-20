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

msg1() {
    echo "=>" "$@" >&2
}

msg2() {
    echo "   ->" "$@" >&2
}

__get_config() {
    grep '^[ \t]*'"$2" "$1" \
        | tail -n 1 \
        | cut '-d=' -f 2 \
        | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//'
}

# get_config FILENAME VARIABLE DEFAULT
get_config() {
    __get_config_result=`__get_config "$1" "$2"`
    if [ -z "$__get_config_result" ]; then
        echo "$3"
    else
        echo "$__get_config_result"
    fi
}


report_init() {
    (
        echo '<?xml version="1.0"?>'
        NOW=`date -u '+%Y-%m-%dT%H:%M:%SZ'`
        echo -n "<build date=\"$NOW\""
        [ -n "$1" ] && echo -n " number=\"$1\""
        echo ">"
    ) >$MY_TEMP/out/result.xml
    START_TIME_UNIX=`date '+%s'`
}

report_done() {
    END_TIME_UNIX=`date '+%s'`
    (
        DURATION=$(( $END_TIME_UNIX - $START_TIME_UNIX ))
        echo "<buildinfo duration=\"$DURATION\" />"
        echo '</build>'
    ) >>$MY_TEMP/out/result.xml
}

xml_escape() {
    sed -e 's#[&]#\&amp;#g' -e 's#[<]#\&lt;#g' -e 's#[>]#\&gt;#g' -e 's#"#\&quot;#g'
}

report_result() {
    while ! mkdir "$MY_TEMP/report.lock" 2>/dev/null; do
        sleep 1
    done
    (
    local tagname
    tagname="$2"
    echo "<$tagname"
    if [ $1 -eq 0 ]; then
        echo "    result=\"ok\""
    elif [ $1 -eq -1 ]; then
        echo "    result=\"skip\""
    else
        echo "    result=\"fail\""
    fi
    local logfile
    logfile="$3"
    shift 3
    local i
    local key
    local value
    for i in "$@"; do
        key=`echo "$i" | cut '-d=' -f 1`
        value=`echo "$i" | cut '-d=' -f 2-`
        echo "    $key=\"$value\""
    done
    echo ">"
    if [ -e "$MY_TEMP/out/$logfile" ]; then
        echo "<log>"
        tail -n $XML_LOG_LINES "$MY_TEMP/out/$logfile" | xml_escape | sed -e 's#.*#<logline>&</logline>#'
        echo "</log>"
    fi
    echo "</$tagname>"
    ) >>$MY_TEMP/out/result.xml
    rmdir "$MY_TEMP/report.lock"
}


tasks_init() {
    __TASK_DIR=$MY_TEMP/task-locks
    mkdir "$__TASK_DIR"
}

task_echo() {
    while ! mkdir "$MY_TEMP/task.echo" 2>/dev/null; do
        :
    done
    echo "$@"
    rmdir "$MY_TEMP/task.echo"
}

task_count_running() {
    ls "$__TASK_DIR"/*.running 2>/dev/null | wc -l
}

task_wait_for() {
    for __TASK_DEP in "$@"; do
        while ! [ -f "$__TASK_DIR/$__TASK_DEP.done" ]; do
            sleep $TASK_SLEEP
        done
    done
}

# task_start NAME "TITLE" [ WAIT_FOR_TASK [ WAIT_FOR_TASK [ ... ] ] ]
task_start() {
    if ! [ -z "$__TASK_MINE" ]; then
         echo "Two tasks inside one shell!!!" >&2
         exit 1
    fi
    __TASK_MINE="$1"
    __TASK_NAME="$2"
    shift 2
    
    task_wait_for "$@"
    

    __TASK_NUMBER=1
    while ! mkdir "$__TASK_DIR/$__TASK_NUMBER.run" 2>/dev/null; do
        __TASK_NUMBER=$(( $__TASK_NUMBER + 1 ))
        if [ $__TASK_NUMBER -gt $MAX_TASKS ]; then
            sleep $TASK_SLEEP
            __TASK_NUMBER=1
        fi
    done
    
    # echo "task_start($__TASK_MINE)"
    task_echo "       $__TASK_NAME"
}

task_end() {
    # echo "task_end($__TASK_MINE)"
    task_echo "[done] $__TASK_NAME"
    touch "$__TASK_DIR/$__TASK_MINE.done"
    #rm -f "$__TASK_DIR/$__TASK_MINE.running"
    rmdir "$__TASK_DIR/$__TASK_NUMBER.run"
}

tasks_barrier() {
    wait
}

tasks_done() {
    wait
}


do_checkout() {
    (
        task_start "checkout.$1" "Checking-out repository from $2."
        (
            if [ -z "$2" ]; then
                echo "No repository given for $1."
                exit 1
            elif echo "$2" | grep -q '^bzr:'; then
                bzr branch "$2" "$MY_TEMP/$1" || exit 1
            else
                cp -R "$2" "$MY_TEMP/$1" || exit 1
            fi
        ) &>"$MY_TEMP/out/checkout-$1.log"
        RC=$?
        
        report_result $RC "checkout" "checkout-$1.log" "repository=$2"
        
        task_end
    )
}

get_image_file() {
    # Hack for ARM32
    if [ `echo $1 | cut '-d/' -f 1` = "arm32" ]; then
        if [ "$1" = "arm32/integratorcp" ]; then
            echo "image.boot"
        else
            echo "uImage.bin"
        fi
    elif [ "$1" = "sparc32/leon3" ]; then
        echo "uImage.bin"
    else
        cat $MY_TEMP/mainline/defaults/`echo $1 | cut '-d/' -f 1`/output 2>/dev/null
    fi
}

get_output_image_file() {
    __tmp_image_arch_esc=`echo $1 | tr '/' '-'`
    echo "${__tmp_image_arch_esc}/helenos-${__tmp_image_arch_esc}$2.`get_image_file $1 | cut '-d.' -f 2`"
}

is_testable_architecture() {
    echo " $TESTABLE_ARCHITECTURES " | tr '\t' ' ' | grep -q " $1 "
}

create_coastline_conf() {
    (
        echo "root = $3"
        # Workaround for malta-be where UARCH is mips32eb
        if [ "$2" = "mips32/malta-be" ]; then
            echo "arch = mips32eb"
        else
            echo "arch =" `echo $2 | cut '-d/' -f 1`
        fi
        echo "machine =" `echo $2 | cut '-d/' -f 2`
        [ -n "$4" ] && echo "sources = $4"
        echo "parallel = 1"
    ) > "$1/hsct.conf"
}

get_needed_harbours_for_scenario() {
    cat "scenarios/$1" 2>/dev/null | tr '\t' ' ' \
        | sed -n 's/^[ ]*#[ ]*@needs[ ]\+//p' \
        | tr ' ' '\n' \
        | grep -v '^$' \
        | sort \
        | paste '-sd '
}

hash_harbours() {
    echo "$1" | md5sum - | cut -c 1-32
}

show_help() {
    cat <<EOF_HELP
HelenOS master build script :-)
Usage: $0 [options]

  -h  --help
         Display this help and exit.
  -c  --config=FILE
         Read configuration from FILE.
  -d DIR
         Build directory (the directory will be removed!).
  --helenos-repository=URI
         Clone main HelenOS sources from URI.
         Default is bzr://helenos.org/mainline.
  --coastline-repository=URI
         Clone Coastline sources from URI.
         Default is bzr://helenos.org/coastline.
  -j  --jobs=NUMBER
         Maximum number of concurrent jobs (this is for global tasks,
         individual Makefiles are run with -j1).
         Default is number of cores as listed in /proc/cpuinfo.
  -i  --build-number=NUMBER
         Build number (e.g. from CI software such as Jenkins).
         Default is 1.
  -a  --attic=DIR
         Where to store merged results. Useful for RSS generation.
         Default is empty, meaning no merging would be done.

EOF_HELP
}





#
#
# Read configuration
#
#
HELENOS_REPO="bzr://helenos.org/mainline"
COASTLINE_REPO="bzr://helenos.org/coastline"
ARCHITECTURES="all"
HARBOURS="all"
SCENARIOS="all"
MAX_TASKS=""
TASK_SLEEP=1
MY_TEMP="/var/tmp/helenos-ci"
BUILD_NUMBER="1"
ATTIC_DIR=""
TESTABLE_ARCHITECTURES="ia32 amd64"
XML_LOG_LINES="20"
TEST_USE_KVM=true


MY_OPTS="-o hc:j:i:a:d: -l help,config:,jobs:,build-number:,attic:,helenos-repository:,coastline-repository:,no-kvm"
getopt -Q $MY_OPTS -- "$@" || exit 2
eval set -- `getopt -q $MY_OPTS -- "$@"`

NEXT_IS_CONFIG_FILE=false
CONFIG_FILE=""
for OPT in "$@"; do
    if $NEXT_IS_CONFIG_FILE; then
        CONFIG_FILE="$OPT"
        NEXT_IS_CONFIG_FILE=false
    fi
    if [ "$OPT" = "--" ]; then
        break
    fi
    if [ "$OPT" = "--config" -o "$OPT" = "-c" ]; then
        NEXT_IS_CONFIG_FILE=true
    fi
done

if [ -n "$CONFIG_FILE" ]; then
    if ! [ -e "$CONFIG_FILE" ]; then
        echo "Error: cannot read from configuration file $CONFIG_FILE!"
        exit 1
    fi

    HELENOS_REPO=`get_config "$CONFIG_FILE" helenos "$HELENOS_REPO"`
    COASTLINE_REPO=`get_config "$CONFIG_FILE" coastline "$COASTLINE_REPO"`
    
    ARCHITECTURES=`get_config "$CONFIG_FILE" architectures "$ARCHITECTURES"`
    HARBOURS=`get_config "$CONFIG_FILE" harbours "$HARBOURS"`
    SCENARIOS=`get_config "$CONFIG_FILE" scenarios "$SCENARIOS"`
    
    MAX_TASKS=`get_config "$CONFIG_FILE" tasks ""`
fi


while ! [ "$1" = "--" ]; do
    case "$1" in
        -c|--config)
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -j|--jobs)
            MAX_TASKS="$2"
            shift
            ;;
        -i|--build-number)
            BUILD_NUMBER="$2"
            shift
            ;;
        -a|--attic)
            ATTIC_DIR="$2"
            shift
            ;;
        -d)
            MY_TEMP="$2"
            if ! echo "$MY_TEMP" | grep -q '^/'; then
                MY_TEMP="$PWD/$MY_TEMP"
            fi
            shift
            ;;
        --helenos-repository)
            HELENOS_REPO="$2"
            shift
            ;;
        --coastline-repository)
            COASTLINE_REPO="$2"
            shift
            ;;
        --no-kvm)
            TEST_USE_KVM=false
            ;;
        *)
            exit 1
            ;;
    esac
    shift
done

if ! echo "$MAX_TASKS" | grep -q '^[1-9][0-9]*$'; then
    MAX_TASKS=""
fi

if [ -z "$MAX_TASKS" ]; then
    MAX_TASKS=`cat /proc/cpuinfo 2>/dev/null | grep '^processor' | wc -l`
    [ -z "$MAX_TASKS" ] && MAX_TASKS=1
fi





#
#
# Preparations
#
#
rm -rf $MY_TEMP
mkdir $MY_TEMP
mkdir $MY_TEMP/build
mkdir $MY_TEMP/out
mkdir $MY_TEMP/mirror

tasks_init

report_init "$BUILD_NUMBER"





#
#
# Check-out and populate with all harbours and architectures (when needed)
#
#
do_checkout mainline "$HELENOS_REPO" &
do_checkout coastline "$COASTLINE_REPO" &

tasks_barrier

if ! [ -e "$MY_TEMP/mainline/HelenOS.config" ]; then
    ARCHITECTURES=" "
fi

if ! [ -e "$MY_TEMP/coastline/hsct.sh" ]; then
    HARBOURS=" "
fi

if [ "$ARCHITECTURES" = "all" ]; then
	ARCH_DIRS=`find $MY_TEMP/mainline/defaults/ -name Makefile.config | sed 's/^.*\/defaults\/\(.*\)\/Makefile.config/\1/' | sort`
	ARCHITECTURES=""
	for ARCH in $ARCH_DIRS; do
	    IS_REAL_ARCH=true
	    for ARCH2 in $ARCH_DIRS; do
	        if [ -n "`echo $ARCH2 | grep \"^$ARCH\/.*\"`" ]; then
	            IS_REAL_ARCH=false
	        fi
	    done
	    $IS_REAL_ARCH && ARCHITECTURES="$ARCHITECTURES $ARCH"
	done
fi

if [ "$HARBOURS" = "all" ]; then
    HARBOURS=`ls $MY_TEMP/coastline/[a-zA-Z]*/HARBOUR | sed 's#.*/\([^/]*\)/HARBOUR$#\1#'`
fi

if [ "$SCENARIOS" = "all" ]; then
    SCENARIOS=`find scenarios/ -name '*.test' -and -not -name 'dummy_*.test' | cut '-d/' -f 2-`
fi





#
#
# Detect harbour dependencies and reorder them correctly.
#
#

echo -n "">$MY_TEMP/out/harbour-check.log
HARBOURS_SELF_CHECK_RC=0
# Export dependencies to HARBOUR_DEPS_{harbour_name}
for harbour in $HARBOURS; do
    deps=`( cd $MY_TEMP/coastline/$harbour/; . ./HARBOUR ; echo $shiptugs) 2>>$MY_TEMP/out/harbour-check.log`
    deps2=""
    for d in $deps; do
        for h in $HARBOURS; do
            [ "$h" = "$d" ] && deps2="$deps2 $d"
        done
    done
    eval export HARBOUR_DEPS_$harbour="\"$deps2\""
done
if [ `wc -l <$MY_TEMP/out/harbour-check.log` -gt 0 ]; then
    HARBOURS_SELF_CHECK_RC=1
fi


# Determine the correct ordering
ALL_HARBOURS_CORRECT_ORDER=""
HARBOURS_NOT_RESOLVED="$HARBOURS"

while [ -n "$HARBOURS_NOT_RESOLVED" ]; do
    not_resolved_yet=""
    sed_remove="-e s:x:x:"
    found_one=false
    for harbour in $HARBOURS_NOT_RESOLVED; do
        deps=`eval echo \\$HARBOUR_DEPS_$harbour`
        if [ -z "$deps" ]; then
            ALL_HARBOURS_CORRECT_ORDER="$ALL_HARBOURS_CORRECT_ORDER $harbour";
            sed_remove="$sed_remove -e s:$harbour::g"
            found_one=true
        else
            not_resolved_yet="$not_resolved_yet $harbour";
        fi
    done
    for harbour in $HARBOURS; do
        deps=`eval echo \\$HARBOUR_DEPS_$harbour | sed $sed_remove`
        eval HARBOUR_DEPS_$harbour="\"$deps\""
    done
    HARBOURS_NOT_RESOLVED="$not_resolved_yet"
    if ! $found_one; then
        (
            echo "ERROR: found circular dependency between harbours"
        ) &>>$MY_TEMP/out/harbour-check.log
        HARBOURS_SELF_CHECK_RC=1
        HARBOURS_NOT_RESOLVED=""
        ALL_HARBOURS_CORRECT_ORDER="$HARBOURS"
    fi
done

HARBOURS="$ALL_HARBOURS_CORRECT_ORDER"
report_result $HARBOURS_SELF_CHECK_RC "harbour-check" "harbour-check.log"




#
#
# Fetch the tarballs of individual harbours
#
#

create_coastline_conf "$MY_TEMP/mirror" "ia32" "$MY_TEMP/mainline"

mkdir $MY_TEMP/out/fetch
for HAR in $HARBOURS; do
    (
        task_start "harbour-fetch.$HAR" "Fetching sources for $HAR."
    
        (
            cd $MY_TEMP/mirror
            $MY_TEMP/coastline/hsct.sh fetch $HAR
        ) &>$MY_TEMP/out/fetch/$HAR.log
        RC=$?
        
        report_result $RC "harbour-fetch" "fetch/$HAR.log" "package=$HAR"
    
        task_end
    ) &
done





#
#
# Build HelenOS and its harbours for each architecture
#
#

for ARCH in $ARCHITECTURES; do
    ARCH_ESC=`echo $ARCH | tr '/' '-'`
    ARCH_BASE=`echo $ARCH | cut '-d/' -f 1`
    ARCH_MACH=`echo $ARCH | cut '-d/' -f 2`
    BUILD_DIR="$MY_TEMP/build/$ARCH_ESC"
    
    mkdir "$MY_TEMP/out/$ARCH_ESC"
    mkdir "$BUILD_DIR"
    
    OUT_IMAGE_FILE=`get_output_image_file $ARCH`
    
    # Build HelenOS
    (
        task_start "helenos.$ARCH_ESC" "Building HelenOS for $ARCH."
        
        IMAGE_FILE=`get_image_file $ARCH`
        
       
        (
            cd "$BUILD_DIR"
            cp -R $MY_TEMP/mainline helenos-build
            (
                cd helenos-build
                make PROFILE=$ARCH HANDS_OFF=y || exit 1
            ) || exit 1
            if [ -n "$IMAGE_FILE" ]; then
                cp "helenos-build/$IMAGE_FILE" "$MY_TEMP/out/$OUT_IMAGE_FILE" || exit 1
            fi
        ) &>$MY_TEMP/out/$ARCH_ESC/helenos-build.log
        RC=$?
        
        if [ $RC -eq 0 ]; then
            report_result $RC "helenos-build" "$ARCH_ESC/helenos-build.log" \
                "arch=$ARCH" \
                "image=$OUT_IMAGE_FILE"
        else
            report_result $RC "helenos-build" "$ARCH_ESC/helenos-build.log" \
                "arch=$ARCH"
        fi
        
        task_end
    ) &
    
    
    # Build the individual packages
    (
        # No sense in trying to build for special architectures
        if [ "$ARCH_BASE" = "special" ]; then
            exit
        fi
            
        task_start "harbour-build.$ARCH_ESC" "Building packages for $ARCH." \
            "helenos.$ARCH_ESC" `for HAR in $HARBOURS; do echo "harbour-fetch.$HAR"; done`
        
        mkdir "$BUILD_DIR/coast"
    
        create_coastline_conf "$BUILD_DIR/coast" "$ARCH" \
            "$BUILD_DIR/helenos-build" "$MY_TEMP/mirror/sources"
    
        for HAR in $HARBOURS; do
            if [ -e "$MY_TEMP/out/$OUT_IMAGE_FILE" ]; then
                (
                    cd $BUILD_DIR/coast/
                    MY_RC=0
	                $MY_TEMP/coastline/hsct.sh archive --no-deps --no-fetch $HAR || MY_RC=1
	                cp archives/$HAR.tar.xz "$MY_TEMP/out/$ARCH_ESC/$HAR-$ARCH_ESC.tar.xz" || MY_RC=1
	                $MY_TEMP/coastline/hsct.sh clean $HAR
	                exit $MY_RC
	            ) &>$MY_TEMP/out/$ARCH_ESC/$HAR-build.log
	            RC=$?
                
	            if [ $RC -ne 0 ]; then
	                if tail $MY_TEMP/out/$ARCH_ESC/$HAR-build.log | grep -q \
	                        -e 'run without --no-deps' \
	                        -e 'Error: Unknown package' \
	                        -e 'without --no-fetch'; then
	                    RC=-1
	                fi
	            fi
            else
                echo "Error: HelenOS image '$OUT_IMAGE_FILE' not found." >$MY_TEMP/out/$ARCH_ESC/$HAR-build.log
                RC=-1
            fi
            
	        report_result $RC "harbour-build" "$ARCH_ESC/$HAR-build.log" "package=$HAR" "arch=$ARCH"
        done
     
        task_end
    ) &
    
    # Once the packages are built, we go through the scenarios and determine
    # if we need to build a special images, e.g. HelenOS with GCC.
    if is_testable_architecture $ARCH; then
    (
        task_start "helenos-with-harbours.$ARCH_ESC" "Preparing special builds for $ARCH." \
            "helenos.$ARCH_ESC" "harbour-build.$ARCH_ESC"
        
        # Makes sense only if normal build succeeded
        if [ -e "$MY_TEMP/out/$OUT_IMAGE_FILE" ]; then
            for SCENARIO in $SCENARIOS; do
                NEEDS_HARBOURS=`get_needed_harbours_for_scenario $SCENARIO`
                NEEDS_HARBOURS_HASH=`hash_harbours $NEEDS_HARBOURS`
                TARGET_IMAGE_FILE_NAME=`get_output_image_file $ARCH -$NEEDS_HARBOURS_HASH`
                TARGET_IMAGE_FILE="$MY_TEMP/out/$TARGET_IMAGE_FILE_NAME"
                LOG_FILE="$MY_TEMP/out/$ARCH_ESC/build-extra-$NEEDS_HARBOURS_HASH.log"
                if [ -n "$NEEDS_HARBOURS" ] && [ ! -e "$TARGET_IMAGE_FILE" ] && [ ! -e "$LOG_FILE" ]; then
                    (
                        echo "# Scenario $SCENARIO"
                        echo "# Needs: $NEEDS_HARBOURS (hash is $NEEDS_HARBOURS_HASH)"
                        rm -rf "$BUILD_DIR/helenos-build/uspace/overlay/"* || exit 1
                        for HAR in $NEEDS_HARBOURS; do
	                    HAR_FILE="$MY_TEMP/out/$ARCH_ESC/$HAR-$ARCH_ESC.tar.xz"
	                    if ! [ -e "$HAR_FILE" ]; then
	                        echo "Error: harbour $HAR not built."
	                        exit 1
	                    fi
	                    
	                    (
	                       cd "$BUILD_DIR/helenos-build/uspace/overlay/" || exit 1
	                       tar xJf "$HAR_FILE" || exit 1
	                    ) || exit 1
	                done
	                (
                            cd "$BUILD_DIR/helenos-build/" || exit 1
                            make || exit 1
                        ) || exit 1
                        IMAGE_FILE="$BUILD_DIR/helenos-build/`get_image_file $ARCH`"
                        cp "$IMAGE_FILE" "$TARGET_IMAGE_FILE" || exit 1
                    ) &>"$LOG_FILE"
                    RC=$?
                    
                    if tail -n 1 "$LOG_FILE" | grep -q '^Error: harbour .* not built.$'; then
                        RC=-1
                    fi
                    
                    
                    report_result $RC "helenos-extra-build" \
                        "$ARCH_ESC/build-extra-$NEEDS_HARBOURS_HASH.log" \
                        "packages=$NEEDS_HARBOURS" "arch=$ARCH"
                fi
            done
        fi
        task_end
    ) &
    fi
done

# Wait for for all tasks to be completed.
tasks_barrier





#
#
# Run the tests.
# The tests cannot be run in parallel (KVM sharing) but we use the task_*
# functions for on-screen messages.
#
#
for ARCH in $ARCHITECTURES; do
    ARCH_ESC=`echo $ARCH | tr '/' '-'`
    
    if is_testable_architecture $ARCH; then
    (
        task_start "tests.$ARCH_ESC" "Testing $ARCH." "helenos.$ARCH_ESC" # "harbour-build.$ARCH_ESC"

        for SCENARIO in $SCENARIOS; do
            SCENARIO_ESC=`echo $SCENARIO | sed 's#.test$##' | tr '/' '-'`
            NEEDS_HARBOURS=`get_needed_harbours_for_scenario $SCENARIO`
            if [ -z "$NEEDS_HARBOURS" ]; then
                IMAGE_BASENAME=`get_output_image_file $ARCH`
            else
                NEEDS_HARBOURS_HASH=`hash_harbours $NEEDS_HARBOURS`
                IMAGE_BASENAME=`get_output_image_file $ARCH -$NEEDS_HARBOURS_HASH`
            fi
            IMAGE_FILE="$MY_TEMP/out/$IMAGE_BASENAME"
            
            if [ -e "$IMAGE_FILE" ]; then
                (
                    EXTRA_ARGS=""
                    if ! $TEST_USE_KVM; then
                        EXTRA_ARGS="$EXTRA_ARGS --no-kvm"
                    fi
                    ./test-in-vm.sh \
                        --headless \
                        --fail-fast \
                        --arch=$ARCH \
                        "--temp=$MY_TEMP/test/$ARCH_ESC/" \
                        "--image=$IMAGE_FILE" \
                        $EXTRA_ARGS \
                        scenarios/$SCENARIO
                ) &>$MY_TEMP/out/$ARCH_ESC/test-$SCENARIO_ESC.log
                RC=$?
            else
                echo "Error: HelenOS image '$IMAGE_BASENAME' not found." >$MY_TEMP/out/$ARCH_ESC/test-$SCENARIO_ESC.log
                RC=-1
            fi
            
            report_result $RC "test" "$ARCH_ESC/test-$SCENARIO_ESC.log" "arch=$ARCH" "scenario=$SCENARIO"
        done

        task_end
    )
    fi
done

tasks_barrier

report_done

if [ -n "$ATTIC_DIR" ]; then
    (
        task_start "attic" "Merge with previous builds."
        
        mkdir -p "$ATTIC_DIR"
        
        cd "$ATTIC_DIR"
        
        if ! [ -e "log.xml" ]; then
            ( echo '<?xml version="1.0"?>'; echo '<builds>'; echo '</builds>'; ) > log.xml
        fi
        
        cp "$MY_TEMP/out/result.xml" "last.xml"
        
        xmllint --format log.xml | sed -e '/<\/builds>/r last.xml' -e '/<\/builds>/d' >new.xml
        sed -e '2,$s/<[?]xml version=.*>//' -e '$a</builds>' new.xml >log.xml
        
        task_end
    )
fi

tasks_done
