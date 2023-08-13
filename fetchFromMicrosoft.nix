{ lib, buildPackages ? { inherit stdenvNoCC; }, stdenvNoCC
, curl # Note that `curl' may be `null', in case of the native stdenvNoCC.
, cacert ? null, ncurses, toybox }:

let

  impureEnvVars = lib.fetchers.proxyImpureEnvVars ++ [
    # This variable allows the user to pass additional options to curl
    "NIX_CURL_FLAGS"
  ];

in

{ # ISO to fetch. See https://massgrave.dev/msdl/ for a list of available product IDs.
  productID
, windowsVersion
, language ? "English (United States)"

, # Additional curl options needed for the download to succeed.
  # Warning: Each space (no matter the escaping) will start a new argument.
  # If you wish to pass arguments with spaces, use `curlOptsList`
  curlOpts ? ""

, # Additional curl options needed for the download to succeed.
  curlOptsList ? []

, # Name of the file.  If empty, use the basename of `url' (or of the
  # first element of `urls').
  name ? ""

  # for versioned downloads optionally take pname + version.
, pname ? ""
, version ? ""

, # SRI hash.
  hash ? ""

, # Legacy ways of specifying the hash.
  outputHash ? ""
, outputHashAlgo ? ""
, sha1 ? ""
, sha256 ? ""
, sha512 ? ""

, # Shell code to build a netrc file for BASIC auth
  netrcPhase ? null

, # Impure env vars (https://nixos.org/nix/manual/#sec-advanced-attributes)
  # needed for netrcPhase
  netrcImpureEnvVars ? []

, # Shell code executed after the file has been fetched
  # successfully. This can do things like check or transform the file.
  postFetch ? ""

, # Whether to download to a temporary path rather than $out. Useful
  # in conjunction with postFetch. The location of the temporary file
  # is communicated to postFetch via $downloadedFile.
  downloadToTemp ? false

  # Doing the download on a remote machine just duplicates network
  # traffic, so don't do that by default
, preferLocalBuild ? true

  # Additional packages needed as part of a fetch
, nativeBuildInputs ? [ ]
}:

let
  hash_ =
    # Many other combinations don't make sense, but this is the most common one:
    if hash != "" && sha256 != "" then throw "multiple hashes passed" else

    if hash != "" then { outputHashAlgo = null; outputHash = hash; }
    else if (outputHash != "" && outputHashAlgo != "") then { inherit outputHashAlgo outputHash; }
    else if sha512 != "" then { outputHashAlgo = "sha512"; outputHash = sha512; }
    else if sha256 != "" then { outputHashAlgo = "sha256"; outputHash = sha256; }
    else if sha1   != "" then { outputHashAlgo = "sha1";   outputHash = sha1; }
    else if cacert != null then { outputHashAlgo = "sha256"; outputHash = ""; }
    else throw "fetchFromMicrosoft requires a hash for it's fixed-output derivation";
in

stdenvNoCC.mkDerivation ((
  if (pname != "" && version != "") then
    { inherit pname version; }
  else
    { name =
      if name != "" then name
      else "WindowsISO";
    }
) // {
  builder = ./builder.sh;

  nativeBuildInputs = [ curl ncurses toybox ] ++ nativeBuildInputs;

  # New-style output content requirements.
  inherit (hash_) outputHashAlgo outputHash;

  SSL_CERT_FILE = if (hash_.outputHash == "" || hash_.outputHash == lib.fakeSha256 || hash_.outputHash == lib.fakeSha512 || hash_.outputHash == lib.fakeHash)
                  then "${cacert}/etc/ssl/certs/ca-bundle.crt"
                  else "/no-cert-file.crt";

  outputHashMode = "flat";

  curlOpts = lib.warnIf (lib.isList curlOpts) ''
    fetchurl for ${toString (builtins.head urls_)}: curlOpts is a list (${lib.generators.toPretty { multiline = false; } curlOpts}), which is not supported anymore.
    - If you wish to get the same effect as before, for elements with spaces (even if escaped) to expand to multiple curl arguments, use a string argument instead:
      curlOpts = ${lib.strings.escapeNixString (toString curlOpts)};
    - If you wish for each list element to be passed as a separate curl argument, allowing arguments to contain spaces, use curlOptsList instead:
      curlOptsList = [ ${lib.concatMapStringsSep " " lib.strings.escapeNixString curlOpts} ];'' curlOpts;
  curlOptsList = lib.escapeShellArgs curlOptsList;
  inherit postFetch downloadToTemp;

  impureEnvVars = impureEnvVars ++ netrcImpureEnvVars;

  nixpkgsVersion = lib.trivial.release;

  inherit preferLocalBuild;

  postHook = if netrcPhase == null then null else ''
    ${netrcPhase}
    curlOpts="$curlOpts --netrc-file $PWD/netrc"
  '';
})
