import os

# Plain HTTP downloads write a growing .incomplete file, which is how download progress is
# measured; Xet transfers report nothing until a file is complete. Must precede any hub import.
os.environ.setdefault("HF_HUB_DISABLE_XET", "1")

SAMPLE_RATE = 16_000
