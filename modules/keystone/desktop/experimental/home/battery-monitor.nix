# TODO(upstream-keystone): modules/desktop/home/scripts/default.nix — carries
# the unit-condition half of milestone fix 29879827 until it lands on main:
# skip the battery monitor entirely on hosts without a battery. The script-body
# hardening from that commit is not carried; main already guards empty output.
{ ... }:
{
  systemd.user.services.keystone-battery-monitor.Unit.ConditionPathExistsGlob =
    "/sys/class/power_supply/BAT*";
  systemd.user.timers.keystone-battery-monitor.Unit.ConditionPathExistsGlob =
    "/sys/class/power_supply/BAT*";
}
