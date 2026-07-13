# TODO(upstream-keystone): modules/os/journal-remote.nix — carries the
# journal-remote half of milestone fix 1dbaa921 (reset ListenStream before
# binding localhost) until it lands on keystone main. mkOverride 40 beats the
# upstream mkForce (50). Gate mirrors upstream's `isServer && useNginxProxy`;
# only the journalRemote host with a domain (ocean) matches.
{
  config,
  lib,
  ...
}:
let
  cfg = config.keystone.os.journalRemote;
  hostname = config.networking.hostName;
  journalRemoteHosts = lib.filterAttrs (_: h: h.journalRemote or false) config.keystone.hosts;
  journalRemoteHostNames = lib.attrNames journalRemoteHosts;
  derivedServerHost =
    if journalRemoteHostNames != [ ] then
      (builtins.getAttr (builtins.head journalRemoteHostNames) journalRemoteHosts).hostname
    else
      null;
  effectiveServerHost = if cfg.serverHost != null then cfg.serverHost else derivedServerHost;
  isServer = effectiveServerHost == hostname;
  useNginxProxy = config.keystone.domain != null;
in
{
  config = lib.mkIf (config.keystone.os.enable && isServer && useNginxProxy) {
    systemd.sockets.systemd-journal-remote.listenStreams = lib.mkOverride 40 [
      # Reset systemd's upstream ListenStream=19532 before adding the
      # localhost-only listener; otherwise the wildcard listener races the
      # explicit IPv4 bind.
      ""
      "127.0.0.1:${toString cfg.server.port}"
    ];
  };
}
