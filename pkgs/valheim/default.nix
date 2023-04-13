{
  stdenvNoCC,
  fetchSteam,
  autoPatchelfHook,
}:
stdenvNoCC.mkDerivation rec {
  name = "valheim-server";
  version = "0.215.2";
  src = fetchSteam {
    inherit name;
    appId = "896660";
    depotId = "896661";
    manifestId = "1096250207355556362";
    hash = "sha256-oOHBv//sgpvowiXmongc49t6hjZt1vRQKl+or20oi+o=";
  };

  # Skip phases that don't apply to prebuilt binaries.
  dontBuild = true;
  dontConfigure = true;

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  postFixup = ''
    chmod +x valheim_server.x86_64
  '';

  installPhase = ''
    runHook preInstall

    mkdir $out
    cp -r \
      $src/*.so \
      $src/*.debug \
      $src/valheim_server.x86_64 \
      $src/valheim_server_Data \
      $out

    runHook postInstall
  '';
}