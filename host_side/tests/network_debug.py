"""
============================================
 Network Debug Script for FPGA UDP Testing
============================================

This script helps diagnose network connectivity issues between
the PC and FPGA board.

Usage:
  python network_debug.py                    # Run all tests
  python network_debug.py --ping             # Test ping only
  python network_debug.py --udp              # Test UDP only
  python network_debug.py --arp              # Test ARP only
  python network_debug.py --config           # Show network config
"""

import argparse
import socket
import struct
import sys
import time
from datetime import datetime

# Add parent directory to path
sys.path.insert(0, "..")
from config import (
    FPGA_REAL_UDP_HOST,
    FPGA_REAL_UDP_PORT,
    PC_REAL_BIND_HOST,
    PC_REAL_BIND_PORT,
)


def print_header(title: str) -> None:
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}\n")


def print_config() -> None:
    """Display current network configuration."""
    print_header("Network Configuration")
    print(f"  FPGA IP Address:    {FPGA_REAL_UDP_HOST}")
    print(f"  FPGA UDP Port:      {FPGA_REAL_UDP_PORT}")
    print(f"  PC Bind Address:    {PC_REAL_BIND_HOST}")
    print(f"  PC Bind Port:       {PC_REAL_BIND_PORT}")
    print(f"\n  FPGA MAC Address:   02:00:00:00:00:01 (hardcoded in RTL)")
    print(f"  FPGA Subnet:        169.254.0.0/16 (link-local)")
    print()
    print("  ⚠️  IMPORTANT: PC must be on same subnet as FPGA!")
    print("     Set PC IP to 169.254.0.x (e.g., 169.254.0.100)")
    print("     Subnet mask: 255.255.0.0")
    print("     Gateway: leave empty")


def check_pc_ip_config() -> bool:
    """Check if PC is configured on the correct subnet."""
    print_header("PC IP Configuration Check")

    try:
        # Get local IP addresses
        hostname = socket.gethostname()
        local_ips = socket.gethostbyname_ex(hostname)[2]

        print(f"  Hostname: {hostname}")
        print(f"  Local IPs: {', '.join(local_ips)}")

        # Check if any IP is on the 169.254.0.x subnet
        fpga_subnet = "169.254.0."
        found = False
        for ip in local_ips:
            if ip.startswith(fpga_subnet):
                print(f"  ✅ Found IP on correct subnet: {ip}")
                found = True
                break

        if not found:
            print(f"  ❌ No IP found on {fpga_subnet}x subnet!")
            print(f"\n  To fix this:")
            print(f"  1. Open Network Connections (ncpa.cpl)")
            print(f"  2. Right-click your Ethernet adapter -> Properties")
            print(f"  3. Select 'Internet Protocol Version 4 (TCP/IPv4)'")
            print(f"  4. Click 'Properties'")
            print(f"  5. Select 'Use the following IP address'")
            print(f"  6. Set IP: 169.254.0.100")
            print(f"  7. Set Subnet mask: 255.255.0.0")
            print(f"  8. Leave Gateway empty")
            print(f"  9. Click OK")
            return False

        return True

    except Exception as e:
        print(f"  ❌ Error checking IP config: {e}")
        return False


def test_ping(host: str = FPGA_REAL_UDP_HOST, count: int = 4) -> bool:
    """Test ping connectivity to FPGA."""
    print_header(f"Ping Test: {host}")

    import subprocess
    import platform

    # Determine ping command based on OS
    param = "-n" if platform.system().lower() == "windows" else "-c"
    command = ["ping", param, str(count), host]

    print(f"  Running: {' '.join(command)}")
    print()

    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=30)
        print(result.stdout)

        if result.returncode == 0:
            print(f"  ✅ Ping successful!")
            return True
        else:
            print(f"  ❌ Ping failed!")
            print(f"\n  Possible causes:")
            print(f"  1. FPGA not powered on")
            print(f"  2. Ethernet cable not connected")
            print(f"  3. PC not on 169.254.0.x subnet")
            print(f"  4. FPGA ARP responder not working")
            return False

    except subprocess.TimeoutExpired:
        print(f"  ❌ Ping timed out")
        return False
    except FileNotFoundError:
        print(f"  ❌ Ping command not found")
        return False


def test_arp(host: str = FPGA_REAL_UDP_HOST) -> bool:
    """Test ARP resolution."""
    print_header(f"ARP Test: {host}")

    import subprocess
    import platform

    # First, try to ping to populate ARP cache
    print("  Step 1: Sending ping to populate ARP cache...")
    param = "-n" if platform.system().lower() == "windows" else "-c"
    subprocess.run(["ping", param, "1", host], capture_output=True, timeout=10)

    # Check ARP table
    print("  Step 2: Checking ARP table...")
    try:
        if platform.system().lower() == "windows":
            result = subprocess.run(["arp", "-a"], capture_output=True, text=True, timeout=10)
        else:
            result = subprocess.run(["arp", "-n"], capture_output=True, text=True, timeout=10)

        print(result.stdout)

        # Look for FPGA MAC address
        fpga_mac = "02-00-00-00-00-01"  # Windows format
        fpga_mac_alt = "02:00:00:00:00:01"  # Linux format

        if fpga_mac in result.stdout or fpga_mac_alt in result.stdout:
            print(f"  ✅ FPGA MAC address found in ARP table!")
            return True
        else:
            print(f"  ❌ FPGA MAC address not found in ARP table")
            print(f"\n  Expected MAC: {fpga_mac}")
            print(f"\n  Possible causes:")
            print(f"  1. FPGA ARP responder not working")
            print(f"  2. FPGA not responding to ARP requests")
            print(f"  3. Network connectivity issue")
            return False

    except Exception as e:
        print(f"  ❌ Error checking ARP table: {e}")
        return False


def test_udp_send_receive(
    host: str = FPGA_REAL_UDP_HOST,
    port: int = FPGA_REAL_UDP_PORT,
    bind_host: str = PC_REAL_BIND_HOST,
    bind_port: int = PC_REAL_BIND_PORT,
) -> bool:
    """Test UDP send/receive to FPGA."""
    print_header(f"UDP Test: {host}:{port}")

    # Create a simple test packet (48 bytes, matching upstream protocol)
    # Header: 0xAA55
    # Length: 48
    # Stock code: "000858SZ" (8 bytes)
    # Timestamp: current time (4 bytes)
    # OHLCV: dummy data (20 bytes)
    # Reserved: zeros (8 bytes)
    # CRC32: placeholder (4 bytes)

    import zlib

    print("  Creating test UDP packet...")

    header = 0xAA55
    length = 48
    stock_code = b"000858SZ"
    timestamp = int(time.time()) & 0xFFFFFFFF
    open_price = 10.0
    high_price = 10.5
    low_price = 9.5
    close_price = 10.2
    volume = 1000
    reserved = b"\x00" * 8

    # Pack without CRC
    body = struct.pack(
        ">HH8sIffffI8s",
        header,
        length,
        stock_code,
        timestamp,
        open_price,
        high_price,
        low_price,
        close_price,
        volume,
        reserved,
    )

    # Calculate CRC32
    crc = zlib.crc32(body) & 0xFFFFFFFF
    packet = body + struct.pack(">I", crc)

    print(f"  Packet size: {len(packet)} bytes")
    print(f"  Header: 0x{header:04X}")
    print(f"  Stock code: {stock_code.decode()}")
    print(f"  Timestamp: {timestamp}")
    print(f"  CRC32: 0x{crc:08X}")

    # Create socket and send
    print(f"\n  Sending to {host}:{port}...")
    print(f"  Binding to {bind_host}:{bind_port}...")

    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.bind((bind_host, bind_port))
        sock.settimeout(2.0)  # 2 second timeout

        # Send packet
        sock.sendto(packet, (host, port))
        print(f"  ✅ Packet sent!")

        # Wait for response
        print(f"\n  Waiting for response (2s timeout)...")
        try:
            data, addr = sock.recvfrom(1024)
            print(f"  ✅ Received {len(data)} bytes from {addr}")

            # Parse response (44 bytes downstream)
            if len(data) == 44:
                resp_header = struct.unpack(">H", data[:2])[0]
                if resp_header == 0x55AA:
                    print(f"  ✅ Valid downstream header: 0x{resp_header:04X}")
                    print(f"\n  UDP communication successful!")
                    return True
                else:
                    print(f"  ❌ Invalid response header: 0x{resp_header:04X}")
            else:
                print(f"  ❌ Unexpected response length: {len(data)} (expected 44)")

        except socket.timeout:
            print(f"  ❌ Timeout - no response received")
            print(f"\n  Possible causes:")
            print(f"  1. FPGA UDP parser not working")
            print(f"  2. FPGA application not processing packets")
            print(f"  3. Firewall blocking UDP")
            return False

        finally:
            sock.close()

    except Exception as e:
        print(f"  ❌ Error: {e}")
        return False

    return False


def test_udp_with_mock(host: str = "127.0.0.1", port: int = 9001) -> bool:
    """Test UDP with mock FPGA server."""
    print_header("UDP Mock Test")

    import threading
    from mock_fpga import serve as start_mock_server

    print(f"  Starting mock FPGA server on {host}:{port}...")

    # Start mock server in background
    server_thread = threading.Thread(
        target=start_mock_server,
        kwargs={"host": host, "port": port},
        daemon=True,
    )
    server_thread.start()
    time.sleep(0.5)  # Wait for server to start

    print(f"  Mock server started")

    # Test with mock
    result = test_udp_send_receive(
        host=host,
        port=port,
        bind_host="",
        bind_port=0,
    )

    return result


def run_all_tests(args) -> None:
    """Run all network tests."""
    print_header("FPGA Network Debug Tool")
    print(f"  Started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    results = {}

    # 1. Show config
    if args.config or not any([args.ping, args.udp, args.arp]):
        print_config()

    # 2. Check PC IP config
    results["pc_ip"] = check_pc_ip_config()

    # 3. Ping test
    if args.ping or not any([args.udp, args.arp]):
        results["ping"] = test_ping()

    # 4. ARP test
    if args.arp:
        results["arp"] = test_arp()

    # 5. UDP test
    if args.udp:
        if args.mock:
            results["udp_mock"] = test_udp_with_mock()
        else:
            results["udp"] = test_udp_send_receive()

    # Summary
    print_header("Test Summary")
    for name, passed in results.items():
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"  {status}  {name}")

    passed = sum(1 for v in results.values() if v)
    total = len(results)
    print(f"\n  Result: {passed}/{total} tests passed")

    if passed < total:
        print(f"\n  ⚠️  Some tests failed. Check the output above for details.")
        print(f"  See the README or network_setup_guide.md for troubleshooting.")
    else:
        print(f"\n  ✅ All tests passed! Network is working correctly.")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="FPGA Network Debug Tool",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python network_debug.py                    # Run all tests
  python network_debug.py --ping             # Test ping only
  python network_debug.py --udp              # Test UDP only
  python network_debug.py --udp --mock       # Test UDP with mock server
  python network_debug.py --arp              # Test ARP only
  python network_debug.py --config           # Show network config
        """,
    )

    parser.add_argument("--ping", action="store_true", help="Test ping connectivity")
    parser.add_argument("--udp", action="store_true", help="Test UDP communication")
    parser.add_argument("--arp", action="store_true", help="Test ARP resolution")
    parser.add_argument("--config", action="store_true", help="Show network configuration")
    parser.add_argument("--mock", action="store_true", help="Use mock FPGA server for UDP test")
    parser.add_argument("--host", default=FPGA_REAL_UDP_HOST, help="FPGA IP address")
    parser.add_argument("--port", type=int, default=FPGA_REAL_UDP_PORT, help="FPGA UDP port")

    args = parser.parse_args()

    # Override config if specified
    if args.host != FPGA_REAL_UDP_HOST:
        global FPGA_REAL_UDP_HOST
        FPGA_REAL_UDP_HOST = args.host
    if args.port != FPGA_REAL_UDP_PORT:
        global FPGA_REAL_UDP_PORT
        FPGA_REAL_UDP_PORT = args.port

    run_all_tests(args)


if __name__ == "__main__":
    main()
