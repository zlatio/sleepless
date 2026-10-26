#!/usr/bin/osascript -l JavaScript
// Alfred Script Filter: shows whether the Mac is awake, with the actions that fit.
// Alfred filters the items by the query, so typing "1h" or "off" narrows the list.

function run() {
  const app = Application.currentApplication()
  app.includeStandardAdditions = true

  let output
  try {
    output = app.doShellScript("./sleepless status --json")
  } catch (error) {
    return JSON.stringify({ items: [{ title: "Can't reach Sleepless", subtitle: error.message, valid: false }] })
  }

  const status = JSON.parse(output)
  // The app keeps the display on by default, and status has no setting to report while the app isn't running.
  const keepDisplayAwake = status.keepDisplayAwake !== false
  const details = hold =>
    [
      hold.expiresAt && `until ${new Date(hold.expiresAt).toLocaleTimeString(undefined, { timeStyle: "short" })}`,
      hold.pid && `while pid ${hold.pid}`,
    ]
      .filter(Boolean)
      .join(", ")

  const toggle = status.active
    ? {
        title: "Let the Mac sleep",
        subtitle: `Awake now, held by ${status.holds.map(hold => `${hold.name} ${details(hold)}`.trim()).join("; ")}`,
        arg: "off",
      }
    : {
        title: "Keep the Mac awake",
        subtitle: status.version ? "Sleeping normally now" : "Sleeping normally now. Sleepless isn't running.",
        arg: "on",
      }
  const releases =
    status.holds.length > 1
      ? status.holds.map(hold => ({
          title: `Release ${hold.name}`,
          subtitle: details(hold) || "No time limit",
          arg: `release ${hold.name}`,
        }))
      : []
  const durations = [
    { title: "Keep awake for 15 minutes", arg: "on --for 15m" },
    { title: "Keep awake for 30 minutes", arg: "on --for 30m" },
    { title: "Keep awake for 1 hour", arg: "on --for 1h" },
    { title: "Keep awake for 2 hours", arg: "on --for 2h" },
    { title: "Keep awake indefinitely", arg: "on --for forever" },
  ].map(item => ({
    ...item,
    subtitle: keepDisplayAwake ? "Display stays on. Hold ⌥ to let it sleep." : "Display can sleep. Hold ⌥ to keep it on.",
    mods: {
      alt: {
        arg: `${item.arg} ${keepDisplayAwake ? "--no-display" : "--display"}`,
        subtitle: keepDisplayAwake ? "Let the display sleep from now on" : "Keep the display on from now on",
      },
    },
  }))
  const items = [toggle, ...releases, ...durations].map(item => ({ ...item, match: `${item.title} ${item.arg}` }))

  return JSON.stringify({ items })
}
