#!/bin/sh

echo "Unzipping version from NuGet:"

from_nuget="$(mktemp --directory)"
from_local="$(mktemp --directory)"

ls "${DOWNLOADED_NUPKG:?}"
cp "$DOWNLOADED_NUPKG" "$from_nuget"/zip.zip && cd "$from_nuget" && unzip zip.zip && rm zip.zip && cd - || exit 1

echo "Unzipped. Unzipping version from local build:"
ls "${ORIGINAL_NUPKG_DIR:?}/"
cp "$ORIGINAL_NUPKG_DIR"/"$PACKAGE_NAME".*.nupkg "$from_local"/zip.zip && cd "$from_local" && unzip zip.zip && rm zip.zip && cd - || exit 1

echo "Unzipped."

from_nuget_out="$(mktemp --tmpdir tmp.XXXXXXXX.txt)"
from_local_out="$(mktemp --tmpdir tmp.XXXXXXXX.txt)"

echo "Collecting file contents. Contents from NuGet source file: $from_nuget_out. Contents from locally built source file: $from_local_out."

cd "$from_local" && find . -type f -exec sha256sum {} \; | sort | tee "$from_local_out" && cd .. || exit 1
cd "$from_nuget" && find . -type f -and -not -name '.signature.p7s' -exec sha256sum {} \; | sort | tee "$from_nuget_out" && cd .. || exit 1

echo "Diffing."

diff "$from_local_out" "$from_nuget_out"
