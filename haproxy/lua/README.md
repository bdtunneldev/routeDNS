# HAProxy Lua Scripts Directory

Place your custom Lua scripts in this directory to extend HAProxy functionality.

## Usage

Lua scripts can be used for:
- Request/response manipulation
- Custom authentication logic
- Request routing decisions
- Performance optimization

### Example: Simple Request Logging

```lua
core.register_action("log-request", {"http-req"}, function(txn)
    core.Debug("Request: " .. txn.http:method() .. " " .. txn.http:req_line())
end)
```

For more information, see the [HAProxy Lua documentation](http://www.haproxy.org/#docs).
