"""Run the mod's production-loader and native-script tests with LuaJIT."""
import argparse
import os
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--engine', required=True, type=Path)
parser.add_argument('--cache', type=Path)
parser.add_argument('--harness', type=Path, help='Engine checkout with tests when the target contains runtime files only')
args = parser.parse_args()
mod = Path(__file__).resolve().parents[1]
engine = args.engine.resolve()
cache = args.cache.resolve() if args.cache else None
harness = args.harness.resolve().as_posix() if args.harness else None
os.chdir(engine)
from lupa.luajit21 import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
if harness:
    lua.globals().HARNESS_PATH = harness
    lua.execute("package.path=package.path..';'..HARNESS_PATH..'/?.lua;'..HARNESS_PATH..'/?/init.lua'")
lua.globals().MOD_PATH = Path(os.path.relpath(mod, engine)).as_posix()
lua.globals().CACHE_PATH = cache.as_posix() if cache else None
lua.execute((mod / 'tests/event.lua').read_text(encoding='utf-8'))
lua.execute((mod / 'tests/port.lua').read_text(encoding='utf-8'))
