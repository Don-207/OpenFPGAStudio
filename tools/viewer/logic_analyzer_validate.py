#!/usr/bin/env python3
"""M26 UART Logic Analyzer validator. Run --self-test before opening hardware."""

import argparse
import time

SOF, VERSION = 0xA5, 0x01
READ_REQ, READ_RESP, WRITE_REQ, WRITE_RESP = 0x20, 0x21, 0x22, 0x23
LA_HEADER, LA_DATA, LA_STATUS, LA_TRIGGER = 0x40, 0x41, 0x42, 0x43
LA_ID = 0x0060
LA_VERSION = 0x0064
LA_CONTROL = 0x0068
LA_STATUS_REG = 0x006C
LA_DIVISOR = 0x0070
LA_DEPTH = 0x0074
LA_PRETRIGGER = 0x0078
LA_TRIGGER_MODE = 0x007C
LA_TRIGGER_CHANNEL = 0x0080
LA_TRIGGER_VALUE = 0x0084
LA_TRIGGER_MASK = 0x0088
LA_COMMAND = 0x008C
LA_CAPTURE_ID = 0x0090
EXPECTED_LA_ID = 0x4F464C41


def u16(value):
    return bytes((value & 0xFF, (value >> 8) & 0xFF))


def u32(value):
    return bytes((value >> shift) & 0xFF for shift in (0, 8, 16, 24))


def read_u16(data, offset=0):
    return data[offset] | (data[offset + 1] << 8)


def read_u32(data, offset=0):
    return sum(data[offset + index] << (8 * index) for index in range(4))


def frame(msg_type, payload=b""):
    body = bytes((VERSION, msg_type, len(payload))) + payload
    checksum = 0
    for byte in body:
        checksum ^= byte
    return bytes((SOF,)) + body + bytes((checksum,))


def monitor_read(seq, address):
    return frame(READ_REQ, u16(seq) + u16(address) + b"\x04")


def monitor_write(seq, address, value, mask=0xFFFFFFFF):
    return frame(WRITE_REQ, u16(seq) + u16(address) + b"\x04" + u32(value) + u32(mask))


class Decoder:
    def __init__(self):
        self.buffer = bytearray()
        self.checksum_errors = 0

    def feed(self, data):
        self.buffer.extend(data)
        result = []
        while True:
            while self.buffer and self.buffer[0] != SOF:
                del self.buffer[0]
            if len(self.buffer) < 5:
                break
            length = self.buffer[3]
            total = length + 5
            if len(self.buffer) < total:
                break
            raw = bytes(self.buffer[:total])
            del self.buffer[:total]
            checksum = 0
            for byte in raw[1:-1]:
                checksum ^= byte
            if checksum != raw[-1]:
                self.checksum_errors += 1
                continue
            result.append((raw[2], raw[4:-1]))
        return result


def self_test():
    decoder = Decoder()
    request = monitor_write(7, LA_COMMAND, 1)
    assert request[0] == SOF and request[2] == WRITE_REQ and request[3] == 13
    response = frame(READ_RESP, u32(10) + u16(3) + u16(LA_ID) + b"\x00\x04" + u32(EXPECTED_LA_ID))
    assert decoder.feed(response[:4]) == []
    decoded = decoder.feed(response[4:])
    assert decoded[0][0] == READ_RESP and read_u32(decoded[0][1], 10) == EXPECTED_LA_ID
    bad = bytearray(frame(LA_STATUS, bytes(20)))
    bad[-1] ^= 1
    assert decoder.feed(bad) == [] and decoder.checksum_errors == 1
    print("PASS: OpenFPGA Logic Analyzer validator self-test passed")


class Link:
    def __init__(self, serial_port):
        self.serial = serial_port
        self.decoder = Decoder()
        self.seq = 1
        self.la_frames = []

    def transact(self, request, expected_type, seq, timeout=2.0):
        self.serial.write(request)
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            matched_payload = None
            for msg_type, payload in self.decoder.feed(self.serial.read(256)):
                if msg_type in (LA_HEADER, LA_DATA, LA_STATUS, LA_TRIGGER):
                    self.la_frames.append((msg_type, payload))
                if msg_type == expected_type and len(payload) >= 6 and read_u16(payload, 4) == seq:
                    if payload[8] != 0:
                        raise RuntimeError(f"Monitor status {payload[8]} for sequence {seq}")
                    matched_payload = payload
            if matched_payload is not None:
                return matched_payload
        raise TimeoutError(f"response timeout for sequence {seq}")

    def read_reg(self, address):
        seq = self.seq
        self.seq += 1
        payload = self.transact(monitor_read(seq, address), READ_RESP, seq)
        return read_u32(payload, 10)

    def write_reg(self, address, value, mask=0xFFFFFFFF):
        seq = self.seq
        self.seq += 1
        self.transact(monitor_write(seq, address, value, mask), WRITE_RESP, seq)

    def collect_capture(self, timeout=8.0):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            self.la_frames.extend(self.decoder.feed(self.serial.read(256)))
            kinds = {kind for kind, _ in self.la_frames}
            if LA_HEADER in kinds and LA_DATA in kinds and LA_STATUS in kinds and LA_TRIGGER in kinds:
                return
        counts = {kind: sum(item[0] == kind for item in self.la_frames)
                  for kind in (LA_HEADER, LA_DATA, LA_STATUS, LA_TRIGGER)}
        raise TimeoutError(
            "LA header/trigger/data/status capture frames not received; "
            f"counts={counts} checksum_errors={self.decoder.checksum_errors} "
            f"buffered_bytes={len(self.decoder.buffer)}"
        )


def validate(port, baud):
    try:
        import serial
    except ImportError as error:
        raise RuntimeError("pyserial is required: python -m pip install pyserial") from error
    with serial.Serial(port, baud, timeout=0.05, write_timeout=1) as uart:
        uart.reset_input_buffer()
        link = Link(uart)
        la_id = link.read_reg(LA_ID)
        version = link.read_reg(LA_VERSION)
        if la_id != EXPECTED_LA_ID:
            raise RuntimeError(f"unexpected LA_ID 0x{la_id:08X}")
        for address, value in ((LA_DIVISOR, 4), (LA_DEPTH, 64), (LA_PRETRIGGER, 16),
                               (LA_TRIGGER_MODE, 0), (LA_TRIGGER_CHANNEL, 2),
                               (LA_TRIGGER_VALUE, 1), (LA_TRIGGER_MASK, 1)):
            link.write_reg(address, value)
            if link.read_reg(address) != value:
                raise RuntimeError(f"register 0x{address:04X} readback mismatch")
        capture_before = link.read_reg(LA_CAPTURE_ID)
        link.write_reg(LA_CONTROL, 0x1)
        link.write_reg(LA_COMMAND, 0x1)   # arm
        link.write_reg(LA_COMMAND, 0x8)   # deterministic force trigger
        deadline = time.monotonic() + 4
        while time.monotonic() < deadline and not (link.read_reg(LA_STATUS_REG) & 0x8):
            time.sleep(0.05)
        else:
            if not (link.read_reg(LA_STATUS_REG) & 0x8):
                raise TimeoutError("LA capture did not reach done")
        link.write_reg(LA_COMMAND, 0x10)  # readout
        link.collect_capture()
        capture_after = link.read_reg(LA_CAPTURE_ID)
        if capture_after <= capture_before:
            raise RuntimeError("capture_id did not increment")
        link.write_reg(LA_COMMAND, 0x4)   # clear
        counts = {kind: sum(item[0] == kind for item in link.la_frames) for kind in (LA_HEADER, LA_DATA, LA_STATUS, LA_TRIGGER)}
        print(f"PASS: OpenFPGA Logic Analyzer board validation passed; LA_VERSION=0x{version:08X} capture_id={capture_after} frames={counts} checksum_errors={link.decoder.checksum_errors}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--port")
    parser.add_argument("--baud", type=int, default=115200)
    args = parser.parse_args()
    if args.self_test:
        self_test()
    elif args.port:
        self_test()
        validate(args.port, args.baud)
    else:
        parser.error("use --self-test or --port COMx")


if __name__ == "__main__":
    main()
