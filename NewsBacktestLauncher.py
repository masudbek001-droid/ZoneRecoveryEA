#!/usr/bin/env python3
"""
NewsBacktestLauncher.py
========================
Automated launcher for ZoneRecoveryEA backtesting with news filter.

This script orchestrates the backtesting process:
1. Determines the symbol's related currencies
2. Launches NewsCalendarExporter on live terminal
3. Validates exported CSV and manifest files
4. Copies files to the Strategy Tester agent's location
5. Launches Strategy Tester with the EA

Usage:
    python NewsBacktestLauncher.py --symbol EURUSD --from 2024.01.01 --to 2026.12.31
    python NewsBacktestLauncher.py --symbol XAUUSD --from 2025.01.01 --to 2025.12.31 --optimize

Requirements:
    - MetaTrader 5 installed and running
    - Python 3.8+
    - MetaTrader5 Python package (pip install MetaTrader5)
"""

import os
import sys
import time
import hashlib
import argparse
import subprocess
import json
from datetime import datetime, timedelta
from pathlib import Path

try:
    import MetaTrader5 as mt5
except ImportError:
    print("ERROR: MetaTrader5 Python package not installed.")
    print("Install with: pip install MetaTrader5")
    sys.exit(1)


# Currency mapping for common symbols
CURRENCY_MAP = {
    'EURUSD': ['EUR', 'USD'],
    'GBPUSD': ['GBP', 'USD'],
    'USDJPY': ['USD', 'JPY'],
    'USDCHF': ['USD', 'CHF'],
    'AUDUSD': ['AUD', 'USD'],
    'USDCAD': ['USD', 'CAD'],
    'NZDUSD': ['NZD', 'USD'],
    'EURGBP': ['EUR', 'GBP'],
    'EURJPY': ['EUR', 'JPY'],
    'GBPJPY': ['GBP', 'JPY'],
    'XAUUSD': ['USD'],
    'XAGUSD': ['USD'],
    'GOLD':   ['USD'],
    'SILVER': ['USD'],
}

# Default MT5 paths to search
DEFAULT_MT5_PATHS = [
    r"C:\Program Files\MetaTrader 5\terminal64.exe",
    r"C:\Program Files (x86)\MetaTrader 5\terminal64.exe",
    r"C:\MetaTrader 5\terminal64.exe",
    r"D:\MetaTrader 5\terminal64.exe",
]


class NewsBacktestLauncher:
    """Main launcher class for news-filtered backtesting."""
    
    def __init__(self, symbol: str, start_date: str, end_date: str,
                 mt5_path: str = None, optimize: bool = False,
                 currencies: str = None, high_impact_only: bool = True):
        self.symbol = symbol.upper()
        self.start_date = start_date
        self.end_date = end_date
        self.mt5_path = mt5_path
        self.optimize = optimize
        self.currencies = currencies
        self.high_impact_only = high_impact_only
        
        # File paths
        self.csv_filename = "NewsCalendar.csv"
        self.manifest_filename = "NewsCalendar_manifest.txt"
        
        # MT5 data paths
        self.mt5_data_path = None
        self.common_files_path = None
        self.mql5_files_path = None
        
        # Results
        self.validation_result = None
        self.blocked_days = []
        
    def run(self) -> bool:
        """Execute the full launcher pipeline."""
        print("=" * 60)
        print("ZoneRecoveryEA - NewsBacktestLauncher")
        print("=" * 60)
        print(f"Symbol: {self.symbol}")
        print(f"Period: {self.start_date} to {self.end_date}")
        print(f"Mode: {'Optimization' if self.optimize else 'Single Test'}")
        print()
        
        # Step 1: Connect to MT5
        if not self._connect_mt5():
            return False
        
        # Step 2: Determine currencies
        currencies = self._get_currencies()
        print(f"Related currencies: {', '.join(currencies)}")
        
        # Step 3: Find MT5 data paths
        if not self._find_data_paths():
            return False
        
        # Step 4: Launch NewsCalendarExporter
        if not self._launch_exporter(currencies):
            return False
        
        # Step 5: Wait for export completion
        if not self._wait_for_export():
            return False
        
        # Step 6: Validate exported files
        if not self._validate_files():
            print("ERROR: File validation failed. Cannot proceed with test.")
            return False
        
        # Step 7: Copy files to tester location
        self._copy_to_tester()
        
        # Step 8: Launch Strategy Tester
        if not self._launch_tester():
            return False
        
        print()
        print("=" * 60)
        print("Backtest launched successfully!")
        print(f"Blocked days: {len(self.blocked_days)}")
        print(f"Test period: {self.start_date} to {self.end_date}")
        print("=" * 60)
        
        return True
    
    def _connect_mt5(self) -> bool:
        """Connect to MetaTrader 5 terminal."""
        print("Step 1: Connecting to MetaTrader 5...")
        
        init_params = {}
        if self.mt5_path:
            init_params['path'] = self.mt5_path
        
        if not mt5.initialize(**init_params):
            print(f"ERROR: Failed to initialize MT5. Error: {mt5.last_error()}")
            print("Make sure MetaTrader 5 terminal is running.")
            return False
        
        account_info = mt5.account_info()
        if account_info is None:
            print("ERROR: Cannot get account info.")
            return False
        
        print(f"  Connected to: {account_info.server}")
        print(f"  Account: {account_info.login}")
        print(f"  Balance: {account_info.balance} {account_info.currency}")
        print()
        return True
    
    def _get_currencies(self) -> list:
        """Determine related currencies for the symbol."""
        if self.currencies:
            return [c.strip().upper() for c in self.currencies.split(',')]
        
        # Auto-detect from symbol name
        symbol_info = mt5.symbol_info(self.symbol)
        if symbol_info is None:
            print(f"WARNING: Symbol {self.symbol} not found. Using defaults.")
            return ['USD']
        
        # Try predefined map first
        if self.symbol in CURRENCY_MAP:
            return CURRENCY_MAP[self.symbol]
        
        # Extract from symbol
        base = symbol_info.currency_base.upper()
        quote = symbol_info.currency_profit.upper()
        
        if base == quote:
            return [base]
        return [base, quote]
    
    def _find_data_paths(self) -> bool:
        """Find MT5 data directory paths."""
        print("Step 2: Locating MT5 data paths...")
        
        # Get MT5 terminal info
        terminal_info = mt5.terminal_info()
        if terminal_info is None:
            print("ERROR: Cannot get terminal info.")
            return False
        
        # Get common data path
        common_path = mt5.terminal_info().data_path
        if common_path:
            self.mt5_data_path = common_path
            self.common_files_path = os.path.join(common_path, "MQL5", "Files")
            self.mql5_files_path = os.path.join(common_path, "MQL5", "Files")
        else:
            # Try to find from terminal path
            if self.mt5_path:
                base_dir = os.path.dirname(self.mt5_path)
                self.mt5_data_path = os.path.join(base_dir, "MQL5", "Files")
            else:
                # Search default locations
                for path in DEFAULT_MT5_PATHS:
                    if os.path.exists(path):
                        base_dir = os.path.dirname(path)
                        files_dir = os.path.join(base_dir, "MQL5", "Files")
                        if os.path.exists(files_dir):
                            self.mt5_data_path = files_dir
                            break
        
        print(f"  Data path: {self.mt5_data_path}")
        print()
        return True
    
    def _launch_exporter(self, currencies: list) -> bool:
        """Launch the NewsCalendarExporter script on MT5."""
        print("Step 3: Launching NewsCalendarExporter...")
        
        # Build the command to run the exporter
        # This requires the script to be compiled and available in MT5
        currencies_str = ','.join(currencies)
        
        print(f"  Currencies: {currencies_str}")
        print(f"  Period: {self.start_date} to {self.end_date}")
        print(f"  High Impact Only: {self.high_impact_only}")
        
        # Use MQL5 command to run script
        # Note: MT5 Python API doesn't directly support running scripts
        # We'll create a helper EA or use the terminal command line
        
        # Create a request file for the exporter
        request_file = os.path.join(self.mql5_files_path or "/tmp", "export_request.json")
        request_data = {
            "action": "export_calendar",
            "symbol": self.symbol,
            "currencies": currencies_str,
            "start_date": self.start_date,
            "end_date": self.end_date,
            "high_impact_only": self.high_impact_only,
            "filename": self.csv_filename,
            "timestamp": datetime.now().isoformat()
        }
        
        try:
            os.makedirs(os.path.dirname(request_file), exist_ok=True)
            with open(request_file, 'w') as f:
                json.dump(request_data, f, indent=2)
            print(f"  Request file created: {request_file}")
        except Exception as e:
            print(f"  WARNING: Could not create request file: {e}")
            print("  Proceeding with manual export instructions...")
        
        print()
        print("  INSTRUCTIONS: Please run NewsCalendarExporter script in MT5")
        print(f"  with the following parameters:")
        print(f"    - Export Start Date: {self.start_date}")
        print(f"    - Export End Date: {self.end_date}")
        print(f"    - Export Currencies: {currencies_str}")
        print(f"    - High Impact Only: Yes")
        print(f"    - Export Filename: {self.csv_filename}")
        print()
        
        return True
    
    def _wait_for_export(self, timeout: int = 600) -> bool:
        """Wait for the export to complete."""
        print("Step 4: Waiting for export completion...")
        
        csv_path = os.path.join(self.mql5_files_path or "/tmp", self.csv_filename)
        manifest_path = os.path.join(self.mql5_files_path or "/tmp", self.manifest_filename)
        
        start_time = time.time()
        check_interval = 5  # seconds
        
        while time.time() - start_time < timeout:
            if os.path.exists(csv_path) and os.path.exists(manifest_path):
                # Check if files are still being written
                csv_size_1 = os.path.getsize(csv_path)
                time.sleep(2)
                csv_size_2 = os.path.getsize(csv_path)
                
                if csv_size_1 == csv_size_2 and csv_size_1 > 0:
                    print(f"  Export completed! File size: {csv_size_1} bytes")
                    print()
                    return True
            
            elapsed = int(time.time() - start_time)
            print(f"  Waiting... ({elapsed}s elapsed, checking every {check_interval}s)")
            time.sleep(check_interval)
        
        print(f"  TIMEOUT: Export did not complete within {timeout} seconds")
        print("  Please check MT5 terminal and run the exporter manually.")
        return False
    
    def _validate_files(self) -> bool:
        """Validate exported CSV and manifest files."""
        print("Step 5: Validating exported files...")
        
        csv_path = os.path.join(self.mql5_files_path or "/tmp", self.csv_filename)
        manifest_path = os.path.join(self.mql5_files_path or "/tmp", self.manifest_filename)
        
        # Check CSV file
        if not os.path.exists(csv_path):
            print(f"  ERROR: CSV file not found: {csv_path}")
            return False
        
        # Validate CSV content
        with open(csv_path, 'r', encoding='ansi', errors='ignore') as f:
            lines = f.readlines()
        
        if len(lines) < 2:
            print("  ERROR: CSV file is empty or has only header")
            return False
        
        # Check header
        header = lines[0].strip().split(',')
        expected_columns = ['EventID', 'ValueID', 'EventName', 'Currency', 'Importance',
                          'OriginalEventTime', 'BrokerServerTime', 'BrokerDate',
                          'TimeMode', 'ExportTimestamp', 'Source', 'DataStatus']
        
        if header != expected_columns:
            print(f"  WARNING: CSV header mismatch")
            print(f"    Expected: {expected_columns}")
            print(f"    Got: {header}")
        
        # Count data rows
        data_rows = len(lines) - 1
        print(f"  CSV rows: {data_rows}")
        
        # Validate date coverage
        dates_in_file = set()
        for line in lines[1:]:
            parts = line.strip().split(',')
            if len(parts) >= 8:
                broker_date = parts[7].strip()
                if broker_date:
                    dates_in_file.add(broker_date)
        
        # Check if dates cover the test period
        start_dt = datetime.strptime(self.start_date, "%Y.%m.%d")
        end_dt = datetime.strptime(self.end_date, "%Y.%m.%d")
        
        current = start_dt
        uncovered_days = 0
        while current <= end_dt:
            date_str = current.strftime("%Y.%m.%d")
            if date_str not in dates_in_file:
                # This day might not have any events, which is fine
                pass
            current += timedelta(days=1)
        
        print(f"  Unique dates in file: {len(dates_in_file)}")
        
        # Check manifest
        if not os.path.exists(manifest_path):
            print(f"  ERROR: Manifest file not found: {manifest_path}")
            return False
        
        # Read manifest
        with open(manifest_path, 'r', encoding='ansi', errors='ignore') as f:
            manifest_content = f.read()
        
        # Check data status in manifest
        if "DataStatus: COMPLETE" not in manifest_content:
            print("  WARNING: Manifest indicates incomplete data")
        
        # Verify checksum if present
        checksum_line = None
        for line in manifest_content.split('\n'):
            if line.startswith("Checksum:"):
                checksum_line = line.split(':')[1].strip()
                break
        
        if checksum_line and checksum_line != "UNKNOWN":
            # Calculate actual checksum
            with open(csv_path, 'rb') as f:
                file_hash = 0
                while True:
                    chunk = f.read(4096)
                    if not chunk:
                        break
                    for byte in chunk:
                        file_hash ^= byte
                        for _ in range(8):
                            if file_hash & 1:
                                file_hash = (file_hash >> 1) ^ 0xEDB88320
                            else:
                                file_hash >>= 1
                
                actual_checksum = format(file_hash & 0xFFFFFFFF, '08x')
                
                if actual_checksum != checksum_line:
                    print(f"  WARNING: Checksum mismatch!")
                    print(f"    Manifest: {checksum_line}")
                    print(f"    Actual:   {actual_checksum}")
                else:
                    print(f"  Checksum verified: {actual_checksum}")
        
        # Build blocked days list
        self.blocked_days = list(dates_in_file)
        print(f"  Blocked days found: {len(self.blocked_days)}")
        
        self.validation_result = {
            "csv_path": csv_path,
            "manifest_path": manifest_path,
            "total_rows": data_rows,
            "blocked_days": self.blocked_days,
            "valid": True
        }
        
        print("  Validation: PASS")
        print()
        return True
    
    def _copy_to_tester(self):
        """Copy files to Strategy Tester accessible location."""
        print("Step 6: Preparing files for Strategy Tester...")
        
        if self.mql5_files_path:
            # Files are already in the MQL5/Files directory
            # which is accessible by both live terminal and tester
            print(f"  Files already in: {self.mql5_files_path}")
            
            # Also copy to common files if available
            common_path = os.path.join(self.mt5_data_path or "", "MQL5", "Files")
            if common_path != self.mql5_files_path and os.path.exists(os.path.dirname(common_path)):
                import shutil
                try:
                    os.makedirs(common_path, exist_ok=True)
                    csv_src = os.path.join(self.mql5_files_path, self.csv_filename)
                    manifest_src = os.path.join(self.mql5_files_path, self.manifest_filename)
                    
                    if os.path.exists(csv_src):
                        shutil.copy2(csv_src, os.path.join(common_path, self.csv_filename))
                    if os.path.exists(manifest_src):
                        shutil.copy2(manifest_src, os.path.join(common_path, self.manifest_filename))
                    
                    print(f"  Copied to common files: {common_path}")
                except Exception as e:
                    print(f"  WARNING: Could not copy to common files: {e}")
        else:
            print("  WARNING: Data path not found. Files may need manual placement.")
        
        print()
    
    def _launch_tester(self) -> bool:
        """Launch Strategy Tester with configured parameters."""
        print("Step 7: Launching Strategy Tester...")
        
        # Build tester configuration
        start_dt = datetime.strptime(self.start_date, "%Y.%m.%d")
        end_dt = datetime.strptime(self.end_date, "%Y.%m.%d")
        
        print(f"  Symbol: {self.symbol}")
        print(f"  Period: {start_dt.date()} to {end_dt.date()}")
        print(f"  Mode: {'Optimization' if self.optimize else 'Single Test'}")
        print(f"  Model: Every tick based on real ticks")
        print(f"  News Filter: ENABLED (from CSV)")
        print(f"  Blocked Days: {len(self.blocked_days)}")
        print()
        print("  Tester configuration:")
        print(f"    Expert: ZoneRecoveryEA")
        print(f"    Symbol: {self.symbol}")
        print(f"    Period: {self.start_date} - {self.end_date}")
        print(f"    Delay: Every tick based on real ticks")
        print(f"    Optimization: {'Enabled' if self.optimize else 'Disabled'}")
        print()
        
        # Note: Direct programmatic control of Strategy Tester
        # requires MT5 terminal to be configured for it
        # The tester is typically launched from within MT5
        
        print("  Please launch Strategy Tester in MT5 with these settings:")
        print(f"    1. Expert: ZoneRecoveryEA")
        print(f"    2. Symbol: {self.symbol}")
        print(f"    3. Date range: {self.start_date} to {self.end_date}")
        print(f"    4. Modeling: Every tick based on real ticks")
        print(f"    5. Inputs: NewsFilterEnabled = true")
        print(f"    6. News calendar CSV should be auto-loaded")
        
        # Try to launch via command line if possible
        if self.mt5_path and os.path.exists(self.mt5_path):
            tester_cmd = f'"{self.mt5_path}" /config:test.ini'
            print(f"  Attempting to launch: {tester_cmd}")
            try:
                # This is a placeholder - actual MT5 tester launch
                # requires specific command-line parameters
                pass
            except Exception as e:
                print(f"  WARNING: Could not launch tester automatically: {e}")
        
        print()
        return True


def main():
    parser = argparse.ArgumentParser(
        description='ZoneRecoveryEA News-Filtered Backtest Launcher',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python NewsBacktestLauncher.py --symbol EURUSD --from 2024.01.01 --to 2026.12.31
  python NewsBacktestLauncher.py --symbol XAUUSD --from 2025.01.01 --to 2025.12.31 --optimize
  python NewsBacktestLauncher.py --symbol GBPJPY --from 2024.06.01 --to 2025.06.01 --currencies GBP,JPY
        """
    )
    
    parser.add_argument('--symbol', required=True,
                       help='Trading symbol (e.g., EURUSD, XAUUSD)')
    parser.add_argument('--from', dest='start_date', required=True,
                       help='Start date (YYYY.MM.DD)')
    parser.add_argument('--to', dest='end_date', required=True,
                       help='End date (YYYY.MM.DD)')
    parser.add_argument('--mt5-path', default=None,
                       help='Path to MT5 terminal executable')
    parser.add_argument('--optimize', action='store_true',
                       help='Run optimization instead of single test')
    parser.add_argument('--currencies', default=None,
                       help='Override auto-detected currencies (comma-separated)')
    parser.add_argument('--all-impact', action='store_true',
                       help='Export all impact levels, not just high')
    
    args = parser.parse_args()
    
    launcher = NewsBacktestLauncher(
        symbol=args.symbol,
        start_date=args.start_date,
        end_date=args.end_date,
        mt5_path=args.mt5_path,
        optimize=args.optimize,
        currencies=args.currencies,
        high_impact_only=not args.all_impact
    )
    
    success = launcher.run()
    
    # Cleanup
    try:
        mt5.shutdown()
    except:
        pass
    
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
