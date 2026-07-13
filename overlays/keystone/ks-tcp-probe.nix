# TODO(upstream-keystone): packages/ks — carries milestone fix 8830b560
# (probe host reachability via TCP connect instead of an auth-required ssh
# probe) until it lands on keystone main. -p3 strips a/packages/ks/ because
# the crane src root is packages/ks. No new cargo deps, so the vendored
# dependency artifacts are unaffected.
final: prev: {
  keystone = prev.keystone // {
    ks = prev.keystone.ks.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [ ./ks-tcp-probe.patch ];
      patchFlags = [ "-p3" ];
    });
  };
}
