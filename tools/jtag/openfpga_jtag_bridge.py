#!/usr/bin/env python3
"""Deprecated compatibility entry point for the YiFPGA JTAG Bridge."""

from __future__ import annotations

import warnings

from yifpga_jtag_bridge import *  # noqa: F401,F403
from yifpga_jtag_bridge import main


if __name__ == "__main__":
    warnings.warn(
        "openfpga_jtag_bridge.py is deprecated; use yifpga_jtag_bridge.py",
        DeprecationWarning,
        stacklevel=1,
    )
    raise SystemExit(main())
