#!/usr/bin/env python3

import sys
import polars as pl

parquet_path = sys.argv[1]
df = pl.read_parquet(parquet_path)

print(len(df), end="")