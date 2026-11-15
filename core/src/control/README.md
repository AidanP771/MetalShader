# control

The developer control server that `mmctl` talks to. Dev builds only: Release
builds compile it out. Starts in M4.

## Socket

`~/Library/Application Support/MetalMix/ctl.sock`, a Unix domain socket with
permissions `0600` (only the user running the game can connect).

## Protocol

Plain text, one request per connection:

1. The client sends one line: the command and its arguments separated by
   spaces, ending in `\n`. Example: `set Vibrance.strength 0.4`
2. The server replies with any number of lines, then closes the connection.
   The first line is `ok` or `error: <plain sentence>`.

Plain text keeps it easy to use over SSH and easy to read in logs.

## Commands

See `tools/mmctl/README.md` for the list. Adding a command means updating that
README and `docs/dev-setup.md` in the same change.

## Threading

The server runs on its own dispatch queue. Commands that change rendering state
hand their change to the runtime, which applies it at the start of the next
frame. The server never touches Metal objects directly.
