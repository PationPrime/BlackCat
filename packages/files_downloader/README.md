# files_downloader

Resumable HTTP downloads of any files, in a background isolate.

A file is split into slices (10 MiB by default) that are downloaded in
parallel with range requests, like torrent pieces. Progress of every slice of
every file of a download lives in one binary state file, `state_<id>.fds`, so
a paused or interrupted download continues where it stopped.

## Usage

```dart
final downloader = FilesDownloader();
final download = await downloader.start(
  FilesDownloadRequest(
    id: 'movie',
    stateDirectory: '/downloads/.state',
    options: const FilesDownloadOptions(maxConnections: 4),
    files: [
      DownloadFileRequest(url: 'https://example.com/movie.mkv', savePath: '/downloads/movie.mkv'),
    ],
  ),
);

download.progress.listen((progress) => print('${progress.fraction} ${progress.bytesPerSecond}'));

switch (await download.result) {
  case FilesDownloadCompleted(:final files):
    print('done: $files');
  case FilesDownloadStopped():
    print('paused: start the same request to continue');
  case FilesDownloadFailed(:final error):
    print('failed: $error');
}
```

`download.pause()` keeps the files and the state, `download.cancel()` deletes
them, `download.setSpeedLimit(bytesPerSecond)` changes the limit on the go.
`FilesDownloader.readState(stateDirectory, id)` reads the saved progress
without starting the download.

## How a download runs

1. **Probing.** `GET` with `Range: bytes=0-0` tells the size, range support
   and the validator (`ETag` or `Last-Modified`); `HEAD` is the fallback.
   Servers that take the range as a `range=start-end` link parameter
   (googlevideo.com) use `RangeRequestMode.queryParameter`.
2. **Preparing.** The state is reused only if it was made for the same files:
   identity, size, range support, slice size and, if asked, the validator.
   Files get their full size on disk. With
   `ExistingFilePolicy.continuePrefix` a file written in order by another
   downloader is continued after its bytes.
3. **Downloading.** Missing slices go to a pool of connections. Every slice
   is downloaded from its start, so its counter is its contiguous length.
   Every checkpoint flushes the written bytes to disk before the counters
   are saved: a counter never claims bytes that are not on disk.
4. **Finishing.** File sizes are checked, the state is deleted.

## Free space

Before the files are reserved, the free space of their disk
(`GetDiskFreeSpaceExW` on Windows, `statvfs` or `df` on macOS and Linux)
must hold what the download still needs plus 1 MiB. NTFS gives an extended
file its space at once, so on Windows a file needs its whole missing size;
APFS and ext4 make it sparse, so there only the bytes not downloaded yet
count. Otherwise the download fails with `FilesDownloadErrorType.diskFull`
before anything is reserved, with `neededBytes` and `availableBytes`.

A file error during the download is checked the same way: the system may
report a full disk (`ENOSPC`, `EDQUOT`, `ERROR_DISK_FULL`…), or the error
may come from a lack of space (a failed write, an I/O error) and the free
space shows it. Errors with a cause of their own (no rights, a missing
path, a file held by another program) stay `fileSystem`. Downloaded slices
stay in the state: after freeing space the download continues.

## Server answers

- `206` with `Content-Range` starting **before** the asked position: the
  extra bytes are skipped.
- A part ending **after** the slice, or after the end of the file: only the
  bytes of the slice are written.
- A part **shorter** than asked: the rest is asked by the next request.
- A part starting **after** the asked position: the attempt is retried.
- `200` to a range request: the body is the whole file, the slice is cut
  out of it. With `If-Range` sent, `200` means the file changed.
- A different size in `Content-Range`, `416` or a failed `If-Range`: the file
  changed on the server; the state is dropped and the next start downloads
  the file anew.
- `401`, `403`, `404`, `410` fail at once; `408`, `425`, `429`, `5xx` and
  network errors are retried with a growing delay.
- A server without ranges or without a size gets one request for the whole
  file, restarted from the beginning after a failure.

## `state_<id>.fds`

Little-endian. A fixed header (magic `FDSSTATE`, version, file count, slice
size, offset of the counters, FNV-1a checksum of the header), then the files
(size, slice count, flags, identity and validator), then one `int64` counter
per slice of every file. The header is written once; a checkpoint rewrites
only the changed counters in place. A damaged header makes the state
unusable, a damaged counter is clamped to its slice.

## Tests

```sh
cd packages/files_downloader
dart test
```
