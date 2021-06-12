#!/bin/bash

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


getJsonKeyVal() {
    local file="$1"
    local key="$2"
    grep '"'$key'":' "$file" | sed 's/.*"'$key'": "\([^"]\+\)".*/\1/'
}

extractExtensionIdFromPath() {
    local path="$1"
    echo "${path%%/*}"
}

editUpdateUrl() {
    local manifest="$1"
    local enableDisable="$2"

    if [ $enableDisable = "e" ]; then
        sed -i 's/"update_url": "+http/"update_url": "http/g' "$manifest"
    else
        sed -i 's/"update_url": "http/"update_url": "+http/g' "$manifest"
    fi
}

echo
echo "This script will enable or disable the automatic extension update feature for specific browser extensions you have installed."
echo "It will not actually enable or disable the *operation* of the extension for you, it just controls the update process by editing the manifest file to manipulate the update_url variable."
echo

# Find all the different extension install dirs across different brands of chromium based browsers, and versions.
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

numExtensionInstallPaths=${#extensionInstallPaths[@]}
if [ "$numExtensionInstallPaths" -lt "1" ]; then
    echo "Didnt find any chrome install directories in any of these paths: ${extensionInstallDirSearchBases[@]}."
    echo "Edit the extensionInstallDirSearchBases variable, then try again."
    exit 1
elif [ "$numExtensionInstallPaths" -gt "1" ]; then
    validatedIndex=-1
    echo "Found multiple Chromium based browser installs:"
    while (( validatedIndex < 0)); do

        for i in $(seq 0 $(($numExtensionInstallPaths-1)))
        do
            echo "$i) " "${extensionInstallPaths[$i]}"
        done

        echo
        printf "Choose which browser install you wish to manage extensions for\n>"
        read index

        pat='^[0-9]+$'
        if [[ $index =~ $pat ]] && [[ $index -ge 0 ]] && [[ $index -lt $numExtensionInstallPaths ]]; then
            validatedIndex=$index
        else
            echo
            echo "Bad input."
            echo "Index num for install path is out of range."
            echo
        fi

    done

    browserInstallationPath="${extensionInstallPaths[$validatedIndex]}"
else
    browserInstallationPath="${extensionInstallPaths[0]}"
fi


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



for i in $(seq 0 $(($numExtensionPaths-1)))
do
    # path has extension id dir, followed by version dir, like ppdnkejgcieghdpjnjokjeefbojbjdaa/1.4_0
    path="${extensionPaths[$i]}"

    # Chop off leading ./
    path="${path:2}"
    manifest="$browserInstallationPath/$path/manifest.json"
    extensionId=$(extractExtensionIdFromPath "$path")
    extName=$(getJsonKeyVal "$manifest" name)
    updateUrl=$(getJsonKeyVal "$manifest" update_url)
    version=$(getJsonKeyVal "$manifest" version)
#    description=$(getJsonKeyVal "$manifest" description)
#    shortName=$(getJsonKeyVal "$manifest" short_name)

    extensionIds+=("$extensionId")
    manifestFiles+=("$manifest")
    extensionNames+=("$extName")

    echo
    printf "%-3s %s\n" "$i)" "$extName v$version"
#    echo "$i) $extName v$version"
    echo "    $extensionId"

    if [[ ${updateUrl:0:1} == "+" ]]; then
        echo "    $updateUrl (disabled)"
    else
        echo "    $updateUrl (enabled)"
    fi
done


echo
echo "Enter an extension index number, followed by either "e" or "d" to enable or disable it."
echo "Examples:"
echo "4 e - enable extension at index 4"
echo "4,7,11 d - disable extensions at indexes 4, 7, and 11"
echo "all e - enable all extensions"
printf ">"
read command

commandArgs=($command)

if [ "${#commandArgs[@]}" -eq "0" ]; then
    # they want to exit
    exit 1
elif [ "${#commandArgs[@]}" -ne "2" ]; then
    # Too many args
    echo
    echo "Bad input."
    echo "Make sure to enter a number, followed by a space, followed by either e or d, like: \"4 e\""
    exit 1
fi

numExtensions="${#manifestFiles[@]}"
index="${commandArgs[0]}"
enableDisable="${commandArgs[1]}"

if [ $enableDisable != "e" ] && [ $enableDisable != "d" ]; then
    echo
    echo "Bad input."
    echo "Make sure to enter a number, followed by a space, followed by either e or d, like: \"4 e\""
    exit 1
fi

indexesToModify=()
if [ $index = "all" ]; then
    indexesToModify=( $(seq 0 $numExtensions) )
else
    # Change csv string to space sep, like "1 2 5"
    indexes="$(tr ',' ' ' <<<$index)"
    indexesToModify=($indexes)
    # Loop over the space separated string elements.
    for index in ${indexesToModify[@]}
    do
        if (( $index < 0 )) || (( $index >= $numExtensions )); then
            # index out of range
            echo
            echo "Bad input."
            echo "Index num out of range."
            exit 1
        fi
    done

    # Ensure we have at least 1 number.
    if [ "${#indexesToModify[@]}" -eq "0" ]; then
        # This could happen if they enter something like ", e"
        echo
        echo "Bad input."
        echo "Make sure to enter a number, followed by a space, followed by either e or d, like: \"4 e\""
        exit 1
    fi

fi

# Loop over the list of extension indexes, and modify each extension.
for index in "${indexesToModify[@]}"
do
    manifest="${manifestFiles[$index]}"
    extName="${extensionNames[$index]}"

    echo
    echo "modifying $extName $manifest"

    editUpdateUrl "$manifest" $enableDisable
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