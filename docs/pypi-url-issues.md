# PyPI URL Prediction Issues

## Problem Description

Some Python packages, particularly newer ones, may fail to download with a 404 error during poetry2nix builds. This typically manifests as:

```
Trying to fetch with predicted URL: https://files.pythonhosted.org/packages/wheel/a/arpeggio/Arpeggio-2.0.0-py2.py3-none-any.whl
curl: (22) The requested URL returned error: 404
```

## Root Cause

Modern PyPI has moved from predictable URL patterns to hash-based URLs for many packages. Poetry2nix's URL prediction mechanism uses the legacy pattern:

- **Legacy pattern**: `/packages/{kind}/{firstChar}/{pname}/{file}`
- **Modern pattern**: `/packages/{hash_prefix}/{hash_suffix}/{file}`

For example:
- **Predicted**: `https://files.pythonhosted.org/packages/wheel/a/arpeggio/Arpeggio-2.0.0-py2.py3-none-any.whl`
- **Actual**: `https://files.pythonhosted.org/packages/7a/b7/62898ef180bbfea60d28678040ddbb50e36c180d5c56e9cc62b7944c4623/Arpeggio-2.0.0-py2.py3-none-any.whl`

## Solutions

### Solution 1: Automatic Fallback (Default Behavior)

Poetry2nix includes an automatic fallback mechanism that should handle this transparently:

1. Try the predicted URL
2. If it fails with 404, query the PyPI JSON API to get the actual URL
3. Download using the API-provided URL

If you're still getting 404 errors, this suggests the fallback isn't working properly in your specific case.

### Solution 2: Force API-First Mode

For packages known to have URL prediction issues, you can force the use of API-first mode:

```nix
# In your poetry2nix configuration
packageOverrides = {
  arpeggio = prev.arpeggio.overridePythonAttrs (old: {
    src = fetchFromPypi {
      pname = old.pname;
      inherit (old) version;
      file = old.src.name;
      hash = old.src.outputHash;
      useApiFirst = true;  # Force API-first mode
    };
  });
};
```

### Solution 3: Use the Alternative API-First Fetcher

Poetry2nix provides a dedicated API-first fetcher:

```nix
# In your poetry2nix configuration
packageOverrides = {
  arpeggio = prev.arpeggio.overridePythonAttrs (old: {
    src = fetchFromPypiApiFirst {
      pname = old.pname;
      inherit (old) version;
      file = old.src.name;
      hash = old.src.outputHash;
    };
  });
};
```

### Solution 4: Enable Global API-First Mode

If you're experiencing this issue with many packages, you can modify the default fetcher behavior:

```nix
# In fetchers/default.nix, change the default:
useApiFirst ? true  # Changed from false to true
```

**Note**: This makes all fetches slightly slower due to the additional API call, but is more reliable.

## Known Affected Packages

- **Arpeggio**: All versions use hash-based URLs
- Many packages uploaded after 2020 when PyPI modernized its infrastructure

## Debugging Tips

1. **Check the actual URL**: Query the PyPI API to see the real download URL:
   ```bash
   curl -s "https://pypi.org/pypi/PACKAGE_NAME/json" | jq '.releases."VERSION"[] | {filename: .filename, url: .url}'
   ```

2. **Test URL prediction**: Compare the predicted URL with the actual URL to confirm the issue

3. **Verify API fallback**: Check if the fallback mechanism is being triggered by looking for "querying pypi.org API" in the build logs

## Future Improvements

This issue could be resolved by:

1. **Improved URL prediction**: Update the prediction logic to handle modern PyPI patterns
2. **Default API-first**: Make API-first the default behavior for better reliability
3. **Smart fallback**: Use package metadata to determine which URL pattern to use

For now, the automatic fallback mechanism should handle most cases transparently. 