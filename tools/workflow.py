#!/usr/bin/env python3
"""One repository workflow for Apple, Android and Windows. Python standard library only."""
import argparse
import concurrent.futures
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]

def run(*args, capture=False, env=None):
    return subprocess.run(args, cwd=ROOT, check=True, text=True,
                          stdout=subprocess.PIPE if capture else None, env=env)

def git(*args):
    return run('git', *args, capture=True).stdout.strip()

def clean():
    if git('status', '--porcelain'):
        raise ValueError('Save/commit your local edits first. No files were stashed or discarded.')

def branch():
    name = git('branch', '--show-current')
    if not name:
        raise ValueError('Switch to a branch before syncing.')
    return name

def sync_pull():
    clean()
    branch()
    git('rev-parse', '--abbrev-ref', '@{upstream}')
    run('git', 'pull', '--ff-only')

def publish(message, paths, all_files):
    name = branch()
    if not paths and not all_files:
        raise ValueError('Select paths after --, or use --all to include all non-ignored edits.')
    # Never commit a pre-existing staged selection accidentally.
    if git('diff', '--cached', '--name-only'):
        raise ValueError('There are already staged files. Commit or unstage them before using pq push.')
    if all_files:
        run('git', 'add', '-A')
    else:
        run('git', 'add', '--', *paths)
    if git('diff', '--cached', '--name-only'):
        run('git', 'diff', '--cached', '--check')
        run('git', 'commit', '-m', message)
    # No force push, merge, stash or reset. A rejection leaves the local commit intact.
    run('git', 'push', '-u', 'origin', name)

def check(platform):
    env = os.environ.copy()
    if not env.get('JAVA_HOME'):
        jdk = Path('/Applications/Android Studio.app/Contents/jbr/Contents/Home')
        if jdk.exists():
            env['JAVA_HOME'] = str(jdk)
    if not env.get('ANDROID_HOME'):
        sdk = Path.home() / 'Library/Android/sdk'
        if sdk.exists():
            env['ANDROID_HOME'] = str(sdk)
    windows_env = os.environ.get('WINDOWS_JAVA_HOME')
    commands = {
        'apple': [['swift', 'test'], ['xcodebuild', '-project', 'PrintQuote3D.xcodeproj',
                   '-scheme', 'PrintQuote3D', '-destination', 'generic/platform=macOS',
                   '-derivedDataPath', '.workflow/apple', 'CODE_SIGNING_ALLOWED=NO', 'build'],
                  ['xcodebuild', '-project', 'PrintQuote3D.xcodeproj', '-scheme', 'PrintQuote3D',
                   '-destination', 'generic/platform=iOS Simulator', '-derivedDataPath', '.workflow/apple',
                   'CODE_SIGNING_ALLOWED=NO', 'build']],
        'android': [['./android/gradlew', '-p', 'android', ':app:assembleDebug',
                     ':app:testDebugUnitTest', ':app:lintDebug']],
    }
    commands['windows'] = [[('windows/gradlew.bat' if os.name == 'nt' else './windows/gradlew'), '-p', 'windows', ':sharedLogic:test', ':desktopApp:build']]
    folder = ROOT / '.workflow'
    folder.mkdir(exist_ok=True)
    def worker(name):
        log = folder / (name + '.log')
        task_env = env.copy()
        if name == 'windows' and windows_env:
            task_env['JAVA_HOME'] = windows_env
        with log.open('w') as output:
            for command in commands[name]:
                output.write('$ ' + ' '.join(command) + '\n'); output.flush()
                result = subprocess.run(command, cwd=ROOT, env=task_env, stdout=output, stderr=subprocess.STDOUT)
                if result.returncode:
                    return name, False, log
        return name, True, log
    selected = ['apple', 'android'] if platform == 'both' else list(commands) if platform == 'all' else [platform]
    failed = False
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        for name, ok, log in pool.map(worker, selected):
            print(f'{name}: {"PASS" if ok else "FAIL"} — {log}', flush=True)
            failed |= not ok
    return 1 if failed else 0

def feature(slug, title):
    if not re.fullmatch(r'[a-z0-9]+(?:-[a-z0-9]+)*', slug):
        raise ValueError('Use a lowercase feature slug such as quote-pdf-export.')
    clean()
    target = ROOT / 'docs/features' / (slug + '.md')
    if target.exists():
        raise ValueError('That feature specification already exists.')
    run('git', 'switch', '-c', 'feature/' + slug)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(f'''# {title}

## Shared outcome

Describe the user action and expected result on Apple, Android and Windows.

## Shared contract

- Data/schema changes in `SharedSchemas/`:
- Calculation examples and expected values (include boundary/error cases):
- Existing saved-data compatibility:

## Implementation and acceptance

- [ ] Shared behavior and fixtures defined
- [ ] Apple: Swift domain/data and SwiftUI implementation
- [ ] Android: Kotlin domain/data and Compose implementation
- [ ] Windows: desktop UI and shared Kotlin logic
- [ ] Windows shared fixture tests and installed MSI interaction checks
- [ ] Apple tests exercise the shared expected behavior
- [ ] Android tests exercise the same expected behavior
- [ ] Phone, tablet and Mac interaction/layout checks recorded
- [ ] `./pq check` passes
- [ ] Documentation updated

## Verification evidence

Record test commands/results and interaction coverage. State unverified devices.
If a platform intentionally differs, document the reason and user-visible behavior.

## Implementation pointers

Apple: `Sources/QuoteDomain`, `Sources/QuoteData`, `Sources/PrintQuoteApp`
Android: `android/app/src/main/java/local/printquote/android`
Shared fixtures: `SharedSchemas/`; Apple tests: `Tests/QuoteTests`
Android tests: `android/app/src/test`, `android/app/src/androidTest`
Windows: `windows/sharedLogic`, `windows/desktopApp`; shared Android logic is compiled directly
''')
    print(f'Created {target}\nImplement both platforms on this branch, then run ./pq check.')

def main():
    p = argparse.ArgumentParser(description=__doc__)
    s = p.add_subparsers(dest='command', required=True)
    s.add_parser('status', help='Show branch, remote and edits for both apps')
    s.add_parser('pull', help='Fast-forward the current branch; requires a clean workspace')
    push = s.add_parser('push', help='Commit selected edits and push the current branch')
    push.add_argument('-m', '--message', required=True)
    push.add_argument('--all', action='store_true', dest='all_files')
    push.add_argument('paths', nargs='*')
    checks = s.add_parser('check', help='Build and test Apple and Android concurrently')
    checks.add_argument('--platform', choices=['both', 'all', 'apple', 'android', 'windows'], default='both')
    f = s.add_parser('feature', help='Create one feature branch and a two-platform specification')
    f.add_argument('slug'); f.add_argument('title')
    args = p.parse_args()
    try:
        if args.command == 'status':
            run('git', 'status', '--short', '--branch'); run('git', 'remote', '-v')
        elif args.command == 'pull': sync_pull()
        elif args.command == 'push': publish(args.message, args.paths, args.all_files)
        elif args.command == 'check': return check(args.platform)
        elif args.command == 'feature': feature(args.slug, args.title)
        return 0
    except (ValueError, OSError, subprocess.CalledProcessError) as e:
        print(f'Workflow stopped: {e}', file=sys.stderr)
        return 1

if __name__ == '__main__':
    sys.exit(main())
