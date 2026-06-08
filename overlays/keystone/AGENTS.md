# keystone-bound overlay holding area

Local overlays staged here are destined for keystone's overlay set but held in
ks-config to unblock local work until they can be upstreamed to `../keystone`.

Each overlay must carry a `TODO(upstream-keystone):` comment naming its keystone
destination. Overlays are wired into the consumer package set via
`overlays/default.nix`, alongside `inputs.keystone.overlays.default`.

See `modules/keystone/AGENTS.md` ("Holding area for keystone-bound changes") for
the full convention.
