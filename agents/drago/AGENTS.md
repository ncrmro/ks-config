# drago — legacy agent instructions

Drago persona rules live in `agents/applepi/profiles/drago/profile.yml`.
Shared engineering delivery workflow rules live in the inherited
`agents/applepi/profiles/platform-engineer/profile.yml` role base.

Keep this file free of ApplePi-era delivery constraints so non-ApplePi symlinks do
not silently override profile-scoped behavior.
