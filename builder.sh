# Copyright (C) 2023 Elliot Killick <contact@elliotkillick.com>
# Licensed under the MIT License. See LICENSE file for details.

if [ -e .attrs.sh ]; then source .attrs.sh; fi
source $stdenv/setup

# Test for 4-bit color (16 colors)
# Operand "colors" is undefined by POSIX
# If the operand doesn't exist, the terminal probably doesn't support color and the program will continue normally without it
if [ "0$(tput colors 2> /dev/null)" -ge 16 ]; then
    RED='\033[0;31m'
    BLUE='\033[0;34m'
    GREEN='\033[0;32m'
    NC='\033[0m'
fi

# Avoid printing messages as potential terminal escape sequences
echo_ok() { printf "%b%s%b" "${GREEN}[+]${NC} " "$1" "\n" >&2; }
echo_info() { printf "%b%s%b" "${BLUE}[i]${NC} " "$1" "\n" >&2; }
echo_err() { printf "%b%s%b" "${RED}[!]${NC} " "$1" "\n" >&2; }

format() { fmt --width 80; }

word_count() { echo $#; }

curlVersion=$(curl -V | head -1 | cut -d' ' -f2)

# Curl flags to handle redirects, not use EPSV, handle cookies for
# servers to need them during redirects, and work on SSL without a
# certificate (this isn't a security problem because we check the
# cryptographic hash of the output anyway).
curl=(
    curl
    --location
    --max-redirs 20
    --retry 3
    --disable-epsv
    --cookie-jar cookies
)

if ! [ -f "$SSL_CERT_FILE" ]; then
    curl+=(--insecure)
fi

eval "curl+=($curlOptsList)"

downloadedFile="$out"
if [ -n "$downloadToTemp" ]; then downloadedFile="$TMPDIR/file"; fi

handle_curl_error() {
    error_code="$1"

    fatal_error_action=2

    case "$error_code" in
        6)
            echo_err "Failed to resolve Microsoft servers! Is there an Internet connection? Exiting..."
            return "$fatal_error_action"
            ;;
        7)
            echo_err "Failed to contact Microsoft servers! Is there an Internet connection or is the server down?"
            ;;
        23)
            echo_err "Failed at writing Windows media to disk! Out of disk space or permission error? Exiting..."
            return "$fatal_error_action"
            ;;
        26)
            echo_err "Ran out of memory during download! Exiting..."
            return "$fatal_error_action"
            ;;
        36)
            echo_err "Failed to continue earlier download!"
            ;;
        22)
            echo_err "Microsoft servers returned failing HTTP status code!"
            ;;
        # POSIX defines exit statuses 1-125 as usable by us
        # https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html#tag_18_08_02
        $((error_code <= 125)))
            # Must be some other server error (possibly with this specific request/file)
            # This is when accounting for all possible errors in the curl manual assuming a correctly formed curl command and HTTP(S) request, using only the curl features we're using, and a sane build
            echo_err "Server returned an error status!"
            ;;
        126 | 127)
            echo_err "Curl command not found! Please install curl and try again. Exiting..."
            return "$fatal_error_action"
            ;;
        # Exit statuses are undefined by POSIX beyond this point
        *)
            case "$(kill -l "$error_code")" in
                # Signals defined to exist by POSIX:
                # https://pubs.opengroup.org/onlinepubs/009695399/basedefs/signal.h.html
                INT)
                    echo_err "Curl was interrupted!"
                    ;;
                # There could be other signals but these are most common
                SEGV | ABRT)
                    echo_err "Curl crashed! Failed exploitation attempt? Please report any core dumps to curl developers. Exiting..."
                    return "$fatal_error_action"
                    ;;
                *)
                    echo_err "Curl terminated due to a fatal signal!"
                    ;;
            esac
    esac

    return 1
}

scurl_file() {
    out_file="$1"
    tls_version="$2"
    url="$3"
	local error_code=18;

    part_file="${out_file}.iso"
	while [ $error_code -eq 18 ]; do
		# --location: Microsoft likes to change which endpoint these downloads are stored on but is usually kind enough to add redirects
		# --fail: Return an error on server errors where the HTTP response code is 400 or greater
		if curl --progress-bar --location --output "$part_file" --continue-at - --fail --proto =https "--tlsv$tls_version" --http1.1 -- "$url" ; then
			break
		else
			error_code=$?
			handle_curl_error "$error_code"
			error_action=$?
			return "$error_action"
		fi
	done
}

consumer_download() {
    # Download newer consumer Windows versions from behind gated Microsoft API
    # This function aims to precisely emulate what Fido does down to the URL requests and HTTP headers (exceptions: updated user agent and referer adapts to Windows version instead of always being "windows11") but written in POSIX sh (with coreutils) and curl instead of PowerShell (also simplified to greatly reduce attack surface)
    # However, differences such as the order of HTTP headers and TLS stacks (could be used to do TLS fingerprinting) still exist
    #
    # Command translated: ./Fido -Win 10 -Lang English -Verbose
    # "English" = "English (United States)" (as opposed to the default "English (International)")
    # For testing Fido, replace all "https://" with "http://" and remove all instances of "-MaximumRedirection 0" (to allow redirection of HTTP traffic to HTTPS) so HTTP requests can easily be inspected in Wireshark
    # Fido (command-line only) works under PowerShell for Linux if that makes it easier for you
    # UPDATE: Fido v1.4.2+ no longer works without being edited on Linux due to these issues on the Fido GitHub repo (and possibly others after these): #56 and #58
    #
    # If this function in Mido fails to work for you then please test with the Fido script before creating an issue because we basically just copy what Fido does exactly:
    # https://github.com/pbatard/Fido

    out_file="$downloadedFile"
	product_edition_id="$productID"
    windows_version="$windowsVersion"     # Either 8, 10, or 11

    url="https://www.microsoft.com/en-US/software-download/windows$windows_version"
    case "$windows_version" in
        8 | 10) url="${url}ISO" ;;
    esac

    user_agent="Mozilla/5.0 (X11; Linux x86_64; rv:100.0) Gecko/20100101 Firefox/100.0"
    # uuidgen: For MacOS (installed by default) and other systems (e.g. with no /proc) that don't have a kernel interface for generating random UUIDs
    session_id="$(cat /proc/sys/kernel/random/uuid 2> /dev/null || uuidgen --random)"

    # Permit Session ID
    # "org_id" is always the same value
    curl --output /dev/null --user-agent "$user_agent" --header "Accept:" --fail --proto =https --tlsv1.2 --http1.1 -- "https://vlscppe.microsoft.com/tags?org_id=y6jn8c31&session_id=$session_id" || {
        # This should only happen if there's been some change to how this API works (copy whatever fix Fido implements)
        handle_curl_error $?
        return $?
    }

    # Extract everything after the last slash
    url_segment_parameter="${url##*/}"

    # Get language -> skuID association table
    # SKU ID: This specifies the language of the ISO. We always use "English (United States)", however, the SKU for this changes with each Windows release
    # We must make this request so our next one will be allowed
    # --data "" is required otherwise no "Content-Length" header will be sent causing HTTP response "411 Length Required"
    language_skuid_table_html="$(curl --request POST --user-agent "$user_agent" --data "" --header "Accept:" --fail --proto =https --tlsv1.2 --http1.1 -- "https://www.microsoft.com/en-US/api/controls/contentinclude/html?pageId=a8f8f489-4c7f-463a-9ca6-5cff94d8d041&host=www.microsoft.com&segments=software-download,$url_segment_parameter&query=&action=getskuinformationbyproductedition&sessionId=$session_id&productEditionId=$product_edition_id&sdVersion=2")" || {
        handle_curl_error $?
        return $?
    }

    # Limit untrusted size for input validation
    language_skuid_table_html="$(echo "$language_skuid_table_html" | head --bytes 10240)"
    # tr: Filter for only alphanumerics or "-" to prevent HTTP parameter injection
    sku_id="$(echo "$language_skuid_table_html" | grep "$language" | sed 's/&quot;//g' | cut --delimiter ',' --fields 1  | cut --delimiter ':' --fields 2 | tr --complement --delete '[:alnum:]-' | head --bytes 16)"
    [ "$VERBOSE" ] && echo "SKU ID: $sku_id" >&2

    # Get ISO download link
    # If any request is going to be blocked by Microsoft it's always this last one (the previous requests always seem to succeed)
    # --referer: Required by Microsoft servers to allow request
    iso_download_link_html="$(curl --request POST --user-agent "$user_agent" --data "" --referer "$url" --header "Accept:" --fail --proto =https --tlsv1.2 --http1.1 -- "https://www.microsoft.com/en-US/api/controls/contentinclude/html?pageId=6e2a1789-ef16-4f27-a296-74ef7ef5d96b&host=www.microsoft.com&segments=software-download,$url_segment_parameter&query=&action=GetProductDownloadLinksBySku&sessionId=$session_id&skuId=$sku_id&language=English&sdVersion=2")" || {
        # This should only happen if there's been some change to how this API works
        handle_curl_error $?
        return $?
    }

    # Limit untrusted size for input validation
    iso_download_link_html="$(echo "$iso_download_link_html" | head --bytes 4096)"

    if ! [ "$iso_download_link_html" ]; then
        # This should only happen if there's been some change to how this API works
        echo_err "Microsoft servers gave us an empty response to our request for an automated download. Please manually download this ISO in a web browser: $url"
        return 1
    fi

    if echo "$iso_download_link_html" | grep --quiet "We are unable to complete your request at this time."; then
        echo_err "Microsoft blocked the automated download request based on your IP address. Please manually download this ISO in a web browser here: $url"
        return 1
    fi

    # Filter for 64-bit ISO download URL
    # sed: HTML decode "&" character
    # tr: Filter for only alphanumerics or punctuation
    iso_download_link="$(echo "$iso_download_link_html" | grep --only-matching "https://software.download.prss.microsoft.com.*IsoX64" | cut --delimiter '"' --fields 1 | sed 's/&amp;/\&/g' | tr --complement --delete '[:alnum:][:punct:]' | head --bytes 512)"

    if ! [ "$iso_download_link" ]; then
        # This should only happen if there's been some change to the download endpoint web address
        echo_err "Microsoft servers gave us no download link to our request for an automated download. Please manually download this ISO in a web browser: $url"
        return 1
    fi

    echo_ok "Got latest ISO download link (valid for 24 hours): $iso_download_link"

    # Download ISO
    scurl_file "$out_file" "1.3" "$iso_download_link"
}

# Enable exiting on error
#
# Disable shell globbing
# This isn't necessary given that all unquoted variables (e.g. for determining word count) are set directly by us but it's just a precaution
set -ef

# If script is installed (in the PATH) then remain at PWD
# Otherwise, change directory to location of script
local_dir="$(dirname -- "$(readlink -f -- "$0")")"
case ":$PATH:" in
  *":$local_dir:"*) ;;
  *) cd "$local_dir" || exit ;;
esac

consumer_download





