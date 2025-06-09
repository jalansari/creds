#!/usr/bin/env bash

set -e

AwsCredsPath="$HOME/.aws"
SshPath="$HOME/.ssh"
BashHistory="$HOME/.bash_history"
MySqlHistory="$HOME/.mysql_history"
PsqlHistory="$HOME/.psql_history"

gpg_key="gpg_private.asc"

compressed_file_prefix="creds"
compressed_file_extension=".tar.gz"
compressed_file_extension_enc=".gpg"

user_bashrc="$HOME/.bashrc"





LOG_PREFIX="CREDS:  "
prefixColour="0;33"
logColour="1;36"
ERRORCOLOUR="1;31"
WARNCOLOUR="1;35"
function PRINTLOG()
{   echo -e "\033[${prefixColour}m${LOG_PREFIX}\033[0m\033[${logColour}m${1}\033[0m"
}
function PRINT_ERROR()
{   PRINTLOG "\033[${ERRORCOLOUR}m$1\033[0m"
}
function PRINT_WARN()
{   PRINTLOG "\033[${WARNCOLOUR}m$1\033[0m"
}

doExtract=false
addDirs=""
additional_dirs_list=()

while [[ -n "$1" ]]; do
    case $1 in
        -x ) doExtract=true ;;
        -a ) shift
             addDirs="$1" ;;
        * ) PRINT_ERROR "Usage: $0 [-x] [-a <additional_dirs>]"
            exit 1 ;;
    esac
    shift
done

PRINTLOG "Starting credentials management script..."
PRINTLOG "doExtract: $doExtract"
if [[ "$doExtract" != "true" ]]; then
    PRINTLOG "addDirs  : $addDirs"

    if [[ -n "$addDirs" ]]; then
        IFS=',' read -r -a additional_dirs <<< "$addDirs"
        for dir in "${additional_dirs[@]}"; do
            absolute_dir="$(cd "$(dirname "$dir")"; pwd)/$(basename "$dir")"
            if [[ -d "$absolute_dir" ]]; then
                additional_dirs_list+=("$absolute_dir")
            else
                PRINT_WARN "Discarding <$absolute_dir> - does not exist."
            fi
        done
    fi

    additional_dirs_list=( $(echo "${additional_dirs_list[@]}" | tr ' ' '\n' | sort -u) )

    PRINTLOG "Adding directories to backup:"
    for dir in "${additional_dirs_list[@]}"; do
        PRINTLOG "    $dir"
        addDirs="$addDirs $dir"
    done
elif [[ -n "$addDirs" ]]; then
    PRINT_ERROR "ERROR: -x cannot be used with -a."
    exit 1
fi





if [[ "$doExtract" != "true" ]]; then





rm -rf "$AwsCredsPath/cli"

key_id=$( gpg --list-secret-keys --with-colons | awk -F: '/^sec/ { print $5 }' )
gpg --armor --export-secret-key $key_id > "$gpg_key"

tar -czf "$compressed_file_prefix$compressed_file_extension" \
    "$AwsCredsPath" "$SshPath" \
    "$BashHistory" "$MySqlHistory" "$PsqlHistory" \
    "$gpg_key" \
    "${additional_dirs_list[@]}"

rm -r "$gpg_key"

read -sp "Enter encryption password: " ZipPasswd
echo
gpg -c --batch --yes --passphrase "$ZipPasswd" "$compressed_file_prefix$compressed_file_extension"

PRINTLOG "CREATED : $compressed_file_prefix$compressed_file_extension$compressed_file_extension_enc"





else





compressed_file=

for file_name in creds*; do
    if [[ "$file_name" =~ ^$compressed_file_prefix.*$compressed_file_extension_enc$ ]]; then
        compressed_file="$file_name"
    fi
done

uncompress_to_file="${compressed_file%.*}"

if [[ -z "$compressed_file" ]]; then
    PRINT_ERROR "ERROR: Encrypted file not found."
    exit 1
fi

PRINTLOG "FOUND         : $compressed_file"
PRINTLOG "Decrypting to : $uncompress_to_file"
PRINTLOG
read -sp "Enter encryption password: " ZipPasswd
PRINTLOG
gpg -d --batch --yes --passphrase "$ZipPasswd" -o "$uncompress_to_file" "$compressed_file"
PRINTLOG "Decrypted to  : $uncompress_to_file"

temp_dir="creds_temp"
if [[ -f "$uncompress_to_file" ]]; then
    PRINTLOG "Extracting files from $uncompress_to_file to $temp_dir"
    mkdir -p "$temp_dir"
    tar -xzf "$uncompress_to_file" -C "$temp_dir"
    rm -f "$uncompress_to_file"
else
    PRINT_ERROR "ERROR: Decryption failed or file not found."
    exit 1
fi

# gpg import key
if [[ -f "$temp_dir/$gpg_key" ]]; then
    PRINTLOG "Importing GPG key"
    gpg --allow-secret-key-import --import "$temp_dir/$gpg_key"
else
    PRINT_WARN "GPG key file not found in extracted files."
fi

# home dir files and dirs
for dir in "$temp_dir"/*; do
    if [[ -d "$dir" ]] && [[ "$dir" == "$temp_dir/home" ]]; then
        PRINTLOG "Copying home directory files"
        user_dir=( $(ls "$dir") )
        number_of_user_dirs=${#user_dir[@]}
        user_home="$dir/${user_dir[0]}"
        if [[ $number_of_user_dirs -ne 1 ]] || [[ ! -d "$user_home" ]]; then
            PRINT_ERROR "ERROR: Expected exactly one user home directory."
            exit 1
        fi
        items_in_home=( $(ls -A $user_home) )
        PRINTLOG "User home directory: $user_home"
        for item in ${items_in_home[@]}; do
            item="$user_home/$item"
            if [[ -f "$item" ]]; then
                PRINTLOG "Copying file: $item"
                cp "$item" "$HOME/"
            elif [[ -d "$item" ]]; then
                PRINTLOG "Copying directory: $item"
                cp -r "$item" "$HOME/"
            else
                PRINT_WARN "Skipping non-file/directory: $item"
            fi
        done
    fi
done

rm -rf "$temp_dir"





fi
