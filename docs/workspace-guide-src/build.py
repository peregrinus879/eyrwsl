#!/usr/bin/env python3
"""Build/check the self-contained workspace guide using only the Python standard library.

Both hosts share the complete template and reference. Only the embedded profile
selector differs in the generated HTML. No network or installed app is needed.
"""

import argparse
import json
import re
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parent


def validate(data):
    """Reject broken reference links, selectors and unreachable profile entries."""
    profiles = set(data['profiles'])
    if profiles != {'eyrarchy', 'eyrwsl'}:
        raise ValueError('expected the EyrArcHy and EyrWSL profiles')
    ids = set()
    for item in data['items']:
        if not re.fullmatch(r'[a-z0-9-]+', item['id']) or item['id'] in ids:
            raise ValueError(f'invalid/duplicate action ID: {item["id"]}')
        ids.add(item['id'])
        if item['app'] not in data['apps']:
            raise ValueError(f'unknown app: {item["app"]}')
        if not item['hosts'] or not set(item['hosts']) <= profiles:
            raise ValueError(f'invalid host scope: {item["id"]}')
        if item['kind'] not in ('keys', 'command'):
            raise ValueError(f'invalid action kind: {item["id"]}')
        if not item['keys'] or not all(isinstance(key, str) and key for key in item['keys']):
            raise ValueError(f'missing controls: {item["id"]}')
        for field in ('title', 'category', 'mode', 'detail'):
            if not isinstance(item[field], str) or not item[field]:
                raise ValueError(f'missing {field}: {item["id"]}')
        for source in [item['source'], *item['extra']]:
            if source not in data['sources']:
                raise ValueError(f'unknown source {source}: {item["id"]}')
    for workflow in data['workflows']:
        if not all(source in data['sources'] for source in workflow['sources']):
            raise ValueError(f'unknown workflow source: {workflow["title"]}')
    for source in data['sources'].values():
        for profile in profiles:
            url = urlsplit(source['url'].replace('{repo}', profile))
            if url.scheme != 'https' or not url.netloc:
                raise ValueError(f'invalid source URL: {source["url"]}')
    recipes = data['recipes']
    if [recipe['selector'] for recipe in recipes] != ['cc', 'cx', 'oc', 'ha']:
        raise ValueError('launcher must cover all four hdw selectors')
    for recipe in recipes:
        if recipe['command'] != 'hdw ' + recipe['selector'] or recipe['resume'] != recipe['command'] + ' -c':
            raise ValueError(f'invalid launcher recipe: {recipe["selector"]}')
    for profile in profiles:
        if {item['app'] for item in data['items'] if profile in item['hosts']} != set(data['apps']):
            raise ValueError(f'missing application coverage: {profile}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', required=True, choices=('eyrarchy', 'eyrwsl'))
    parser.add_argument('--check', action='store_true', help='compare without writing')
    args = parser.parse_args()
    data = json.loads((ROOT / 'reference.json').read_text(encoding='utf-8'))
    validate(data)
    template = (ROOT / 'template.html').read_text(encoding='utf-8')
    for token in ('__REFERENCE__', '__PROFILE__'):
        if template.count(token) != 1:
            raise ValueError(f'expected exactly one {token} placeholder')
    payload = json.dumps(data, ensure_ascii=False, indent=2).replace('<', '\\u003c')
    output = template.replace('__REFERENCE__', payload).replace('__PROFILE__', args.profile)
    if '\u2014' in output:
        raise ValueError('use periods, commas or semicolons instead of em dashes')
    target = ROOT.parent / 'workspace-guide.html'
    if args.check:
        if not target.exists() or target.read_text(encoding='utf-8') != output:
            raise SystemExit('FAIL: docs/workspace-guide.html is stale; run make workspace-guide')
        print(f'ok:   {args.profile} offline guide is current; {len(data["items"])} reference actions')
    else:
        target.write_text(output, encoding='utf-8')
        print(f'Built {target} ({args.profile})')


if __name__ == '__main__':
    main()
