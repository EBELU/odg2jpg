#!/bin/bash

PROCESS=2 # Standard should be paralell
DELAY=5 # Minimum time between conversions in seconds
# ==== Options ====

while test $# -gt 0; do
    case "$1" in
        -h | --help )
        echo "Options:"
        echo "-process {}"
        echo -e "\tArgs: \n\t0 - Run without seperate LO env in single thread. \n\t1 - Run in seperate LO env in single thread. \n\t2 - Run in paralell in seperate LO envs."
        
        exit 0
        ;;
        -process )
           PROCESS=$2
           shift
           shift
           ;;
           
        -delay )
            DELAY=$2
            shift
            shift
            ;;
        *)
        break
        ;;
    esac         
done


wd=$1 # Save working directory

function fn_odg2jpg_basic {
    # Most basic function for converting images
    local DIR="$(dirname "$1")" # Get directory of file
    soffice --headless --nologo --nofirststartwizard --norestore  --convert-to jpg:draw_jpg_Export "$1" --outdir "$DIR"
}

function fn_odg2jpg_paralell {

    local DIR="$(dirname "$1")"
    
    # Make a temporary directory for the LO env, will later be deleted
    tmpdir=`mktemp -d /tmp/libreoffice-XXXXXXXXXXXX`
    echo -e "\n========== Tempdir: $tmpdir =========="
    # Create a trap with code that executes on the function return
    trap "rm -rf $tmpdir" RETURN
    
    
    soffice "-env:UserInstallation=file://$tmpdir" --headless --nologo --nofirststartwizard --norestore  --convert-to jpg:draw_jpg_Export "$1" --outdir "$DIR"
   

}

function fn_check_lifetime {

        # If the file is to young do not convert again
        # This is done by first checking if the file exists
        # If it does, the life time is checked, if it is less than DELAY the conversion is skipped
        
        local i="$1"       
        local file_as_jpg="${i/.odg/".jpg"}" # Change .odg to .jpg
        
        if test -f "$file_as_jpg"; then # Test if the image exists
            local life_time=$(( $(date +%s) - $(stat -c "%W" "$file_as_jpg") )) # Calculate life time in seconds
            # date +%s gives current epoch time
            #stat -c %W gives creation time in epoch time
            if [[ $life_time -le $DELAY ]]; then
                echo -e "\n=======>>> Skipping "$i", life time: "$life_time" >>>======="
                return 0
            fi
        fi
        
        return 1
}

test_fn () {
    DIR="$(dirname "$1")"
    echo $DIR
    echo "$1"
}

# If no odg files are present, the script swiftly exits
if [[ ! $(find $wd -name '*.odg') ]]; then
    echo "No odg files"
    exit 0
fi




# Simplest
if [ $PROCESS -eq 0 ]; then
    find $wd -name '*.odg' | while read line; do fn_odg2jpg_basic "$line"; done
    
# Single thread
elif  [ $PROCESS -eq 1 ]; then   
    # Make a temporary directory for the LO env, will later be deleted
    tmpdir=`mktemp -d /tmp/libreoffice-XXXXXXXXXXXX`
    echo -e "\n========== Tempdir: $tmpdir =========="
    # Create a trap with code that executes on script exit
    trap "rm -rf $tmpdir" EXIT

    find $wd -name '*.odg' | while read line; do  
    
    # If the file is to young do not convert again
    fn_check_lifetime "$line"
    if (( ! $? )); then
        continue
    fi
    
    OUTDIR="$(dirname "$line")"
    soffice "-env:UserInstallation=file://$tmpdir" --headless --nologo --nofirststartwizard --norestore  --convert-to jpg:draw_jpg_Export "$line" --outdir "$OUTDIR"
    done
    
# Paralell  
elif [ $PROCESS -eq 2 ]; then

    shopt -s globstar
    for i in **/*.odg; do 
        # If the file is to young do not convert again
        fn_check_lifetime "$i"
        if (( ! $? )); then
            continue
        fi
        
        # Call conversion function as a background subshell
        fn_odg2jpg_paralell "$i" &
    done
    
fi
wait

