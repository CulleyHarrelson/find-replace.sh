#!/opt/homebrew/bin/bash

# setup
CMDNAME=$(basename $0)
NO_ARGS=0
DEFAULT_SRC=~/.find-replace.sed
TEMPERR=/tmp/find-replace-err-$$
TEMPOUT=/tmp/find-replace-out-$$

HELP="\
Usage: $CMDNAME options (-cers) file-to-edit [files-to-edit]

    This command is used to perform global find and replace operations by
    wrapping around sed. Sed commands are taken from the file specified in the
    DEFAULT_SRC variable (currently $DEFAULT_SRC) 
    or whatever file is specified with the -s option

    -c check the results of the operation (uses bat for colorized diff output)
    -e edit the source file
    -h print this help file
    -r run the operation
    -s (file) use this source file

    Examples:
        find-replace.sh -e                  #set up your commands
        find-replace.sh -c (file glob)      #see colorized diffs of changes
        find-replace.sh -r (file glob)      #run the script
        find . -name \"*.php\" | xargs find-replace.sh -c
    "

# Script invoked with no command-line args?
if [ $# -eq "$NO_ARGS" ]; then
    echo "$HELP"
    exit
fi

while getopts ":cehrs:" Option; do
    case $Option in
    c) CHECK=yes ;;
    e) EDIT=yes ;;
    h)
        echo "$HELP"
        exit
        ;;
    r) RUN=yes ;;
    s) SCRIPT=$OPTARG ;;
    esac
done

shift $(($OPTIND - 1))

#use the default if no script was specified
if [ -z "$SCRIPT" ]; then
    SCRIPT=$DEFAULT_SRC
fi

#make sure the file exists
if [ ! -r $SCRIPT -o ! -f $SCRIPT ]; then
    echo "$CMDNAME quitting: $SCRIPT isn't readable or isn't a file." 1>&2
    exit
fi

# run the check operation?
if [ -n "$CHECK" ]; then
    # Loop through files. Print header before each file's results.
    # Then run sed and show the changes script would make using bat.
    for FILE; do
        echo "********** Changes for $FILE **********"
        sed -E -f $SCRIPT "$FILE" | diff --color=always "$FILE" - | bat --language=diff --style=plain
        echo
    done
    exit
fi
# edit the source file?
if [ -n "$EDIT" ]; then
    $EDITOR $SCRIPT
    exit
fi
# execute the script?
if [ -n "$RUN" ]; then

    STAT=1 # Default exit status (reset to 0 before normal exit)
    trap 'rm -f $TEMPERR $TEMPOUT; exit $STAT' 0
    trap 'echo "$CMDNAME: Interrupt!  Cleaning up..." 1>&2' 1 2 15

    for x; do
        echo "$CMDNAME: editing $x: " 1>&2
        if [ "$x" = $SCRIPT ]; then
            echo "$CMDNAME: not editing $SCRIPT!" 1>&2
        elif [ ! -s "$x" -o ! -f "$x" ]; then
            echo "$CMDNAME: original $x is empty or not a file." 1>&2
        elif [ ! -w "$x" ]; then
            echo "$CMDNAME: can't write $x -- skipping..." 1>&2
        else
            # If get here, run sed.  To keep source file's permissions
            # and owner the same, don't overwrite it until the end --
            # and use "cat > file" to write the file in place.
            sed -E -f $SCRIPT "$x" >$TEMPOUT 2>$TEMPERR
            if [ $? -ne 0 -o -s $TEMPERR ]; then
                cat $TEMPERR 1>&2
                echo "$CMDNAME quitting: 'sed -f $SCRIPT $x' bombed!?!" 1>&2
                exit
            elif [ -s $TEMPOUT ]; then
                if cmp -s "$x" $TEMPOUT; then
                    echo "$CMDNAME: $x file not changed." 1>&2
                else
                    if /bin/cat $TEMPOUT >$x; then
                        echo "$CMDNAME: done with $x" 1>&2
                    else
                        echo "$CMDNAME quitting: problem replacing $x?" 1>&2
                        exit
                    fi
                fi
            else
                echo "$CMDNAME quitting: sed produced an empty file - check your $SCRIPT." 1>&2
                echo "$CMDNAME: didn't change $x" 1>&2
                exit
            fi
        fi
    done

    echo "$CMDNAME: all done" 1>&2
    STAT=0
    exit

fi
