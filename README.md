# Miaow motion update channel

Stable data-only update feed for the Android online wallpaper and iPhone browser companion. This independent branch contains metadata only: no real pet images, movies, app binaries, credentials or claim links. The main branch remains the existing generic iOS code-only build. No CI workflow is present here.

Clients pin the channel address, check sequence/schema/client format and the manifest SHA, then verify each media SHA/size before atomic activation. Data updates do not execute remote code. The current activation package has22 actual playable clips: 21 of the original30 planned states and one extra idle glance. Sequence6 adds a3-second paw-pad reaction and a4-second ear scratch, preserving the prior20 media SHAs. Idle scratches may enter random idle selection; touch reactions do not. Owner identity and naturalness review remains pending. Test-only cloned actions are never published.

Media is stored at the user-authorized public hosting URL in channel.json; a new anonymous host must be claimed by the owner to persist. `source_initial_expiry` is the original unclaimed deadline, not an assertion that later owner claiming has failed. The current consumer web link can stay the same for future motion updates; binaries/app-shell changes may still require app/version updates.

Only the owner or an authorized publisher should advance channel.json after checking the remote manifest and all new assets. Never add access tokens, signing keys, claim URLs, raw private references or media to this branch. Keep previous channel history; no force-push.
