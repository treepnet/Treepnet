#!/usr/bin/env python3
"""Grid thumbnails for posts published before the app made them.

Since the 1.0.8 app, each post photo is uploaded with a small copy,
posts/<postId>/thumb_<i>, whose URL is stored as thumb_url in posts.media; the
grids (profile, saved posts, map, timeline) show that instead of the full
photo. This makes the same copy for every older photo.

For each photo in posts.media without a thumb_url it downloads the photo from
the bucket, scales it so its shorter side is 480px (JPEG quality 75, as
ImageCompress.compressThumbnail does in the app), uploads it next to the photo
and then sets thumb_url, all posts in one transaction. A post changed in the
meantime is left alone (the update matches the old media text). Safe to run
again: photos that have a thumbnail are skipped.

Runs on a Mac: macOS `sips`, the OCI CLI signed in (~/.oci/config) and SSH to
the server.
  python3 backfill_post_thumbs.py           # lists what it would do
  python3 backfill_post_thumbs.py --apply
"""

import json
import os
import secrets
import subprocess
import sys
import tempfile
import urllib.request
from concurrent.futures import ThreadPoolExecutor

SSH = ['ssh', '-i', os.path.expanduser('~/.ssh/arm_key_new'), 'ubuntu@130.61.138.104']
PSQL = 'docker exec -i treepnet-postgres psql -U treepnet -d treepnet -v ON_ERROR_STOP=1'
OCI = os.path.expanduser('~/Library/Python/3.9/bin/oci')
NAMESPACE = 'fryarohmp0gm'
BUCKET = 'treepnet-media'
ORIGIN = f'https://objectstorage.eu-frankfurt-1.oraclecloud.com/n/{NAMESPACE}/b/{BUCKET}/o/'
CDN = 'https://media.treepnet.com/'
IMAGE = '__image_media__'
SHORT_SIDE = 480
QUALITY = 75


def psql(sql, *flags):
    out = subprocess.run(SSH + [f'{PSQL} {" ".join(flags)}'], input=sql, text=True,
                         capture_output=True, check=True)
    return out.stdout


def object_of(url):
    for base in (CDN, ORIGIN):
        if url.startswith(base):
            return url[len(base):].split('?')[0]
    return None


def make_thumb(obj, workdir):
    """Downloads `obj` and writes its thumbnail; returns the file path."""
    name = obj.replace('/', '_')
    src = os.path.join(workdir, name)
    dst = os.path.join(workdir, name + '.thumb.jpg')
    with urllib.request.urlopen(ORIGIN + obj, timeout=60) as r, open(src, 'wb') as f:
        f.write(r.read())
    info = subprocess.run(['sips', '-g', 'pixelWidth', '-g', 'pixelHeight', src],
                          capture_output=True, text=True, check=True).stdout
    w = int(info.split('pixelWidth:')[1].split()[0])
    h = int(info.split('pixelHeight:')[1].split()[0])
    cmd = ['sips', '-s', 'format', 'jpeg', '-s', 'formatOptions', str(QUALITY)]
    if min(w, h) > SHORT_SIDE:
        width = SHORT_SIDE if w <= h else round(SHORT_SIDE * w / h)
        cmd += ['--resampleWidth', str(width)]
    subprocess.run(cmd + [src, '--out', dst], capture_output=True, check=True)
    return dst, os.path.getsize(src), os.path.getsize(dst)


def upload(path, obj):
    subprocess.run([OCI, 'os', 'object', 'put', '-ns', NAMESPACE, '-bn', BUCKET,
                    '--name', obj, '--file', path, '--content-type', 'image/jpeg',
                    '--cache-control', 'max-age=9000000', '--force'],
                   capture_output=True, check=True)


def main():
    apply = '--apply' in sys.argv[1:]
    rows = json.loads(psql(
        "select coalesce(json_agg(json_build_object('id', id, 'media', media)), '[]') "
        "from posts where media like '%https://%';", '-At') or '[]')

    todo = []  # (post id, media index, photo object, thumbnail object)
    for row in rows:
        try:
            media = json.loads(row['media'])
        except (TypeError, ValueError):
            continue
        for i, m in enumerate(media):
            if not isinstance(m, dict) or m.get('type', IMAGE) != IMAGE or m.get('thumb_url'):
                continue
            obj = object_of(m.get('url') or '')
            if obj and obj.startswith(f'posts/{row["id"]}/'):
                todo.append((row['id'], i, obj, f'posts/{row["id"]}/thumb_{i}'))

    print(f'{len(rows)} posts, {len(todo)} photos without a thumbnail')
    if not apply:
        for t in todo[:10]:
            print('  would make', t[3], 'from', t[2])
        print('Dry run. Add --apply to make and upload them.')
        return

    with tempfile.TemporaryDirectory() as workdir:
        def one(t):
            post_id, i, obj, thumb_obj = t
            try:
                path, before, after = make_thumb(obj, workdir)
                upload(path, thumb_obj)
                return t, before, after, None
            except Exception as e:  # noqa: BLE001 - reported per photo
                return t, 0, 0, e

        with ThreadPoolExecutor(max_workers=6) as pool:
            results = list(pool.map(one, todo))

    done = {}
    total_before = total_after = 0
    for (post_id, i, _, thumb_obj), before, after, error in results:
        if error:
            print('  failed', thumb_obj, error)
            continue
        done.setdefault(post_id, {})[i] = CDN + thumb_obj
        total_before += before
        total_after += after
    print(f'uploaded {sum(len(v) for v in done.values())} thumbnails: '
          f'{total_before // 1024} KB of photos -> {total_after // 1024} KB')

    tag = '$t' + secrets.token_hex(4) + '$'
    statements = []
    for row in rows:
        thumbs = done.get(row['id'])
        if not thumbs:
            continue
        media = json.loads(row['media'])
        for i, url in thumbs.items():
            media[i]['thumb_url'] = url
        new = json.dumps(media, ensure_ascii=False, separators=(',', ':'))
        statements.append(
            f"update public.posts set media = {tag}{new}{tag} "
            f"where id = '{row['id']}' and media = {tag}{row['media']}{tag};")
    if not statements:
        return
    out = psql('begin;\n' + '\n'.join(statements) + '\ncommit;\n')
    updated = sum(int(line.split()[1]) for line in out.splitlines() if line.startswith('UPDATE'))
    print(f'set thumb_url on {updated} of {len(statements)} posts')


if __name__ == '__main__':
    main()
