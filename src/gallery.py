#!/usr/bin/env python3
"""
Photo gallery generator for redshell.

Scans a directory tree for photos, optionally deduplicates them, generates
thumbnails and mid-size images, and creates a JSON index for the gallery viewer.

Usage:
    gallery.py scan [OPTIONS] DIRECTORY
"""

import os
import sys
import json
import hashlib
import shutil
import multiprocessing
from pathlib import Path
from datetime import datetime
from collections import defaultdict
from functools import partial

# Try to import PIL for image processing
try:
    from PIL import Image
    HAS_PIL = True
except ImportError:
    HAS_PIL = False

# Try to import tqdm for progress bars
try:
    from tqdm import tqdm
    HAS_TQDM = True
except ImportError:
    HAS_TQDM = False

# Constants
THUMB_SIZE = 300
MID_SIZE = 1600
QUALITY = 85
GALLERY_DIR_NAME = ".gallery"

# Patterns to exclude from scanning
EXCLUDE_PATTERNS = [
    '$RECYCLE.BIN',
    'System Volume Information',
    'Program Files',
    'Windows',
    'AppData',
    '.Trash',
    '.gallery',
    '__MACOSX',
    '.DS_Store',
]

# Photo extensions to include
PHOTO_EXTENSIONS = {'.jpg', '.jpeg', '.png', '.heic', '.heif'}


def progress_wrapper(iterable, desc=None, total=None):
    """Wrap an iterable with tqdm if available, otherwise return as-is."""
    if HAS_TQDM:
        return tqdm(iterable, desc=desc, total=total, unit='file')
    else:
        return iterable


def compute_hash(filepath: Path) -> tuple[Path, str | None]:
    """Compute SHA256 hash of file. Returns (filepath, hash) for pool.map."""
    sha256 = hashlib.sha256()
    try:
        with open(filepath, 'rb') as f:
            for chunk in iter(lambda: f.read(65536), b''):
                sha256.update(chunk)
        return filepath, sha256.hexdigest()
    except Exception as e:
        print(f"Error hashing {filepath}: {e}", file=sys.stderr)
        return filepath, None


def get_exif_date(filepath: Path) -> datetime | None:
    """Try to get date from EXIF data."""
    if not HAS_PIL:
        return None

    try:
        with Image.open(filepath) as img:
            exif_data = img._getexif()
            if exif_data:
                # Look for DateTimeOriginal (36867), DateTimeDigitized (36868), or DateTime (306)
                for tag_id in [36867, 36868, 306]:
                    if tag_id in exif_data:
                        date_str = exif_data[tag_id]
                        if date_str:
                            try:
                                return datetime.strptime(date_str, "%Y:%m:%d %H:%M:%S")
                            except ValueError:
                                try:
                                    return datetime.strptime(date_str.split()[0], "%Y:%m:%d")
                                except:
                                    pass
    except Exception:
        pass
    return None


def get_file_date(filepath: Path) -> tuple[datetime, str]:
    """Get date for file - prefer EXIF, fall back to mtime."""
    exif_date = get_exif_date(filepath)
    if exif_date:
        return exif_date, 'exif'

    try:
        mtime = os.path.getmtime(filepath)
        return datetime.fromtimestamp(mtime), 'mtime'
    except:
        return datetime.now(), 'now'


def should_exclude(filepath: Path) -> bool:
    """Check if a path should be excluded from scanning."""
    path_str = str(filepath)
    for pattern in EXCLUDE_PATTERNS:
        if pattern in path_str:
            return True
    return False


def find_photos(root_path: Path) -> list[Path]:
    """Find all photo files in directory tree."""
    photos = []
    for ext in PHOTO_EXTENSIONS:
        # Case-insensitive search using glob
        photos.extend(root_path.rglob(f"*{ext}"))
        photos.extend(root_path.rglob(f"*{ext.upper()}"))

    # Filter out excluded paths and dedupe (since we search both cases)
    seen = set()
    filtered = []
    for p in photos:
        if p in seen:
            continue
        seen.add(p)
        if not should_exclude(p):
            filtered.append(p)

    return sorted(filtered)


def resize_image_task(task: tuple) -> tuple[str, bool]:
    """
    Worker function for parallel thumbnail generation.

    Args:
        task: (src_path, dest_path, max_size) tuple

    Returns:
        (dest_path, success) tuple
    """
    src_path, dest_path, max_size = task
    src_path = Path(src_path)
    dest_path = Path(dest_path)

    if not HAS_PIL:
        return str(dest_path), False

    try:
        with Image.open(src_path) as img:
            # Handle HEIC/HEIF if pillow-heif is installed
            if img.format == 'HEIF':
                try:
                    import pillow_heif
                except ImportError:
                    return str(dest_path), False

            # Convert to RGB if necessary
            if img.mode in ('RGBA', 'P', 'LA'):
                img = img.convert('RGB')
            elif img.mode != 'RGB':
                img = img.convert('RGB')

            # Calculate new size preserving aspect ratio
            ratio = min(max_size / img.width, max_size / img.height)
            if ratio < 1:
                new_size = (int(img.width * ratio), int(img.height * ratio))
                img = img.resize(new_size, Image.LANCZOS)

            # Save with optimization
            dest_path.parent.mkdir(parents=True, exist_ok=True)
            img.save(dest_path, 'JPEG', quality=QUALITY, optimize=True)
            return str(dest_path), True
    except Exception as e:
        return str(dest_path), False


def generate_date_filename(filepath: Path, date_counts: dict) -> str:
    """Generate a date-based filename for a photo."""
    file_date, _ = get_file_date(filepath)
    date_str = file_date.strftime("%Y-%m-%d_%H%M%S")
    date_counts[date_str] += 1

    if date_counts[date_str] == 1:
        return f"{date_str}.jpg"
    else:
        return f"{date_str}_{date_counts[date_str]}.jpg"


def get_cpu_count() -> int:
    """Get number of CPUs to use for parallel processing."""
    try:
        # Use all but one CPU, minimum 1
        return max(1, multiprocessing.cpu_count() - 1)
    except:
        return 1


def scan(directory: str, dedupe: str = "", copy_to: str = "",
         gallery_dir: str = "", force: str = "", title: str = ""):
    """
    Scan directory for photos and generate gallery data.

    Args:
        directory: Directory to scan for photos
        dedupe: If "True", deduplicate photos by hash
        copy_to: If set, copy photos to this directory with date-based names
        gallery_dir: Where to put .gallery data (defaults to directory or copy_to)
        force: If "True", regenerate thumbnails even if they exist
        title: Gallery title (defaults to directory name)
    """
    # Convert string bools from bash
    dedupe_flag = dedupe.lower() == "true" if dedupe else False
    force_flag = force.lower() == "true" if force else False

    if not HAS_PIL:
        print("Warning: PIL not available, thumbnails will not be generated", file=sys.stderr)

    if not HAS_TQDM:
        print("Note: Install 'tqdm' for progress bars", file=sys.stderr)

    root_path = Path(directory).resolve()
    if not root_path.exists():
        print(f"Error: Directory does not exist: {root_path}", file=sys.stderr)
        return 1

    num_workers = get_cpu_count()
    print(f"Using {num_workers} worker processes")

    print(f"Scanning for photos in {root_path}...")
    photos = find_photos(root_path)
    print(f"Found {len(photos)} photo files")

    if not photos:
        print("No photos found.")
        return 0

    # Determine where to put gallery data
    if copy_to:
        copy_path = Path(copy_to).resolve()
        copy_path.mkdir(parents=True, exist_ok=True)
        gallery_base = Path(gallery_dir).resolve() if gallery_dir else copy_path
    else:
        copy_path = None
        gallery_base = Path(gallery_dir).resolve() if gallery_dir else root_path

    gallery_path = gallery_base / GALLERY_DIR_NAME
    gallery_path.mkdir(parents=True, exist_ok=True)
    thumb_dir = gallery_path / "thumbs"
    mid_dir = gallery_path / "mid"
    thumb_dir.mkdir(exist_ok=True)
    mid_dir.mkdir(exist_ok=True)

    # Load existing gallery data to avoid re-scanning known files
    json_path = gallery_path / "photos.json"
    existing_photos = {}  # original_path -> photo_data
    existing_title = None
    if json_path.exists() and not force_flag:
        try:
            with open(json_path) as f:
                existing_data = json.load(f)
            if isinstance(existing_data, dict):
                existing_title = existing_data.get('title')
                for photo in existing_data.get('photos', []):
                    existing_photos[photo['original_path']] = photo
            print(f"Loaded {len(existing_photos)} existing entries from gallery index")
        except Exception as e:
            print(f"Warning: Could not load existing gallery data: {e}", file=sys.stderr)

    # Deduplicate if requested (parallel hashing)
    if dedupe_flag:
        print("\nComputing hashes for deduplication...")
        with multiprocessing.Pool(num_workers) as pool:
            results = list(progress_wrapper(
                pool.imap(compute_hash, photos),
                desc="Hashing",
                total=len(photos)
            ))

        hash_to_files = defaultdict(list)
        for filepath, file_hash in results:
            if file_hash:
                hash_to_files[file_hash].append(filepath)

        unique_count = len(hash_to_files)
        dupe_count = len(photos) - unique_count
        print(f"Found {unique_count} unique photos ({dupe_count} duplicates)")
        photos = [files[0] for files in hash_to_files.values()]

    # Process photos - collect metadata and prepare resize tasks
    print("\nCollecting photo metadata...")
    photo_data = []
    date_counts = defaultdict(int)
    resize_tasks = []  # (src, dest, size) tuples
    new_count = 0
    skipped_count = 0

    for filepath in progress_wrapper(photos, desc="Metadata"):
        # Compute the original_path to check if already indexed
        if copy_path:
            # When copying, we need to generate the filename first to know the path
            gallery_filename = generate_date_filename(filepath, date_counts)
            dest_path = copy_path / gallery_filename
            original_path = str(dest_path.relative_to(gallery_base))
            source_for_resize = dest_path
        else:
            original_path = str(filepath.relative_to(gallery_base))
            source_for_resize = filepath
            gallery_filename = None  # Will get from existing or generate

        # Check if this file is already indexed
        if original_path in existing_photos and not force_flag:
            # Use existing metadata
            photo_entry = existing_photos[original_path]
            photo_data.append(photo_entry)
            gallery_filename = photo_entry['filename']
            skipped_count += 1
        else:
            # New file - collect metadata
            if gallery_filename is None:
                gallery_filename = generate_date_filename(filepath, date_counts)

            if copy_path:
                try:
                    shutil.copy2(filepath, dest_path)
                except Exception as e:
                    print(f"Error copying {filepath}: {e}", file=sys.stderr)
                    continue

            file_date, date_source = get_file_date(filepath)
            photo_data.append({
                'filename': gallery_filename,
                'original_path': original_path,
                'date': file_date.isoformat(),
                'date_source': date_source,
            })
            new_count += 1

        # Always check for missing thumbnails (even for existing entries)
        thumb_path = thumb_dir / gallery_filename
        mid_path = mid_dir / gallery_filename

        if force_flag or not thumb_path.exists():
            resize_tasks.append((str(source_for_resize), str(thumb_path), THUMB_SIZE))

        if force_flag or not mid_path.exists():
            resize_tasks.append((str(source_for_resize), str(mid_path), MID_SIZE))

    if skipped_count > 0:
        print(f"  Skipped {skipped_count} already-indexed files, found {new_count} new files")

    # Generate thumbnails in parallel
    if resize_tasks:
        print(f"\nGenerating {len(resize_tasks)} thumbnail/mid-size images...")
        with multiprocessing.Pool(num_workers) as pool:
            results = list(progress_wrapper(
                pool.imap(resize_image_task, resize_tasks),
                desc="Resizing",
                total=len(resize_tasks)
            ))

        success_count = sum(1 for _, success in results if success)
        fail_count = len(results) - success_count
        if fail_count > 0:
            print(f"  {fail_count} images failed to process", file=sys.stderr)
    else:
        print("\nAll thumbnails already exist, skipping generation.")

    # Sort by date
    photo_data.sort(key=lambda x: x['date'])

    # Default title to: provided title > existing title > directory name
    gallery_title = title if title else (existing_title if existing_title else root_path.name)

    # Write JSON index
    json_path = gallery_path / "photos.json"
    gallery_data = {
        'title': gallery_title,
        'photos': photo_data,
    }
    with open(json_path, 'w') as f:
        json.dump(gallery_data, f, indent=2)

    print(f"\nGallery data written to: {gallery_path}")
    print(f"  Photos indexed: {len(photo_data)}")
    print(f"  JSON index: {json_path}")
    print(f"  Thumbnails: {thumb_dir}")
    print(f"  Mid-size: {mid_dir}")

    # Size stats
    if thumb_dir.exists() and mid_dir.exists():
        thumb_size = sum(f.stat().st_size for f in thumb_dir.glob("*.jpg"))
        mid_size = sum(f.stat().st_size for f in mid_dir.glob("*.jpg"))
        print(f"\nGenerated image sizes:")
        print(f"  Thumbnails: {thumb_size / 1e6:.1f} MB")
        print(f"  Mid-size: {mid_size / 1e6:.1f} MB")

    return 0
