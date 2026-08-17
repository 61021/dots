# Opening one image loads its folder into the filelist, so h/l browse
# the rest from there. Anything else passes through untouched.
function feh --wraps feh --description 'feh, browsing the folder when given one image'
    if test (count $argv) -eq 1; and test -f $argv[1]
        command feh --start-at $argv[1]
    else
        command feh $argv
    end
end
