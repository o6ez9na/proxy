#!/usr/bin/env python3
"""
Geosite.dat builder for Xray/V2ray

Usage:
  python geosite_builder.py -f youtube.txt,discord.txt -o geosite.dat
  python geosite_builder.py -f youtube.txt discord.txt -o geosite.dat

Each file becomes a tag named after the file (without extension).
For example: youtube.txt → geosite:youtube

File format: one domain per line, empty lines and lines starting with # are ignored.
"""

import sys
import os
import argparse


def encode_varint(value):
    bits = value & 0x7F
    value >>= 7
    result = b""
    while value:
        result += bytes([0x80 | bits])
        bits = value & 0x7F
        value >>= 7
    result += bytes([bits])
    return result


def encode_string(value):
    encoded = value.encode("utf-8")
    return encode_varint(len(encoded)) + encoded


def encode_field(field_number, wire_type, data):
    tag = (field_number << 3) | wire_type
    return encode_varint(tag) + data


def encode_domain(domain_value, domain_type=2):
    """
    Types: 0=Plain, 1=Regex, 2=Domain (subdomain match), 3=Full
    """
    data = b""
    data += encode_field(1, 0, encode_varint(domain_type))
    data += encode_field(2, 2, encode_string(domain_value))
    return data


def encode_geosite(country_code, domains):
    data = b""
    data += encode_field(1, 2, encode_string(country_code.upper()))
    for domain in domains:
        domain_bytes = encode_domain(domain)
        data += encode_field(2, 2, encode_varint(len(domain_bytes)) + domain_bytes)
    return data


def encode_geositelist(entries):
    data = b""
    for country_code, domains in entries.items():
        geosite_bytes = encode_geosite(country_code, domains)
        data += encode_field(1, 2, encode_varint(len(geosite_bytes)) + geosite_bytes)
    return data


def read_domains_from_file(filepath):
    """Read domains from a text file, one per line. Skip empty lines and comments."""
    domains = []
    with open(filepath, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                domains.append(line)
    return domains


def tag_from_filename(filepath):
    """Extract tag name from filename: /path/to/youtube.txt -> YOUTUBE"""
    basename = os.path.basename(filepath)
    name, _ = os.path.splitext(basename)
    return name.upper()


def build_dat(entries, output_file):
    data = encode_geositelist(entries)
    with open(output_file, "wb") as f:
        f.write(data)
    print(f"Written {len(data)} bytes -> {output_file}")
    print()
    print("Tags included:")
    for tag, domains in entries.items():
        print(f"  geosite:{tag.lower()} ({len(domains)} domains)")
    print()
    print("Use in Xray/Remnawave config:")
    tags = [f"geosite:{t.lower()}" for t in entries.keys()]
    print(f'  "domain": {tags}')


def parse_files(raw_args):
    """Accept files separated by commas or spaces."""
    files = []
    for arg in raw_args:
        parts = arg.split(",")
        for p in parts:
            p = p.strip()
            if p:
                files.append(p)
    return files


def main():
    parser = argparse.ArgumentParser(description="Build geosite.dat for Xray/V2ray")
    parser.add_argument(
        "-f", "--files",
        nargs="+",
        required=True,
        metavar="FILE",
        help="Input files with domain lists (space or comma separated). "
             "Each file becomes a tag named after the file.",
    )
    parser.add_argument(
        "-o", "--output",
        default="geosite.dat",
        metavar="OUTPUT",
        help="Output .dat file (default: geosite.dat)",
    )
    args = parser.parse_args()

    files = parse_files(args.files)

    entries = {}
    for filepath in files:
        if not os.path.exists(filepath):
            print(f"File not found: {filepath}", file=sys.stderr)
            sys.exit(1)
        tag = tag_from_filename(filepath)
        domains = read_domains_from_file(filepath)
        if not domains:
            print(f"Warning: {filepath} is empty, skipping.", file=sys.stderr)
            continue
        entries[tag] = domains
        print(f"Loaded {len(domains)} domains from {filepath} -> tag: {tag.lower()}")

    if not entries:
        print("No domains loaded. Exiting.", file=sys.stderr)
        sys.exit(1)

    print()
    build_dat(entries, args.output)


if __name__ == "__main__":
    main()
