# pr-assets

Screenshots and screen recordings that PR and MR descriptions link to.

## Why this folder exists

The PR template requires screenshots or video for any frontend change. In the web UI
you satisfy that by dragging a file into the description box, which uploads it to
GitHub's attachment CDN. **There is no CLI equivalent** — `gh pr create` cannot attach
files, so a PR opened from the terminal could never meet the requirement. Committing
the media to the branch and linking it is the way to satisfy it from anywhere.

## Link them — do not embed them

Our repos are private, and **inline `![](...)` embeds of committed files do not render
in a private repo.** GitHub serves markdown images through its camo proxy, which
fetches anonymously and gets a 404 on private content. Embeds silently render as a
broken image.

So write a plain link, not an image embed:

```markdown
[Mobile nav after the fix](https://github.com/harbourspace-org/website/blob/9a3f21c4.../.github/pr-assets/hsdev-858-mobile-nav.webp)
```

Anyone with repo access clicks it and sees the image in GitHub's file viewer, which
also gives `.mp4` a real video player.

### Use a commit permalink, not a branch name

Link to the **commit SHA**, never to `main` or your branch name. Branch links die when
the branch is deleted on merge, and `main` links die when the file is later pruned
(see below). A SHA permalink keeps working forever.

Print the correct URL for a file you have just committed:

```sh
f=.github/pr-assets/hsdev-858-mobile-nav.webp
echo "https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/blob/$(git rev-parse HEAD)/$f"
```

On GitLab the same folder is used, with a `/-/blob/` path:

```sh
echo "https://gitlab.com/harbourspace/laravel/-/blob/$(git rev-parse HEAD)/$f"
```

## Naming

`<ticket>-<what-it-shows>.<ext>` — e.g. `hsdev-858-mobile-nav.webp`,
`hsdev-902-checkout-flow.mp4`. The ticket prefix is what makes pruning safe later.

## Keep the files small

Everything here is committed to git, and **git history is permanent**: deleting a file
later does not shrink the repo, the blob stays in history forever. Pruning keeps the
working tree tidy, it does not reclaim space. So the real discipline is not adding
large files in the first place.

- **Stills** — `.webp`, or `.png` if you must. Aim well under 1MB.
  ```sh
  cwebp -q 80 shot.png -o hsdev-858-mobile-nav.webp
  ```
- **Recordings** — `.mp4` (H.264). Never `.gif`; a GIF of the same clip is roughly ten
  times the size.
  ```sh
  ffmpeg -i recording.mov -vcodec libx264 -crf 28 -preset veryfast -an hsdev-902-checkout-flow.mp4
  ```
- Keep any single file under ~5MB. GitHub hard-rejects a push containing a file over
  100MB, and warns over 50MB.

## Pruning

Keep this folder under **~100MB**. When it goes over, delete the oldest files — their
PRs are long merged and the permalinks in those old descriptions keep working from
history regardless.

`prune.sh` does it correctly. Reach for it rather than `ls -t`: git does not preserve
modification times, so in a fresh clone every file here looks equally old. The script
sorts by last-commit date instead.

```sh
.github/pr-assets/prune.sh            # dry run — shows what it would delete
.github/pr-assets/prune.sh --apply    # actually git rm the oldest, then commit
```
