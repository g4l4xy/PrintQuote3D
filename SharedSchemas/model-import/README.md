# Model inspection report v1

Native implementations expose `fileName`, `format`, `fields` and `warnings`. A field has `category`, `source`, `key`, `value` strings. Categories: Package, Geometry, Project settings, Sliced results, Metadata. Paths include indexed XML ancestry or JSON array indices so object, plate and filament scopes are retained. Values are strings for lossless display, not trusted quote inputs. Sliced results are slicer predictions, and a G-code role label does not quantify that role's usage.

Fixtures are synthetic and contain no user models. Both native test suites must assert the same printer, filament, support flag, plate usage and triangle count. Geometry bounds describe mesh resources in declared model units; component/build transforms remain explicit metadata. Unsupported opaque payloads are listed as package entries. Limits produce errors rather than silent truncation.
