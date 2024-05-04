{
  lib,
  stdenv,
  fetchSteam,
}:
stdenv.mkDerivation rec {
  name = "valheim-server";
  version = "0.217.38";
  src = fetchSteam {
    inherit name;
    appId = "896660";
    depotId = "896661";
    manifestId = "252049227837324070";
    hash = "sha256-b5a5lvxwxebSNx64tQDASpx/MS/o4PeABX9al3/NbhU=";
  };

  # Skip phases that don't apply to prebuilt binaries.
  dontBuild = true;
  dontConfigure = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r \
      *.so \
      *.debug \
      valheim_server.x86_64 \
      valheim_server_Data \
      $out

    chmod +x $out/valheim_server.x86_64

    runHook postInstall
  '';

  meta = with lib; {
    description = "Valheim dedicated server";
    homepage = "https://steamdb.info/app/896660/";
    changelog = "https://store.steampowered.com/news/app/892970?updates=true";
    sourceProvenance = with sourceTypes; [binaryBytecode binaryNativeCode];
    license = licenses.unfree;
    maintainers = with maintainers; [aidalgol];
    platforms = ["x86_64-linux"];
  };
}
