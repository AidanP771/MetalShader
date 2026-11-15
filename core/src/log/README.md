# log

`MMLogDebug`, `MMLogInfo` and `MMLogError` wrap `os_log` under the subsystem
`io.metalmix`, category `core`. The loader logs under the same subsystem with
category `loader`, so one command shows both:

```sh
log stream --predicate 'subsystem == "io.metalmix"' --level debug
```

Write messages as plain sentences a player could read, plus the values needed to
act on them. Use `%{public}s` for strings, or Console shows `<private>`.

Planned for M3: a rolling file mirror in `~/Library/Logs/MetalMix/` for
`mm-report.command` to collect.
