# Manufacturing importer performance evidence

Measured on the local Apple Silicon development Mac with a Swift release build of `ThreeMFProbe` on 2026-09-15. The probe disables the normalized-result cache and includes snapshot/hash, ZIP inspection, metadata and geometry processing. Peak resident memory is measured by `/usr/bin/time -l` for the entire process.

| Case | Archive size | Triangles | Elapsed | Peak RSS |
|---|---:|---:|---:|---:|
| small | 0.00 MiB | 4 | 0.007 s | 8.69 MiB |
| medium | 32.00 MiB | 4 | 0.026 s | 40.94 MiB |
| large | 192.00 MiB | 4 | 0.136 s | 201.67 MiB |
| geometry | 15.26 MiB | 500,000 | 3.318 s | 64.70 MiB |

The medium/large cases intentionally contain streamed binary assets with minimal geometry; they demonstrate container-budget behavior, not the cost of 192 MiB of complex mesh XML. The separate geometry case processes 500,000 triangles. These are deterministic geometry structures with synthetic, randomly filled asset payloads. ZIP memory mapping and operating-system file caching can affect RSS and timings.

The benchmark enforces a 120-second process timeout, requires usable nonfatal results, and asserts peak RSS below 512 MiB for these cases. Importer defaults independently enforce archive/entry/geometry/metadata/time budgets. These measurements are not guarantees for every file or for iPhone/iPad memory limits.

Reproduce from the repository root:

```sh
swift build -c release --product ThreeMFProbe
python3 tools/three-mf/benchmark.py
```

Generated large archives live in a temporary directory and are deleted afterward. Machine-readable results go to ignored `.workflow/three-mf-performance.json`. No customer geometry is included.
