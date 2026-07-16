#!/usr/bin/env python3
"""Dependency-free OpenFPGA UART board validator for POSIX hosts."""
from __future__ import annotations

import argparse
from collections import Counter
import os
import select
import termios
import time

SOF, VERSION, MAX_PAYLOAD = 0xA5, 0x01, 32
TYPE_NAMES = {
    0x01: "HEARTBEAT", 0x02: "DEBUG_PRINT", 0x03: "EVENT",
    0x04: "WATCH", 0x05: "STATUS", 0x10: "TRACE_SPAN_BEGIN",
    0x11: "TRACE_SPAN_END", 0x12: "TRACE_MARK", 0x13: "TRACE_VALUE",
    0x14: "TRACE_DROP", 0x21: "MONITOR_READ_RESP",
    0x23: "MONITOR_WRITE_RESP", 0x30: "PROFILER_SNAPSHOT",
    0x31: "PROFILER_ALERT", 0x40: "LA_CAPTURE_HEADER",
    0x41: "LA_SAMPLE_DATA", 0x42: "LA_CAPTURE_STATUS",
    0x43: "LA_TRIGGER_EVENT",
}
MONITOR_READ_REQ = 0x20
MONITOR_READ_RESP = 0x21


class Decoder:
    def __init__(self) -> None:
        self.buffer = bytearray()
        self.frames: list[tuple[int, bytes]] = []
        self.checksum_errors = 0
        self.sync_drops = 0
        self.version_errors = 0
        self.locked = False
        self.bad_frames: list[bytes] = []

    def feed(self, data: bytes) -> None:
        self.buffer.extend(data)
        while len(self.buffer) >= 5:
            if self.buffer[0] != SOF:
                del self.buffer[0]
                self.sync_drops += 1
                continue
            length = self.buffer[3]
            if (self.buffer[1] != VERSION or self.buffer[2] not in TYPE_NAMES or
                    length > MAX_PAYLOAD):
                del self.buffer[0]
                self.sync_drops += 1
                continue
            total = length + 5
            if len(self.buffer) < total:
                return
            raw = bytes(self.buffer[:total])
            checksum = 0
            for value in raw[1:-1]:
                checksum ^= value
            if checksum != raw[-1]:
                # Before the first valid frame, an 0xA5 inside the partial frame
                # present at open time is only a false sync candidate.
                if self.locked:
                    self.checksum_errors += 1
                    if len(self.bad_frames) < 4:
                        self.bad_frames.append(raw)
                else:
                    self.sync_drops += 1
                del self.buffer[0]
                continue
            del self.buffer[:total]
            if raw[1] != VERSION:
                self.version_errors += 1
                continue
            self.frames.append((raw[2], raw[4:-1]))
            self.locked = True


def configure(fd: int, baud: int) -> None:
    speeds = {115200: termios.B115200, 230400: termios.B230400,
              460800: termios.B460800, 921600: termios.B921600}
    if baud not in speeds:
        raise ValueError(f"unsupported baud: {baud}")
    attrs = termios.tcgetattr(fd)
    attrs[0] = 0
    attrs[1] = 0
    attrs[2] = termios.CS8 | termios.CREAD | termios.CLOCAL
    attrs[3] = 0
    attrs[4] = attrs[5] = speeds[baud]
    attrs[6][termios.VMIN] = 0
    attrs[6][termios.VTIME] = 0
    termios.tcsetattr(fd, termios.TCSANOW, attrs)
    termios.tcflush(fd, termios.TCIFLUSH)


def u16(value: int) -> bytes:
    return bytes((value & 0xFF, (value >> 8) & 0xFF))


def read_u16(data: bytes, offset: int) -> int:
    return data[offset] | (data[offset + 1] << 8)


def read_u32(data: bytes, offset: int) -> int:
    return sum(data[offset + index] << (8 * index) for index in range(4))


def make_frame(msg_type: int, payload: bytes) -> bytes:
    body = bytes((VERSION, msg_type, len(payload))) + payload
    checksum = 0
    for value in body:
        checksum ^= value
    return bytes((SOF,)) + body + bytes((checksum,))


def monitor_read_frame(sequence: int, address: int) -> bytes:
    return make_frame(MONITOR_READ_REQ, u16(sequence) + u16(address) + b"\x04")


def monitor_read(port: str, baud: int, address: int, timeout: float) -> None:
    fd = os.open(port, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    decoder = Decoder()
    sequence = 0x4100
    request = monitor_read_frame(sequence, address)
    try:
        configure(fd, baud)
        written = os.write(fd, request)
        if written != len(request):
            raise RuntimeError(f"short UART write: {written}/{len(request)} bytes")
        deadline = time.monotonic() + timeout
        checked = 0
        while time.monotonic() < deadline:
            readable, _, _ = select.select([fd], [], [], min(0.05, deadline-time.monotonic()))
            if not readable:
                continue
            decoder.feed(os.read(fd, 4096))
            while checked < len(decoder.frames):
                msg_type, payload = decoder.frames[checked]
                checked += 1
                if msg_type != MONITOR_READ_RESP or len(payload) < 14:
                    continue
                if read_u16(payload, 4) != sequence:
                    continue
                response_address = read_u16(payload, 6)
                status = payload[8]
                width = payload[9]
                value = read_u32(payload, 10)
                print(f"monitor_read seq=0x{sequence:04X} addr=0x{response_address:04X} "
                      f"status={status} width={width} value=0x{value:08X} "
                      f"checksum_errors={decoder.checksum_errors}")
                if response_address != address:
                    raise RuntimeError("Monitor response address mismatch")
                if status != 0:
                    raise RuntimeError(f"Monitor returned status {status}")
                if width != 4:
                    raise RuntimeError(f"Monitor returned width {width}, expected 4")
                if decoder.checksum_errors:
                    raise RuntimeError("UART checksum error while waiting for Monitor response")
                print("PASS: UART Monitor read validation")
                return
        raise TimeoutError(
            f"Monitor read timeout: addr=0x{address:04X} timeout={timeout:.3f}s "
            f"valid_frames={len(decoder.frames)} checksum_errors={decoder.checksum_errors}"
        )
    finally:
        os.close(fd)


def validate(port: str, baud: int, duration: float, minimum: int) -> None:
    fd = os.open(port, os.O_RDONLY | os.O_NOCTTY | os.O_NONBLOCK)
    decoder = Decoder()
    byte_count = 0
    started = time.monotonic()
    try:
        configure(fd, baud)
        deadline = started + duration
        while time.monotonic() < deadline:
            readable, _, _ = select.select([fd], [], [], min(0.25, deadline-time.monotonic()))
            if readable:
                data = os.read(fd, 4096)
                byte_count += len(data)
                decoder.feed(data)
    finally:
        os.close(fd)
    elapsed = max(time.monotonic() - started, 1e-9)
    counts = Counter(TYPE_NAMES.get(kind, f"0x{kind:02x}") for kind, _ in decoder.frames)
    print(f"port={port} baud={baud} seconds={elapsed:.3f} bytes={byte_count} "
          f"rate={byte_count/elapsed:.1f}B/s frames={len(decoder.frames)}")
    print("types=" + ", ".join(f"{name}:{count}" for name, count in sorted(counts.items())))
    print(f"checksum_errors={decoder.checksum_errors} version_errors={decoder.version_errors} "
          f"initial_sync_drops={decoder.sync_drops}")
    for index, raw in enumerate(decoder.bad_frames):
        print(f"bad_frame[{index}]={raw.hex()}")
    if len(decoder.frames) < minimum:
        raise RuntimeError(f"only {len(decoder.frames)} valid frames, expected at least {minimum}")
    if decoder.checksum_errors or decoder.version_errors:
        raise RuntimeError("UART protocol errors detected")
    print("PASS: UART OpenFPGA frame validation")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", default="/dev/serial/by-id/usb-1a86_USB_Serial-if00-port0")
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument("--duration", type=float, default=5.0)
    parser.add_argument("--minimum-frames", type=int, default=10)
    parser.add_argument("--monitor-read-address", type=lambda value: int(value, 0))
    parser.add_argument("--monitor-timeout", type=float, default=2.0)
    args = parser.parse_args()
    if args.monitor_read_address is None:
        validate(args.port, args.baud, args.duration, args.minimum_frames)
    else:
        monitor_read(args.port, args.baud, args.monitor_read_address, args.monitor_timeout)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
