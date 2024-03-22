{ hostPlatform, callPackage }: {
  thorium-browser = if hostPlatform.system == "aarch64-linux"
    then callPackage ./thorium-aarch64.nix { }
    else callPackage ./thorium-amd64.nix { };
}
