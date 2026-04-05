# Eternal Terminal Typing Issues - Double Letters & Wrong Line

## Symptoms
- Double letters appearing when typing
- Cursor jumping to wrong line
- Input appearing in wrong location
- General terminal corruption during ET sessions

## Root Causes

### 1. Flow Control (XON/XOFF)
ET can have issues with software flow control enabled. The Ctrl-S/Ctrl-Q sequences can interfere with terminal rendering.

### 2. TERM Variable Mismatch
Ocean is configured with `TERM=xterm-256color` but your client terminal may be sending different escape sequences.

### 3. Terminal Size Sync Issues
ET sometimes doesn't properly handle SIGWINCH (window resize) signals, causing rendering issues.

### 4. Network Latency/Buffering
High latency or packet loss can cause ET's reconnection logic to double-send keystrokes.

## Solutions

### Option 1: Disable Flow Control (Quick Fix)

Add to your shell RC file on ocean (`~/.zshrc`):
```bash
# Disable software flow control for ET sessions
if [[ -n "$ET_VERSION" ]]; then
  stty -ixon
fi
```

### Option 2: Set Proper TERM Variable

On your **client machine** (where you run `et`), before connecting:
```bash
export TERM=xterm-256color
et ncrmro@ocean
```

Or add to your client's shell RC:
```bash
alias eto='TERM=xterm-256color et ncrmro@ocean'
```

### Option 3: Configure ET Client Options

ET has client configuration options. Create `~/.et.cfg` on your client:
```
; Eternal Terminal client configuration
[General]
; Disable jump host if not needed
disable_jump_host=1

; Increase verbosity for debugging (0-9, default 0)
verbose=2

; Terminal type to use
terminal_type=xterm-256color
```

### Option 4: Use ET with tmux/zellij

ET works better when paired with a terminal multiplexer:
```bash
# Connect and immediately attach to zellij
et ncrmro@ocean -- zellij attach -c ocean
```

The multiplexer provides an additional layer of terminal state management.

### Option 5: Adjust NixOS ET Configuration

If issues persist, we can tune the ET daemon configuration on ocean. Options include:
- Adjusting keepalive settings
- Changing the idle timeout
- Modifying buffer sizes

### Option 6: Switch to Mosh

If ET issues are persistent, consider using Mosh instead, which has better terminal handling:
```nix
# In hosts/common/optional/mosh.nix
{ pkgs, ... }: {
  programs.mosh.enable = true;
  networking.firewall.allowedUDPPortRanges = [
    { from = 60000; to = 61000; }  # Mosh port range
  ];
}
```

Then connect with:
```bash
mosh ncrmro@ocean
```

## Recommended Testing Order

1. **Test with flow control disabled** - Run `stty -ixon` in your ET session
2. **Verify TERM matches** - Check `echo $TERM` on both client and in ET session
3. **Test with tmux/zellij** - See if multiplexer helps
4. **Check network quality** - Run `ping ocean` to check for packet loss
5. **Try SSH instead** - Does regular SSH have the same issues?

## Debugging Commands

```bash
# Check current terminal settings in ET session
stty -a

# Check ET version
et --version

# Check for flow control
stty -ixon  # Disable
stty ixon   # Enable

# Check terminal size
echo $COLUMNS x $LINES
tput cols
tput lines

# Monitor ET connection
et ncrmro@ocean -v 9  # Maximum verbosity
```

## Related Configuration

- Ocean's TERM setting: `hosts/ocean/default.nix:141`
- Keystone ET module: `../keystone/modules/os/eternal-terminal.nix`
- ET enabled by default via: `keystone.os.services.eternalTerminal.enable = true`
