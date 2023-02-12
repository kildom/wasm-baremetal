

import os
from pathlib import Path
import pickle
import re
import subprocess
import sys
from tempfile import NamedTemporaryFile
import concurrent.futures

NINJA = 'ninja'
BUILD_DIR = '/home/doki/my/wasm-baremetal/build/llvm'
TARGETS_CHUNK_LENGTH = 1000

class Test:

    all_deps: 'dict[str, list[set[str], set[str], set[str], bool]]' = {}

    def query_targets(self, targets: 'list[str]'):
        query_args = [NINJA, '-t', 'query']
        query_args.extend(targets)
        lines = self.exec(query_args)
        return self.parse_query_output(lines)

    def parse_query_output(self, lines: str):
        result = {}
        lines = lines.split('\n')
        lines = tuple(filter(lambda line: len(line.strip()) > 0, lines))
        line_no = 0
        while line_no < len(lines):
            m = re.fullmatch(r'(\S.*)\s*:', lines[line_no])
            if m is None:
                raise Exception(f'{line_no + 1}: Expecting target.')
            target = m.group(1)
            explicit = set()
            implicit = set()
            order_only = set()
            phony = False
            line_no += 1
            while line_no < len(lines):
                m = re.fullmatch(r'(\s*)(.*):(.*)', lines[line_no])
                if m is None:
                    raise Exception(f'{line_no + 1}: Expecting direction.')
                if m.group(1) == '':
                    break
                line_no += 1
                ind1 = len(m.group(1))
                dir = m.group(2)
                phony = phony or (re.search(r'(\s|^)phony(\s|$)', m.group(3)) is not None)
                if dir == 'input':
                    inputs = True
                else:
                    if dir != 'outputs':
                        raise Exception(f'{line_no + 1}: Expecting "input:" or "outputs:".')
                    inputs = False
                while line_no < len(lines):
                    m = re.fullmatch(r'(\s*)(\|?\|?)\s*(.*)', lines[line_no])
                    if m is None:
                        raise Exception(f'{line_no + 1}: Expecting {dir} target.')
                    if len(m.group(1)) <= ind1:
                        break
                    line_no += 1
                    input_target = str(m.group(3))
                    if inputs:
                        if m.group(2) == '':
                            explicit.add(input_target)
                        elif m.group(2) == '|':
                            implicit.add(input_target)
                        else:
                            order_only.add(input_target)
            result[target] = [explicit, implicit, order_only, phony]
        return result

    def exec(self, args):
        with NamedTemporaryFile(mode='w+', encoding='8859') as out_file, \
                NamedTemporaryFile(mode='w+', encoding='8859') as err_file:
            cp = subprocess.run(args, stdout=out_file, stderr=err_file, cwd=BUILD_DIR, check=False)
            out_file.seek(0)
            err_file.seek(0)
            err = err_file.read()
            err_file.close()
            if cp.returncode != 0:
                print(err, file=sys.stderr)
                raise Exception(f'Ninja command error, code {cp.returncode}.')
            if len(err.strip()) > 0:
                print(err, file=sys.stderr)
                raise Exception('Cannot read list of all targets.')
            del err
            return out_file.read()

    def get_all_targets(self):
        def first(x):
            x = x.split(':', 1)
            return x[0].strip()
        result = self.exec(['ninja', '-t', 'targets', 'all'])
        return [first(x) for x in result.split('\n') if len(x.strip()) > 0]

    def get_all_deps(self):
        all_targets = self.get_all_targets()
        chunks = [all_targets[i:i + TARGETS_CHUNK_LENGTH] for i in range(0, len(all_targets), TARGETS_CHUNK_LENGTH)]
        executor_workers = os.cpu_count()
        executor = concurrent.futures.ThreadPoolExecutor(executor_workers)
        executor_chunk_size = (len(chunks) + executor_workers - 1) // executor_workers
        result = {}
        for partial_result in executor.map(self.query_targets, chunks, chunksize=executor_chunk_size):
            result.update(partial_result)
        return result

    def process_dep(self, name, level=0):
        if name not in self.all_deps:
            return -1
        target = self.all_deps[name]
        if len(target) >= 5:
            return
        target.append(level)
        if name.endswith('.o'):
            if level == 1:
                print(name)
            if level >= len(self.levels):
                self.levels.append([])
            self.levels[level].append(name)
            sub_level = level + 1
        else:
            sub_level = level
        for sub in set().union(*target[0:3]):
            self.process_dep(sub, sub_level)


    def main(self):
        self.depth = 0
        self.levels = []
        print('Getting all targets...')
        state_file = Path('tmp.pickle')
        if state_file.exists():
            with open(state_file, 'rb') as fd:
                self.all_deps = pickle.load(fd)
        else:
            self.all_deps = self.get_all_deps()
            with open(state_file, 'wb') as fd:
                pickle.dump(self.all_deps, fd)
        print('Processing...')
        self.process_dep('install-clang')
        self.process_dep('install-clang')
        self.process_dep('install-clang-format')
        self.process_dep('install-clang-tidy')
        self.process_dep('install-clang-apply-replacements')
        self.process_dep('install-lld')
        self.process_dep('install-llvm-mc')
        self.process_dep('install-llvm-ranlib')
        self.process_dep('install-llvm-strip')
        self.process_dep('install-llvm-dwarfdump')
        self.process_dep('install-clang-resource-headers')
        self.process_dep('install-ar')
        self.process_dep('install-ranlib')
        self.process_dep('install-strip')
        self.process_dep('install-nm')
        self.process_dep('install-size')
        self.process_dep('install-strings')
        self.process_dep('install-objdump')
        self.process_dep('install-objcopy')
        self.process_dep('install-c++filt')
        print('--', len(self.levels))
        for l in self.levels:
            print(len(l))
        print('--', sum(len(l) for l in self.levels))
        print(len([x for x in self.all_deps if x.endswith('.o')]))



x = Test()
x.main()
