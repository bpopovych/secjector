# Secjector Bug Fixes and Improvements

## Critical Bug Fix: Colon Parsing in YAML Keys

### Problem
The YAML parser in `secrets.rsc` was using a naive approach to find the key-value separator:

```routeros
:local pos [:find $line ":" 0]  # BUG: finds FIRST colon
```

This caused keys containing colons to be incorrectly parsed:
- Input: `"colon:key": "v:col"`
- Parser found colon at position 6 (inside the quoted key!)
- Resulted in: key=`"colon`, value=`key": "v:col"` ❌

### Solution
Added a new helper function `__findColonOutsideQuotes` that:
1. Tracks quote state (single and double quotes)
2. Skips over quoted sections
3. Finds the first colon **outside quotes**

```routeros
:local __findColonOutsideQuotes do={
    :local s $1; :local L [:len $s]; :local inQuote false; :local quoteChar ""
    :for i from=0 to=($L-1) do={
        :local c [:pick $s $i ($i+1)]
        :if ($inQuote) do={
            :if ($c=$quoteChar) do={ :set inQuote false; :set quoteChar "" }
        } else={
            :if ($c="\"" || $c="'") do={ :set inQuote true; :set quoteChar $c }
            :if ($c=":") do={ :return $i }
        }
    }
    :return nil
}
```

Now correctly parses:
- `"colon:key": "v:col"` → key=`colon:key`, value=`v:col` ✅
- `"space key": "spacey"` → key=`space key`, value=`spacey` ✅
- `"@leading": "atvalue"` → key=`@leading`, value=`atvalue` ✅

### Files Changed
- `secrets.rsc:65-78` - Added `__findColonOutsideQuotes` helper
- `secrets.rsc:98` - Use new helper instead of naive `[:find]`

## Additional Improvements

### 1. Security Enhancement
**File:** `.gitignore`

Added protection against accidentally committing real secrets:
```gitignore
# Security: never commit actual secrets
secrets.yaml
!examples/secrets.yaml
!tests/secrets.yaml
```

Now only example and test fixtures are tracked by git.

### 2. Comprehensive Test Suite
**File:** `tests/unit/test_parser.py` (NEW)

Added automated tests for:
- Keys with colons: `"colon:key"`
- Keys with spaces: `"space key"`
- Keys with special chars: `"@leading"`
- Values with colons: `"v:col"`
- Multiple colons in one line
- Integration test expectations validation

All tests validate that the Python simulation matches expected RouterOS behavior.

### 3. Better Error Messages
**File:** `secrets.rsc:42-44`

Before:
```routeros
:error "secrets_injector: secrets.yaml not found"
```

After:
```routeros
:error "secrets_injector: secrets.yaml not found in /file. Available files: [/file print]"
```

Also improved malformed line error:
```routeros
:error ("secrets_injector: malformed line (no colon separator): " . $line)
```

### 4. Testing Tools
**New Files:**
- `tests/integration/test_manual.sh` - Quick manual testing script
- `tests/integration/test_debug.sh` - Verbose debug output
- `tests/integration/debug_main.rsc` - Detailed test with step-by-step output
- `TESTING.md` - Comprehensive testing guide

### 5. Updated Test Suite
**File:** `Makefile`

Added parser tests to default test target:
```makefile
test:
    @bash -c 'grep -q "secrets.rsc" README.md && echo "README sanity: ok"'
    @bash -c 'test -f examples/secrets.yaml && echo "examples exist: ok"'
    @tests/unit/test_regressions.py
    @tests/unit/test_parser.py  # NEW
```

## Test Results

### Unit Tests (Local)
```bash
$ make test
README sanity: ok
examples exist: ok
secrets.rsc regression guards: ok
Running secrets.rsc parser tests...

✓ Colon in key test passed
✓ Space in key test passed
✓ Multiple colons test passed
✓ Special characters in key test passed
✓ Integration test expected values validated

✅ All parser tests passed!
```

### Integration Tests (MikroTik Hardware)
The fix enables the integration test to pass with keys containing:
- Colons: `"colon:key": "v:col"`
- Spaces: `"space key": "spacey"`
- Special chars: `"@leading": "atvalue"`

Expected output: `TEST_OK:12:19:5:6:7:T:F:OK:F`

## Breaking Changes
None - this is a bug fix that makes the parser work as documented.

## Migration Guide
No migration needed. Existing scripts will work better with this fix.

If you previously avoided using keys with colons, spaces, or special characters due to parsing issues, you can now use them safely:

```yaml
# These now work correctly!
"api:v2:endpoint": "https://api.example.com/v2"
"user email": "user@example.com"
"@mention_token": "secret123"
```

## RouterOS 7.20.x Compatibility Fixes (v0.1.3)

### Critical Compatibility Issues Resolved

The project was extensively tested on **bare metal MikroTik hAP ac² running RouterOS 7.20.2 (ARM)**. Multiple RouterOS 7.20.x scripting limitations were discovered and fixed:

#### 1. Function Naming Convention
**Problem**: RouterOS 7.20.x rejects underscores in `:local` function names
- `secret_has` → syntax error
- `secret_require` → syntax error
- `secret_cleanup` → syntax error

**Solution**: Renamed all functions to camelCase
- ✅ `$secret` (no change needed)
- ✅ `$secretHas` (was `secret_has`)
- ✅ `$secretRequire` (was `secret_require`)
- ❌ `$secretCleanup` - disabled (see below)

**Files Changed**: `secrets.rsc:167-177`

#### 2. Global vs Local Variable Scoping
**Problem**: Multiple `:local` limitations discovered:
- Cannot use `:set` on `:local` variables to update them
- Cannot assign array literals to `:local` variables (become `nothing`)
- `:local` functions cannot access `:global` variables even with `:global varName;` declaration
- Cannot assign `:global` function return values to `:local` variables (returns empty)

**Example Failures**:
```routeros
:local map {key="value"}        # → $map is nothing (not array!)
:local result [$secret "key"]   # → $result is empty string!
:local x ""; :set x "hello"     # → syntax error!
```

**Solution**: Changed to `:global` for everything
- ✅ `secretMap` is now `:global` (was intended to be local)
- ✅ All accessor functions are `:global` (were `:local`)
- ✅ Helper variables in loops use `:global`

**Files Changed**: `secrets.rsc:155-177`

#### 3. Script Import Scope Isolation
**Problem**: `/import` creates isolated scope - globals defined inside imported scripts don't persist

**Testing Results**:
```routeros
/import test.rsc          # test.rsc creates :global variables
# After import completes, those globals are NOT accessible!
```

**Solution**: Changed usage pattern from `/import` to `:parse [/file get ...]`
```routeros
# ✅ Works - runs in current scope
[:parse [/file get "secrets.rsc" contents]]
[:parse $OUT]
:put [$secret "wifi_password"]  # → "test_pw_1234"

# ❌ Doesn't work - isolated scope
/import secrets_setup.rsc
:put [$secret "wifi_password"]  # → empty/error
```

**Files Changed**:
- `secrets.rsc:12-26` (updated documentation)
- `README.md:55-82` (added compatibility section)
- `tests/integration/example_main.rsc:1-31` (updated test pattern)
- `.github/workflows/chr-smoke.yml:118-125` (CI uses `:parse`)

#### 4. Newline Escaping in Generated Code
**Problem**: Multiline YAML values contain literal `\n` characters. When generating RouterOS code, these literal newlines break syntax.

**Example**:
```routeros
:global secretMap {"cert"="-----BEGIN
CERT
END"}  # ← Syntax error! Literal newlines in code
```

**Solution**: Escape newlines as `\\n` in generated code
```routeros
:global secretMap {"cert"="-----BEGIN\\nCERT\\nEND"}  # ✅ Works
```

**Files Changed**: `secrets.rsc:59-70` (helperEsc function)

#### 5. Variable Concatenation in Loops
**Problem**: Cannot use `:set` on `:local` to build strings in loops

**Original Code** (failed):
```routeros
:local miss ""
:foreach k in=$arr do={
    :set miss ($miss . $k)  # ← Syntax error!
}
```

**Solution**: Use `:global` for accumulator variables
```routeros
:global secretRequireMiss ""
:foreach k in=$arr do={
    :set secretRequireMiss ($secretRequireMiss.$k)  # ✅ Works
}
```

**Files Changed**: `secrets.rsc:172-177`

#### 6. secretCleanup Function Disabled
**Problem**: The `secretCleanup` function attempted to disable other functions by using `:set function do={...}`. RouterOS 7.20.x cannot `:set` on `:global` function variables.

**Solution**: Disabled `secretCleanup` entirely - not possible in RouterOS 7.20.x

**Files Changed**: `secrets.rsc:180-181` (commented out)

### Usage Pattern Changes

#### Before (v0.1.2 - didn't work on 7.20.x)
```routeros
[:parse [[:parse [/file get "secrets.rsc" contents]]]]
:local pass [$secret_has "wifi_password"]
[$secret_require {"api_key"}]
```

#### After (v0.1.3 - works on 7.20.x)
```routeros
[:parse [/file get "secrets.rsc" contents]]
[:parse $OUT]
:global pass [$secretHas "wifi_password"]  # Use :global for storage
[$secretRequire {"api_key"}]
# Or use directly: /user add password=[$secret "wifi_password"]
```

### Test Results

**Hardware**: MikroTik hAP ac² (wAP-ac)
**RouterOS**: 7.20.2 (stable) ARM architecture

All functionality verified working:
- ✅ Basic secret retrieval: `wifi_password: test_pw_1234`
- ✅ Keys with colons: `colon:key: v:col`
- ✅ Keys with spaces: `space key: spacey`
- ✅ Special characters: `@leading: atvalue`
- ✅ Multiline values: 59-char certificate with `\n`
- ✅ `$secretHas` function: returns `true`/`false`
- ✅ `$secretRequire` function: validates required keys
- ✅ Error handling: correctly errors on missing keys

### Breaking Changes (v0.1.3)

1. **Function names changed** (backwards incompatible):
   - `$secret_has` → `$secretHas`
   - `$secret_require` → `$secretRequire`
   - `$secret_cleanup` → removed (not available)

2. **Usage pattern changed**:
   - Must use `:parse [/file get ...]` instead of `/import`
   - Must use `:global` for storing return values, not `:local`

3. **Injection syntax changed**:
   - Old: `[:parse [[:parse [/file get "secrets.rsc" contents]]]]`
   - New: `[:parse [/file get "secrets.rsc" contents]]` then `[:parse $OUT]`

### Migration Guide (v0.1.2 → v0.1.3)

1. Update function names:
   ```diff
   - [$secret_has "key"]
   + [$secretHas "key"]

   - [$secret_require {"key1";"key2"}]
   + [$secretRequire {"key1";"key2"}]
   ```

2. Update injection pattern:
   ```diff
   - [:parse [[:parse [/file get "secrets.rsc" contents]]]]
   + [:parse [/file get "secrets.rsc" contents]]
   + [:parse $OUT]
   ```

3. Update variable storage:
   ```diff
   - :local pass [$secret "key"]
   + :global pass [$secret "key"]
   # Or use directly in expressions:
   + /user add password=[$secret "key"]
   ```

4. Remove secretCleanup usage:
   ```diff
   - [$secret_cleanup]
   # (feature not available in RouterOS 7.20.x)
   ```

## Version
**v0.1.3** - RouterOS 7.20.x compatibility update (breaking changes)

## Credits
- Bug identified through integration testing with `tests/secrets.yaml`
- Fix validated against RouterOS 7.20.2 on bare metal MikroTik hAP ac²
- All compatibility issues discovered through hands-on testing
