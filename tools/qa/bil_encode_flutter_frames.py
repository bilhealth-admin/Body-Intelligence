"""Encode actual host Flutter painted frames; this is not a device recording."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('directory', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    frames = sorted(args.directory.glob('[0-9][0-9][0-9][0-9][0-9].png'))
    if not frames or args.output.exists():
        parser.error('a fresh output and nonempty numbered frame session are required')
    dimensions = set()
    for index, path in enumerate(frames):
        if path.name != f'{index:05d}.png':
            parser.error('the frame sequence is not contiguous')
        data = path.read_bytes()
        if data[:8] != b'\x89PNG\r\n\x1a\n':
            parser.error('frame is not a PNG')
        dimensions.add((int.from_bytes(data[16:20], 'big'), int.from_bytes(data[20:24], 'big')))
    if len(dimensions) != 1:
        parser.error('one recording cannot mix screen sizes')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-n',
                    '-framerate', '10', '-i', str(args.directory / '%05d.png'),
                    '-c:v', 'libx264', '-crf', '18', '-pix_fmt', 'yuv420p',
                    '-movflags', '+faststart', str(args.output)], check=True)
    receipt = {'method': 'painted Flutter WidgetTester frames at 10 test-clock fps',
               'not_device_latency': True, 'frames': len(frames),
               'dimensions': list(next(iter(dimensions))),
               'sha256': hashlib.sha256(args.output.read_bytes()).hexdigest(),
               'steps': [json.loads(line) for line in (args.directory / 'frames.jsonl').read_text().splitlines()]}
    args.output.with_suffix('.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    print(json.dumps({key: value for key, value in receipt.items() if key != 'steps'}))


if __name__ == '__main__':
    main()
