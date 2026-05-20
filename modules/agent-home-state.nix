# Symlink the canonical agent-state tree (this flake's `agents/`) into each
# local agent's home directory. Mirrors PR #29's pattern of treating the
# repo as the source of truth and exposing it through `~/...` paths the
# agent's CLI tools (Claude, Codex, Gemini) read natively.
#
# Per-host: only wires agents whose `keystone.os.agents.<name>.host`
# matches `networking.hostName`. Other agents' state files live on their
# assigned host.
#
# Tracked files (committed): TEAM.md, HUMAN.md, PROJECTS.yaml, and the
# per-agent SOUL.md / ROLE.md / AGENTS.md.
#
# Runtime files (gitignored, touched by activation): TASKS.yaml,
# SCHEDULES.yaml, ISSUES.yaml. Activation creates the empty target file
# in the flake checkout if it does not already exist so the symlink has
# something to point at.
{
  config,
  lib,
  options,
  ...
}:
with lib;
let
  osCfg = config.keystone.os;
  flakePath = config.keystone.systemFlake.path;
  hostName = config.networking.hostName;

  # Agents enabled on this host (terminal must be on; otherwise the agent
  # has no home-manager block to extend).
  localAgents = filterAttrs (
    _name: agentCfg: agentCfg.host == hostName && agentCfg.terminal.enable
  ) osCfg.agents;

  # Shared symlinks — same target file for every agent on this host.
  sharedFiles = {
    "TEAM.md" = "${flakePath}/agents/TEAM.md";
    "HUMAN.md" = "${flakePath}/agents/HUMAN.md";
    "PROJECTS.yaml" = "${flakePath}/agents/PROJECTS.yaml";
  };

  # Skill-tree + per-tool top-level docs. All three CLI tools (Claude,
  # Codex, Gemini) read these natively; the canonical skill content lives
  # in `agents/skills/` and the operating rules in `agents/_shared/AGENTS.md`.
  # nixos-config#29 wires these for ncrmro via the keystone aiExtensions
  # surface; agent users need the same wiring through this module.
  skillTreeFiles = {
    ".agents/skills" = "${flakePath}/agents/skills";
    ".claude/skills" = "${flakePath}/agents/skills";
    ".claude/CLAUDE.md" = "${flakePath}/agents/_shared/AGENTS.md";
    ".gemini/GEMINI.md" = "${flakePath}/agents/_shared/AGENTS.md";
    ".codex/AGENTS.md" = "${flakePath}/agents/_shared/AGENTS.md";
  };

  # Tracked per-agent files. SOUL/ROLE/AGENTS are in-repo.
  perAgentTracked = name: {
    "SOUL.md" = "${flakePath}/agents/${name}/SOUL.md";
    "ROLE.md" = "${flakePath}/agents/${name}/ROLE.md";
    "AGENTS.md" = "${flakePath}/agents/${name}/AGENTS.md";
  };

  # Runtime state files. Gitignored in the flake; activation `touch`es
  # the target in the checkout if missing so the symlink resolves.
  runtimeFileNames = [
    "TASKS.yaml"
    "SCHEDULES.yaml"
    "ISSUES.yaml"
  ];

  runtimeTargets = name: map (fname: "${flakePath}/agents/${name}/${fname}") runtimeFileNames;
in
{
  config = mkIf (osCfg.enable && localAgents != { }) (
    optionalAttrs (options ? home-manager) {
      home-manager.users = mapAttrs' (
        name: _agentCfg:
        nameValuePair "agent-${name}" (
          { config, lib, ... }:
          let
            mkLink = target: config.lib.file.mkOutOfStoreSymlink target;
            runtimeLinks = lib.listToAttrs (
              map (
                fname: lib.nameValuePair fname { source = mkLink "${flakePath}/agents/${name}/${fname}"; }
              ) runtimeFileNames
            );
            sharedLinks = lib.mapAttrs (_n: t: { source = mkLink t; }) sharedFiles;
            trackedLinks = lib.mapAttrs (_n: t: { source = mkLink t; }) (perAgentTracked name);
            skillTreeLinks = lib.mapAttrs (_n: t: { source = mkLink t; }) skillTreeFiles;
          in
          {
            # CRITICAL: these symlinks point INTO the consumer flake checkout
            # via mkOutOfStoreSymlink so an `ks update --dev` immediately
            # reflects edits without a rebuild. The runtime files live behind
            # the gitignore — activation pre-creates them so the symlinks are
            # not dangling on first deploy.
            home.file = sharedLinks // trackedLinks // runtimeLinks // skillTreeLinks;

            home.activation.agentStateTouchRuntime = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
              for target in ${lib.escapeShellArgs (runtimeTargets name)}; do
                if [ ! -e "$target" ]; then
                  mkdir -p "$(dirname "$target")"
                  : > "$target"
                fi
              done
            '';
          }
        )
      ) localAgents;
    }
  );
}
