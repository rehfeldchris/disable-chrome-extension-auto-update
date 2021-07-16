#!/bin/bash

# This script needs to search part of your filesystem to look for installed extensions. Many different
# Chromium browser variants exist, and they each use a slightly different named directory, and each operating system
# also can affect where these directories are stored. Some common locations are already set for you, but you may need to
# edit and supply your own value.

# Edit this var to point to the equivalent location used by Chromium based browsers.
# For example, Vivaldi uses ~/AppData/Local/Vivaldi
# win10 WSL /mnt/c/Users/MY_USER_NAME/AppData/Local/Google
# win git bash / MSYS2 /c/Users/MY_USER_NAME/AppData/Local/Google
# linux ~/.config/chromium
# linux ~/.config/google-chrome
# On win10 WSL you may need to set userDir to: /mnt/c/Users/MY_USER_NAME



# Windows XP: C:\Documents and Settings\%USERNAME%\Local Settings\Application Data\Google\Chrome\User Data\Default\Extensions\<Extension ID>
# Windows 10/8/7/Vista: C:\Users\%USERNAME%\AppData\Local\Google\Chrome\User Data\Default\Extensions\<Extension ID>
# macOS: ~/Library/Application Support/Google/Chrome/Default/Extensions/<Extension ID>
# Linux: ~/.config/google-chrome/Default/Extensions/<Extension ID>
# Chrome OS: /home/chronos/Extensions/<Extension ID>


userDir=~
extensionInstallDirSearchBases=(
    "$userDir/AppData/Local"
    "$userDir/.config"
)

# Exit script on errors.
set -e
err_report() {
    echo "Error on line $(caller). Exiting." >&2
}
trap 'err_report' ERR

# Returns the value of a certain key from a json file.
# For example, if the json line in the file looks like: "update_url": "foo"
# this func would return the value foo.
# It's not a robust json parser, and it will not unescape values, nor will it decode unicode escape sequences etc...
# The json file must be formatted so that only a single key+value pair exists on each line.
getJsonKeyVal() {
    local file="$1"
    local key="$2"
    grep '"'$key'":' "$file" | sed 's/.*"'$key'": "\([^"]\+\)".*/\1/'
}

# wWll return "ppdnkejgcieghdpjnjokjeefbojbjdaa" when called with this arg: "ppdnkejgcieghdpjnjokjeefbojbjdaa/1.4_0"
# Maybe rename this to getLeftmostDirNameFromPath ?
extractExtensionIdFromPath() {
    local path="$1"
    echo "${path%%/*}"
}

# Edits the manifest file, altering the line which has the json "update_url" key and value.
# normally, update_url is a valid url like "https://google.com/...." but this func will prepend a "+" symbol, making the url look like "+https://google.com/....".
# The presence of the + symbol will cause the update process to fail, which prevents automatic updates.
editUpdateUrl() {
    local manifest="$1"
    local enableDisable="$2"

    if [ $enableDisable = "e" ]; then
        sed -i 's/"update_url": "+http/"update_url": "http/g' "$manifest"
    else
        sed -i 's/"update_url": "http/"update_url": "+http/g' "$manifest"
    fi
}


# check if stdout is a terminal...
bold=""
underline=""
standout=""
normal=""
black=""
red=""
green=""
yellow=""
blue=""
magenta=""
cyan=""
white=""
if test -t 1; then

    # see if it supports colors...
    nColors=$(tput colors)

    if test -n "$nColors" && test "$nColors" -ge 8; then
        _bold="$(tput bold)"
        _underline="$(tput smul)"
        _standout="$(tput smso)"
        _normal="$(tput sgr0)"
        _black="$(tput setaf 0)"
        _red="$(tput setaf 1)"
        _green="$(tput setaf 2)"
        _yellow="$(tput setaf 3)"
        _blue="$(tput setaf 4)"
        _magenta="$(tput setaf 5)"
        _cyan="$(tput setaf 6)"
        _white="$(tput setaf 7)"
    fi
fi
function color {
    printf "%s%s%s" "$1" "$2" "$_normal"
}

function red {
    printf "%s%s%s" "$_red" "$@" "$_normal"
}

function green {
    color "$_green" "$1"
}

function yellow {
    color "$_yellow" "$1"
}

echo
echo "This script will enable or disable the automatic extension update feature for specific browser extensions you have installed."
echo "It will not actually enable or disable the *operation* of the extension for you, it just controls the update process by editing the extension manifest file to manipulate the update_url variable, basically breaking the update url."
echo
echo "Scanning..."
echo

# Find all the different extension install dirs, including those for different brands of chromium based browsers, and versions / release channels.
# We need to scan and search because there's lots of path variations across different browsers brands and versions / channels.
# For example, on windows 10 we might have a common base of "C:\Users\%USERNAME%\AppData\Local" but the next 1-2 dirs could be any of these examples:
# C:\Users\%USERNAME%\AppData\Local\Google\Chrome
# C:\Users\%USERNAME%\AppData\Local\Google\Chrome Beta
# C:\Users\%USERNAME%\AppData\Local\Vivaldi
# C:\Users\%USERNAME%\AppData\Local\BraveSoftware\Brave-Browser
# But, they ALL contain nested dirs named "Default\Extensions", like this:
# C:\Users\%USERNAME%\AppData\Local\Google\Chrome\User Data\Default\Extensions\<Extension ID>
# So we search for all dirs containing "Default\Extensions", and that will give us a list of all browsers installed in one of our
# paths listed in the $extensionInstallDirSearchBases array.
extensionInstallPaths=()
for dir in $extensionInstallDirSearchBases
do
    extensionInstallPathLines=$(find "$dir" -mindepth 1 -maxdepth 7 -path "*/Default/Extensions" 2>/dev/null || true)
    mapfile -t paths < <(echo "$extensionInstallPathLines")
    for i in $(seq 0 $((${#paths[@]}-1)))
    do
        extensionInstallPaths+=("${paths[$i]}")
    done
done

# Give feedback about which browser installs we found, and let the user choose which install to operate on if more than 1 was found.
numExtensionInstallPaths=${#extensionInstallPaths[@]}
maxExtensionInstallPathIndex=$((numExtensionInstallPaths - 1))
if [ "$numExtensionInstallPaths" -lt "1" ]; then
    echo "Didnt find any chrome install directories in any of these paths: ${extensionInstallDirSearchBases[@]}."
    echo "Edit the extensionInstallDirSearchBases variable, then try again."
    exit 1
elif [ "$numExtensionInstallPaths" -gt "1" ]; then
    validatedIndex=-1
    echo "Found multiple Chromium based browser installs:"
    while (( validatedIndex < 0)); do

        for i in $(seq 0 $maxExtensionInstallPathIndex)
        do
            echo "$i) " "${extensionInstallPaths[$i]}"
        done

        echo
        printf "Enter the number for which browser install you wish to manage extensions for\n>"
        read -r index

        if [[ $index =~ ^[0-9]+$ ]] && [[ $index -ge 0 ]] && [[ $index -lt $numExtensionInstallPaths ]]; then
            validatedIndex=$index
        else
            echo
            red "Bad input ($index)."
            echo
            red "Input wasn't a number, or the number was not within the range of values of 0 through $maxExtensionInstallPathIndex."
            echo
            echo
            sleep 1
        fi

    done

    browserInstallationPath="${extensionInstallPaths[$validatedIndex]}"
else
    echo "Found a single Chromium based browser install."
    browserInstallationPath="${extensionInstallPaths[0]}"
fi


# Scan the filesystem for extension directory names inside the install dir.
# extensionPathsStr will have 1 path per line, with each line looking like: ./admokidfeboogldpfhheflggdligklpl/1.9_0
# Basically, an extension id, and version on each line.
dir=$(pwd)
cd "$browserInstallationPath"
#cd "$browserInstallationPath/Default/Extensions"
extensionPathsStr=$(find . -maxdepth 2 -mindepth 2 -type d)
#extensionPathsStr=$'./admokidfeboogldpfhheflggdligklpl/1.9_0\n./bcjindcccaagfpapjjmafapmmgkkhgoa/0.6.0_0\n./cjpalhdlnbpafiamejdnhcphjbkeiagm/1.34.0_3\n./doocmbmlcnbbdohogchldhlikjpndpng/1.32_0'

mapfile -t extensionPaths < <(echo "$extensionPathsStr")
numExtensionPaths=${#extensionPaths[@]}

cd "$dir"
extensionIds=()
extensionNames=()
manifestFiles=()
manifestFileContents=()

if (( numExtensionPaths == 0)); then
    echo
    red "Zero installed extensions found."
    red "Are you sure any are actually installed in $browserInstallationPath ?"
    exit 1
else
    echo
    echo "Extensions found:"
    echo
fi

# Parse each extension's manifest.json file, and also output a listing of extensions, along with a summary of info about each.
# This part of the code is pretty slow.
for i in $(seq 0 $(($numExtensionPaths-1)))
do
    # Path has extension id dir, followed by version dir, like ./ppdnkejgcieghdpjnjokjeefbojbjdaa/1.4_0
    path="${extensionPaths[$i]}"

    # Chop off leading ./
    path="${path:2}"

    # Parse the manifest file, extracting a few variables.
    manifest="$browserInstallationPath/$path/manifest.json"
    extensionId=$(extractExtensionIdFromPath "$path")
    extName=$(getJsonKeyVal "$manifest" name)
    updateUrl=$(getJsonKeyVal "$manifest" update_url)
    version=$(getJsonKeyVal "$manifest" version)
#    description=$(getJsonKeyVal "$manifest" description)
#    shortName=$(getJsonKeyVal "$manifest" short_name)

    # Add those vars to our arrays for later use.
    extensionIds+=("$extensionId")
    manifestFiles+=("$manifest")
    extensionNames+=("$extName")

    # Output some info about the extension.
    # If the first char is a +, it means we already disabled the update process for this extension.
    if [[ ${updateUrl:0:1} == "+" ]]; then
        enabledDisabled=$(red D)
    else
        enabledDisabled=$(green E)
    fi

    printf "%s %-4s %s\n" "$enabledDisabled" "$i)" "$extName v$version"
done

indexesToModify=()
numExtensions="${#manifestFiles[@]}"
maxExtensionIndex=$((numExtensions - 1))

# Ask the user which extensions to enable/disable.
validatedArgs=-1
while (( validatedArgs < 0)); do

    echo
    echo "Enter an extension index number, followed by either e or d to enable or disable it."
    echo "Examples:"
    echo "4 e - enable extension at index 4"
    echo "4,7,11 d - disable extensions at indexes 4, 7, and 11"
    echo "all e - enable all extensions"
    printf ">"
    read -r command

    commandArgs=($command)
    indexDescriptor="${commandArgs[0]}"
    enableDisable="${commandArgs[1]}"

    if [[ $enableDisable =~ ^[ed]$ ]] && [[ $indexDescriptor =~ ^(all|[0-9]+(,[0-9]+)*)$ ]]; then
        # Mark args valid, for now. We might change it back to -1.
        validatedArgs=1

        if [ "$indexDescriptor" = "all" ]; then
            indexesToModify=( $(seq 0 $maxExtensionIndex) )
        else
            # Change csv string to space sep, like "1 2 5"
            indexes="$(tr ',' ' ' <<<"$indexDescriptor")"
            indexesToModify=($indexes)

            # Loop over the space separated string elements.
            for index in "${indexesToModify[@]}"
            do
                if (( index < 0 )) || (( index >= maxExtensionIndex )); then
                    # index out of range
                    echo
                    red "Bad input."
                    echo
                    red "Index $index is out of range. Indexes must be between 0 and $maxExtensionIndex."
                    echo
                    echo
                    sleep 1
                    # Set back to -1, so the while loop iterates again, prompting for user input again.
                    validatedArgs=-1
                fi
            done

        fi
    else
        echo
        red "Bad input. Follow the examples, and try again."
        echo
        echo
        sleep 1
    fi

done


# Loop over the list of extension indexes, and modify each extension.
for index in "${indexesToModify[@]}"
do
    manifest="${manifestFiles[$index]}"
    extName="${extensionNames[$index]}"

    echo
    echo "modifying $extName"
    echo "$manifest"

    editUpdateUrl "$manifest" "$enableDisable"
    updateUrl=$(getJsonKeyVal "$manifest" update_url)
    if [[ ${updateUrl:0:1} == "h" && $enableDisable == "e" ]]; then
      echo "Success. Enabled."
    elif [[ ${updateUrl:0:1} == "+" && $enableDisable == "d" ]]; then
      echo "Success. Disabled."
    fi
done

echo
echo "Done."
exit