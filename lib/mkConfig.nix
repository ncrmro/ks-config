# ks-config loader: reads the committed keystone.json (generated from
# keystone.yaml), validates it with diagnostics that name YAML config paths,
# resolves key references, and checks that every enabled service's required
# secrets exist before any host evaluation begins.
#
# Standalone smoke test:
#   nix eval --file lib/mkConfig.nix summary --json
{
  configFile ? ../keystone.json,
  secretsDir ? ../secrets,
  # Service catalog from the services flake (ports, requiredSecrets). The
  # relative default only serves --file eval inside the workspace; the flake
  # passes keystone-services.lib.catalog explicitly.
  catalog ? import ../../services/lib/catalog.nix,
}:
let
  raw = builtins.fromJSON (builtins.readFile configFile);

  # --- validation helpers (diagnostics-first: name the config path) --------
  requireAttr =
    path: attrs: name:
    if attrs ? ${name} then
      attrs.${name}
    else
      throw "keystone.yaml: missing required field `${path}.${name}`";

  knownHostKinds = [
    "laptop"
    "workstation"
    "server"
    "macbook"
  ];

  # --- key registry ---------------------------------------------------------
  hardwareKeys = raw.keys.hardware or { };

  resolveSshKeys =
    path: names:
    map (
      name:
      if hardwareKeys ? ${name} then
        requireAttr "keys.hardware.${name}" hardwareKeys.${name} "sshPublicKey"
      else
        throw "keystone.yaml: `${path}` references unknown key `${name}`; known keys: ${builtins.concatStringsSep ", " (builtins.attrNames hardwareKeys)}"
    ) names;

  # Age recipients only exist for keys that declare one (Secure Enclave keys
  # are SSH-only clients, not portable recipients).
  ageRecipients = builtins.filter (r: r != null) (
    map (k: k.ageRecipient or null) (builtins.attrValues hardwareKeys)
  );

  # --- access policy: each surface selects keys explicitly ------------------
  access = raw.access or { };
  resolvedAccess = {
    admin = resolveSshKeys "access.admin.sshKeys" (access.admin.sshKeys or [ ]);
    root = {
      enable = access.root.enable or false;
      sshKeys = resolveSshKeys "access.root.sshKeys" (access.root.sshKeys or [ ]);
    };
    installer = resolveSshKeys "access.installer.sshKeys" (access.installer.sshKeys or [ ]);
    remoteUnlock = resolveSshKeys "access.remoteUnlock.sshKeys" (access.remoteUnlock.sshKeys or [ ]);
  };

  # --- hosts -----------------------------------------------------------------
  validateHost =
    name: host:
    let
      kind = requireAttr "hosts.${name}" host "kind";
    in
    if builtins.elem kind knownHostKinds then
      host
    else
      throw "keystone.yaml: `hosts.${name}.kind` is `${kind}`; expected one of: ${builtins.concatStringsSep ", " knownHostKinds}";

  hosts = builtins.mapAttrs validateHost (raw.hosts or { });

  # --- clusters ---------------------------------------------------------------
  validateCluster =
    name: cluster:
    let
      nodes = (cluster.controlPlane or [ ]) ++ (cluster.workers or [ ]);
      unknown = builtins.filter (n: !(hosts ? ${n})) nodes;
    in
    if unknown == [ ] then
      cluster
    else
      throw "keystone.yaml: `clusters.${name}` references unknown hosts: ${builtins.concatStringsSep ", " unknown}";

  clusters = builtins.mapAttrs validateCluster (raw.clusters or { });

  # --- services ---------------------------------------------------------------
  rawServices = raw.services or { };
  knownServices = [
    "forgejo"
    "vaultwarden"
    "immich"
  ];
  knownFrontdoors = [
    "nginx"
    "kubernetes"
  ];
  knownTls = builtins.attrNames catalog.frontdoor.tlsSecrets;

  frontdoor = rawServices.frontdoor or "nginx";
  tls = rawServices.tls or "none";

  secretExists = name: builtins.pathExists (secretsDir + "/${name}.age");
  missingSecretError =
    path: names:
    throw "keystone.yaml: `${path}` is enabled but required secrets are missing from secrets/: ${builtins.concatStringsSep ", " (map (n: "${n}.age") names)} — create each with `agenix -e <name>.age` in the secrets directory";

  validateService =
    name:
    let
      svc = rawServices.${name};
      host = svc.host or null;
      missing = builtins.filter (s: !secretExists s) catalog.${name}.requiredSecrets;
    in
    if host == null then
      svc
    else if !(hosts ? ${host}) then
      throw "keystone.yaml: `services.${name}.host` is `${host}`, which is not a declared host; known hosts: ${builtins.concatStringsSep ", " (builtins.attrNames hosts)}"
    else if missing != [ ] then
      missingSecretError "services.${name}" missing
    else
      svc;

  anyServiceEnabled = builtins.any (
    name: rawServices ? ${name} && (rawServices.${name}.host or null) != null
  ) knownServices;

  missingTlsSecrets = builtins.filter (s: !secretExists s) catalog.frontdoor.tlsSecrets.${tls};

  services =
    if rawServices == { } then
      { }
    else if !(builtins.elem frontdoor knownFrontdoors) then
      throw "keystone.yaml: `services.frontdoor` is `${frontdoor}`; expected one of: ${builtins.concatStringsSep ", " knownFrontdoors}"
    else if !(builtins.elem tls knownTls) then
      throw "keystone.yaml: `services.tls` is `${tls}`; expected one of: ${builtins.concatStringsSep ", " knownTls}"
    else if anyServiceEnabled && !(rawServices ? domain) then
      throw "keystone.yaml: `services.domain` is required when any service is enabled"
    else if anyServiceEnabled && missingTlsSecrets != [ ] then
      missingSecretError "services.tls = ${tls}" missingTlsSecrets
    else
      {
        inherit frontdoor tls;
        domain = rawServices.domain or null;
        kubernetes = rawServices.kubernetes or { };
      }
      // builtins.listToAttrs (
        map (name: {
          inherit name;
          value = if rawServices ? ${name} then validateService name else { host = null; };
        }) knownServices
      );

  # Nix is lazy: a bad reference goes unnoticed until something evaluates it.
  # deepSeq forces the whole resolved config so every validation fires up
  # front, regardless of which outputs are built.
  strictly =
    value:
    builtins.deepSeq {
      inherit
        resolvedAccess
        hosts
        clusters
        services
        ;
    } value;
in
strictly {
  inherit
    hosts
    clusters
    services
    ageRecipients
    ;
  admin = requireAttr "" raw "admin";
  access = resolvedAccess;
  defaults = raw.defaults or { };
  secretsBackend = raw.secrets.backend or "agenix";
  keys = hardwareKeys;

  # Compact view for `nix eval` smoke tests.
  summary = {
    admin = raw.admin.username;
    hostKinds = builtins.mapAttrs (_: h: h.kind) hosts;
    adminSshKeys = resolvedAccess.admin;
    inherit ageRecipients;
    services = {
      inherit frontdoor tls;
      enabled = builtins.filter (
        name: services ? ${name} && (services.${name}.host or null) != null
      ) knownServices;
    };
    clusters = builtins.mapAttrs (_: c: {
      inherit (c) type;
      nodes = (c.controlPlane or [ ]) ++ (c.workers or [ ]);
    }) clusters;
  };
}
