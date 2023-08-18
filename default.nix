{ pkgs, lib, config, ... }:
{
  config = lib.mkMerge [{
    nixpkgs.overlays = [
      (final: prev: {
        fetchFromMicrosoft = final.callPackage ./fetchFromMicrosoft.nix {};
      })    
    ];
	environment.systemPackages = [
      (pkgs.writeShellScriptBin "mido_get_langs" ''
	      usage() {
              echo "Usage: mido_get_langs <productID> <windowsVersion>"
			  echo "For more details visit https://github.com/physics-enthusiast/mido-nix"
		  }
          for arg in "$@"; do
              if [ "$arg" = "-h" ] ||  [ "$arg" = "--help" ]; then
                  usage
                  exit
              fi
		  done
          product_edition_id=$1
          windows_version=$2
          url="https://www.microsoft.com/en-US/software-download/windows$windows_version"
          case "$windows_version" in
              8 | 10) url="''${url}ISO" ;;
          esac
          user_agent="Mozilla/5.0 (X11; Linux x86_64; rv:100.0) Gecko/20100101 Firefox/100.0"
          session_id="$(${pkgs.coreutils}/bin/cat /proc/sys/kernel/random/uuid 2> /dev/null || ${pkgs.libuuid}/bin/uuidgen --random)"
          ${pkgs.curl}/bin/curl --silent --output /dev/null --user-agent "$user_agent" --header "Accept:" --fail --proto =https --tlsv1.2 --http1.1 -- "https://vlscppe.microsoft.com/tags?org_id=y6jn8c31&session_id=$session_id"
          url_segment_parameter="''${url##*/}"
          language_skuid_table_html="$(${pkgs.curl}/bin/curl --silent --request POST --user-agent "$user_agent" --data "" --header "Accept:" --fail --proto =https --tlsv1.2 --http1.1 -- "https://www.microsoft.com/en-US/api/controls/contentinclude/html?pageId=a8f8f489-4c7f-463a-9ca6-5cff94d8d041&host=www.microsoft.com&segments=software-download,$url_segment_parameter&query=&action=getskuinformationbyproductedition&sessionId=$session_id&productEditionId=$product_edition_id&sdVersion=2")"
          language_skuid_table_html="$(echo "$language_skuid_table_html" | head --bytes 10240)"
          echo "$language_skuid_table_html" | ${pkgs.gnugrep}/bin/grep "option value.*id" | ${pkgs.gnused}/bin/sed 's/&quot;//g'| ${pkgs.coreutils}/bin/cut --delimiter ':' --fields 3  | ${pkgs.coreutils}/bin/cut --delimiter '}' --fields 1
      '')
    ];
  }];
}
