Vendored from https://github.com/romnycristopher/claude-am-mods at commit 43d1375
(am-context-bar 0.3.20, MIT, see LICENSE). Copied (not installed from upstream) so an
upstream update can't change what runs. Reviewed: its only `$.process.run` calls are the two
fixed `git` commands in hooks/register.tsx; no `$.http`, `$.fs`, `$.env`, `$.model`, `$.agent`
or `$.tool`. Before updating, repeat that grep on the new version.
